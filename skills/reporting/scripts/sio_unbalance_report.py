#!/nfs/site/disks/ayarokh_wa/tools/python/3.11.1/bin/python3

import collections
import datetime
import glob
import os
import re
import subprocess
import sys
import csv
import logging
import argparse
import tempfile
import pandas as pd

log = logging.Logger('default', logging.DEBUG)

cores = ['icore0/par_vpmm', 'icore0/par_ooo_int', 'icore0/par_tmul_stub', 'icore0/par_pmh', 'icore0/par_fe', 'icore0/par_meu', 'icore0/par_ooo_vec', 'icore0/par_msid', 'icore0/par_exe_int', 'icore0/par_fmav0', 'icore0/par_fmav1', 'icore0/par_exe',
         'icore1/par_vpmm', 'icore1/par_ooo_int', 'icore1/par_tmul_stub', 'icore1/par_pmh', 'icore1/par_fe', 'icore1/par_meu', 'icore1/par_ooo_vec', 'icore1/par_msid', 'icore1/par_exe_int', 'icore1/par_fmav0', 'icore1/par_fmav1', 'icore1/par_exe',
         'par_pm', 'par_mlc',]


def check_parenths(str):
    open_list = ["[", "{", "("]
    close_list = ["]", "}", ")"]
    stack = []
    for i in str:
        if i in open_list:
            stack.append(i)
        elif i in close_list:
            pos = close_list.index(i)
            if ((len(stack) > 0) and
                    (open_list[pos] == stack[len(stack)-1])):
                stack.pop()
            else:
                return False
    return len(stack) == 0


def pattern_to_list(pin):
    asterix_to = range(0, 32)
    ret = [pin]
    from_to = collections.OrderedDict()
    start = len(pin)

    while True:
        end = pin.rfind('}', 0, start)
        aend = pin.rfind('*', 0, start)
        if end == -1 and aend == -1:
            break
        if aend > end:
            end = aend+1
            start = end-1
        else:
            start = pin.rfind('{', 0, end)+1
        to_decode = pin[start:end]
        nums = []
        for a in to_decode.split(','):
            if a == '*':
                nums = asterix_to
            elif ':' not in a:
                nums.append(a) # type: ignore
            else:
                s, e = a.split(":")
                nums.extend(list(range(int(s), int(e)+1))) # type: ignore
            from_to[start + 1 if a == '*' else start,
                    end - 1 if a == '*' else end] = nums
    for key, value in from_to.items():
        d = []
        start, end = key
        for r in ret:
            for v in set(value):
                d.append(f'{r[:start-1]}{v}{r[end+1:]}')
        ret = d
    return ret


def read_spec_file(fin):
    ret = {}
    with open(fin, newline='') as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            if 'Active' in row:
                row['active'] = row['Active']
            if 'high_spec' in row:
                row['spec'] = row['high_spec']
            if 'Pin' in row:
                row['pin'] = row['Pin']
            if 'Par' in row:
                row['par'] = row['Par']
            if row['active'] == '1':
                pin = row['pin']
                spec = row['spec']
                par = row['par']
                if not check_parenths(pin):
                    log.warning(f'Problem with line: {row} in file {fin}')
                    continue
                for p in pattern_to_list(pin):
                    for core in cores:
                        if core.endswith(par):
                            try:
                                ret[core + '/' + p] = float(spec)
                            except:
                                print(f'Problem with spec: "{spec}", file: {fin}, row: {row}')
    return ret


def read_spec_ft_file(fin):
    '''active,par,in_pin,out_pin,ft_spec,Comment'''
    ret = {}
    with open(fin, newline='') as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            if row['active'] == '1':
                pins_compr = [row['in_pin'], row['out_pin']]
                pins = []
                spec = row['ft_spec']
                par = row['par']
                for i in range(0,len(pins_compr)):
                    d = []
                    if not check_parenths(pins_compr[i]):
                        log.warning(f'Problem with line: {row} in file {fin}')
                        continue
                    for p in pattern_to_list(pins_compr[i]):
                        d.append(p)
                    pins.append(d)
                for core in cores:
                    if core.endswith(par):
                        for in_pin in pins[0]:
                            for out_pin in pins[0]:
                                p1 = core + '/' + in_pin
                                p2 = core + '/' + out_pin
                                ret[f'{p1},{p2}'] = float(spec)
    return ret


def read_abutted_ports_report(fin):
    fields = ['pin_in', 'pin_out']
    ret = {}
    with open(fin) as f:
        for line in f:
            a, b = line.strip().split(',')
            ret[a] = b
    return ret


def read_unbalanced_spec_report_as_is(f, to_filter=set()):
    fields = ['UnBalance', 'OutputPort', 'InputPort', 'Status StartClk EndClk', 'DriverBudget',
              'DriverBudgetSource', 'ReceiverBudget', 'ReceiverBudgetSource', 'FTBudget', 'Total FT', 'Calculations']
    lines = []
    row = 0
    all_lines = set()
    for line in f:
        if line.strip() == '' or line.strip().startswith(fields[0]):
            continue
        row += 1
        start = 0
        lline = []
        i = 0
        while i < len(fields):
            end = line.find('|', start)
            d = line[start: end].strip().replace('|', '')

            if d != '':
                if d == '-POS':
                    d = -float('inf')
                elif d == '':
                    d = None
                else:
                    try:
                        d = float(d)
                    except ValueError:
                        pass
            if fields[i] in ['DriverBudget', 'ReceiverBudget']:
                a, b = d.split(' ') # type: ignore
                lline.append(float(a))
                lline.append(b)
                i += 1
            else:
                d = None if d == '' else d
                lline.append(d)
            i += 1
            start = end + 1
        if line not in to_filter:
            lines.append(lline)
            all_lines.add(line)

    return pd.DataFrame(lines, columns=fields), all_lines


def read_unbalanced_spec_report(fin, filter_file):
    df = None
    cmd = f'grep -v -f {filter_file} {fin} | grep -v sbclk'
    filters = []
    with os.popen(cmd) as f:
        df, readed = read_unbalanced_spec_report_as_is(f)
    with open(fin) as f:
        df_filtred, readed = read_unbalanced_spec_report_as_is(f, readed)
    filters.append(check_filter(fin, 'sbclk'))
    with open(filter_file) as f:
        for filter in f:
            filter = filter.strip()
            filters.append(check_filter(fin, filter))

    return df, df_filtred, pd.DataFrame(filters, columns=['filter', 'count'])


def check_filter(fin, filter):
    data = subprocess.run(
        f"grep -c '{filter}' {fin}", capture_output=True, shell=True, text=True)
    return [filter, int(data.stdout)]


def calculate_new_unbalance(row, specs, ft_specs, abutted_ports):
    par = None
    for core in cores:
        if row['InputPort'].startswith(core + "/"):
            par = core.split('/')[-1]

    calc = row['UnBalance']
    if row['OutputPort'] not in specs or row['InputPort'] not in specs:
        return [calc, None, None, None, par]
    if row['FTBudget'] is not None:
        ft_budget = calc_ft_spec_budeget(
            row['FTBudget'], row['OutputPort'], row['InputPort'], ft_specs,  abutted_ports)
    else:
        ft_budget = 0.0
    calc = row['UnBalance'] + row['DriverBudget'] + row['ReceiverBudget'] + row['Total FT'] - ft_budget - \
        specs[row['InputPort']] - specs[row['OutputPort']]
    return [calc, specs[row['InputPort']], specs[row['OutputPort']], ft_budget, par]


def calc_ft_spec_budeget(ft_budget, out_port, port_in, ft_specs, abutted_ports):
    ret = 0.0
    a = get_budeget_from_ft_budget(ft_budget)
    port_out = get_from_abutted_ports(port_in, abutted_ports)
    for port_in, budget in a.items():
        key = f'{port_in},{port_out}'
        budget = ft_specs.get(key, budget)
        ret += budget
        port_out = get_from_abutted_ports(port_in, abutted_ports)
    return ret


def get_from_abutted_ports(port, abutted_ports):
    ret = ""
    s = set()
    while True:
        if port in abutted_ports:
            if abutted_ports[port] in s:
                break
            ret = abutted_ports[port]
            s.add(port)
            port = ret
        else:
            break
    return ret


def get_budeget_from_ft_budget(ft_budget):
    ret = collections.OrderedDict()
    _tmp = ft_budget.split(":")
    _tmp.reverse()
    for l in _tmp:
        if l == "":
            continue
        end = l.rfind(")")
        start = l.find("(", 0, end) + 1
        budget = float(l[start:end])
        port = l[:start-1]
        ret[port] = budget
    return ret


def combine_unbalance_with_all_data(df, specs, ft_specs, abutted_ports, uarchs):
    df[['newUnbalance', 'newRecieverBudget', 'newDriverBudget', 'newTotalFt', 'partition']] = df.apply(lambda row: calculate_new_unbalance(
        row, specs, ft_specs, abutted_ports), axis=1, result_type='expand')
    df['uarch_family'] = df.apply(
        lambda row: uarch_get_family(row, uarchs), axis=1)
    return df


def get_rtl_date(indir):
    date = 2345
    var_tcl = f'{indir}/runs/core_client/1278.6/sta_pt/scripts/vars.tcl' if os.path.exists(f'{indir}/runs/core_client/1278.6') else f'{indir}/runs/core_client/1278.3/sta_pt/scripts/vars.tcl'
    cmd = f"grep CORE_ROOT {var_tcl} | sed -r 's/.*-([0-9]*)ww([0-9]*).*/\\1\\2/g' | sort -u | head -1"
    data = subprocess.run(cmd, capture_output=True, shell=True, text=True)
    try:
        date = int(data.stdout.strip())
    except ValueError:
        pass  # it was a string, not an int.
    return date


def parse_args():
    """ parse_args() : command-line parser """
    parser = argparse.ArgumentParser(
        description='SIO MOW unbalance report')
    today = datetime.date.today()
    
    corner = 'func.max_high.ttttcmaxtttt_100.tttt'
    if 'GFCN2' in os.getenv('PRODUCT_NAME',""):
        corner = 'func.max_high.T_85.typical'
    parser.add_argument('-corner', type=str,
                        help='Corner to run', required=False)
    args, _ = parser.parse_known_args()
    if args.corner: corner = args.corner

    indir = '/nfs/site/disks/pnc_fct_bu/work_area/fct_scripts/PNC/links/next_pnc0a_1278_core_client_fcl'
    tech = '1278.6' if os.path.exists(f'{indir}/runs/core_client/1278.6') else '1278.3'
    unbalance_report = f'{indir}/runs/core_client/{tech}/sta_pt/{corner}/reports/spec_status/unbalanced_spec_dir/Unbalanced_spec_report'
    abutted_report = f'{indir}/runs/core_client/{tech}/sta_pt/{corner}/reports/core_client.{corner}_abutted_pins.rpt'
    filter_file = f'{indir}/runs/core_client/{tech}/sta_pt/{corner}/reports/spec_status/unbalanced_spec_dir/filter_file'
    hack_dir_filter = f'/nfs/site/disks/pnc_fct_td/PNC/PNC_client_A0_Hack_dir/runs/core_client/{tech}/sta_pt/inputs/unbalance_filter.csv'
    rtl_date = get_rtl_date(indir)
    uarch_file = '/nfs/site/disks/pnc_fct_bu/work_area/fct_scripts/pnc_clientb0/pnc_uarch_list.csv'
    output_report_dir = f"/nfs/site/disks/ayarokh_wa/PNC/unbalance_report/{today.strftime('%y%m%d')}"
    proj_archive = os.getenv('PROJ_ARCHIVE',None) if os.getenv('PROJ_ARCHIVE') else '/nfs/site/disks/pnc_78_client_arc_proj_archive'
    if 'GFCN2' in os.getenv('PRODUCT_NAME',""):
        tech = 'n2p_htall_conf4'
        indir = f'/nfs/site/disks/pnc_fct_bu/work_area/fct_scripts/GFC/links/daily_gfc0a_n2_core_client_fcl'
        unbalance_report = f'{indir}/runs/core_client/{tech}/sta_pt/{corner}/reports/spec_status/unbalanced_spec_dir/Unbalanced_spec_report'
        abutted_report = f'{indir}/runs/core_client/{tech}/sta_pt/{corner}/reports/core_client.{corner}_abutted_pins.rpt'
        filter_file = f'{indir}/runs/core_client/{tech}/sta_pt/{corner}/reports/spec_status/unbalanced_spec_dir/filter_file'
        hack_dir_filter = f'/nfs/site/disks/idc_gfc_fct_td/GFC_client_A0_Hack_dir/runs/core_client/n2p_htall_conf4/sta_pt/inputs/unbalance_filter.csv'
        rtl_date = get_rtl_date(indir)
        uarch_file = '/nfs/site/disks/pnc_fct_bu/work_area/fct_scripts/gfc_clienta0/pnc_uarch_list.csv'
        output_report_dir = f"/nfs/site/disks/ayarokh_wa/GFC/unbalance_report/{today.strftime('%y%m%d')}"
        proj_archive = os.getenv('PROJ_ARCHIVE',None) if os.getenv('PROJ_ARCHIVE') else '/nfs/site/disks/gfc_n2_client_arc_proj_archive'
    parser.add_argument('-unbalance_report', type=str,
                        help='Unbalance report', required=False, default=unbalance_report)
    parser.add_argument('-abutted_report', type=str,
                        help='Abutted report', required=False, default=abutted_report)
    parser.add_argument('-filter_file', type=str,
                        help='Filters file report', required=False, default=filter_file)
    parser.add_argument('-hack_dir_filter', type=str,
                        help='hack_dir_filter', required=False, default=hack_dir_filter)
    parser.add_argument('-rtl_date', type=int,
                        help='rtl date for filter from hack_dir_filter', required=False, default=rtl_date)
    parser.add_argument('-uarch_file', type=str, help='List of urachs', required=False, default=uarch_file)
    parser.add_argument('-proj_archive', type=str, help='Proj archive', required=False, default=[proj_archive])
    parser.add_argument('-per_par_spec', type=str,
                        help='Per partition spec dir. Dir has to include <par>_spec.csv and <par>_ft_spec.csv, Format: partition:directory', required=False, nargs='*')
    parser.add_argument('-no_xlsx', help="Don't write xlsx", action='store_true')
    parser.add_argument('-output_report_dir', type=str,
                        help='Output excel report', required=False, default=output_report_dir)
    args = parser.parse_args()
    return args


def prepare_hack_dir_filter_file(filter_file, filter_file2, rtl_date):
    ret = None
    ttt = '/tmp_proj'
    if not os.path.exists(ttt):
        ttt = '/tmp'
    with tempfile.NamedTemporaryFile(dir=ttt, mode='wt', delete=False) as fp:
        ret = fp.name
        with open(filter_file) as ff:
            for line in ff:
                line = line.strip()
                if line.startswith("#"):
                    continue
                filt, date, _ = line.split(",", maxsplit=2)
                if int(date) > rtl_date:
                    fp.write(filt + "\n")
        with open(filter_file2) as ff:
            for line in ff:
                line = line.strip()
                if line.startswith("#"):
                    continue
                fp.write(line + "\n")
    return ret


def get_specs_files(from_user, proj_archive):
    ft_specs = []
    specs = []
    done = dict()
    if from_user:
        for f in from_user:
            name, d = f.split(":")
            done[name] = d
            if os.path.exists(d) and os.path.isfile(f'{d}/{name}_spec.csv') and os.path.isfile(f'{d}/{name}_spec_ft.csv'):
                specs.append(f'{d}/{name}_spec.csv')
                ft_specs.append(f'{d}/{name}_spec_ft.csv')
            else:
                log.fatal(f'Not exists: {d}/{name}_spec.csv or {d}/{name}_spec_ft.csv')
                sys.exit(1)
    for f in glob.glob(proj_archive + '/arc/*/timing_specs/GOLDEN/*_spec.csv'):
        name = f.split("/")[-4]
        if name not in done: specs.append(f)
        else: log.debug(f'Got from user: {name}')
    return specs, ft_specs

def main():
    args = parse_args()
    unbalance_report = args.unbalance_report
    abutted_report = args.abutted_report
    filter_file = args.filter_file
    output_report_dir = args.output_report_dir
    rtl_date = int(args.rtl_date)
    hack_dir_filter = args.hack_dir_filter
    uarch_file = args.uarch_file
    per_par_spec = args.per_par_spec
    os.makedirs(output_report_dir, exist_ok=True)

    specs, ft_specs = get_specs_files(per_par_spec, args.proj_archive[0])
    df, df_unbalance_filtred, df_uarchs, filters = make_df(
        unbalance_report, abutted_report, filter_file, ft_specs, specs, rtl_date, hack_dir_filter, uarch_file)
    bins = list(range(-100, 100, 10))
    bins[0] = -float("inf") # type: ignore
    bins[-1] = float("inf")  # type: ignore
    df = add_range(df, 'newUnbalance', bins=bins)
    df_unbalance_filtred = add_range(
        df_unbalance_filtred, 'newUnbalance', bins=bins)
    df_uarchs = add_range(df_uarchs, 'newUnbalance', bins=bins)
    range_name = 'hist_newUnbalance'
    make_excel(df, output_report_dir, range_name,
               df_unbalance_filtred, df_uarchs, filters, args)


def read_uarch_file(uarch_file):
    ret = dict()
    df = pd.read_csv(uarch_file, index_col=None,dtype=str)
    for row in df.to_dict('records'):
        key = f"{row['drv_par']},{row['rcv_par']}"
        drv_signal = row['drv_signal']
        rcv_signal = row['rcv_signal']
        if key not in ret:
            ret[key] = list()
        ret[key].append(dict(
            family=row['#family'],
            drv_signal_regex=re.compile(
                f".*{drv_signal.replace('*','.*')}.*") if drv_signal is pd.notna(drv_signal) else re.compile('.*'),
            rcv_signal_regex=re.compile(
                f".*{rcv_signal.replace('*','.*')}.*") if rcv_signal is pd.notna(rcv_signal) else re.compile('.*'),
            data=row,
        ))
    return ret


def uarch_get_family(row, uarch_df):
    outputPort = row['OutputPort']
    inputPort = row['InputPort']
    drv_par = None
    rcv_par = None

    for core in cores:
        if outputPort.startswith(core + "/"):
            drv_par = core.split('/')[-1]
        if inputPort.startswith(core + "/"):
            rcv_par = core.split('/')[-1]
    family = None
    key = f'{drv_par},{rcv_par}'
    if key in uarch_df:
        for l in uarch_df[key]:
            if l['drv_signal_regex'].match(outputPort) and l['rcv_signal_regex'].match(inputPort):
                family = l['family']
                break

    return family


def make_df(unbalance_report, abutted_report, filter_file, ft_specs, specs, rtl_date, hack_dir_filter_file, uarch_file):
    ret_columns = ['newUnbalance', 'UnBalance', 'newDriverBudget', 'DriverBudget', 'newRecieverBudget', 'ReceiverBudget', 'newTotalFt', 'Total FT',
                   'OutputPort', 'InputPort', 'partition', 'Status StartClk EndClk', 'DriverBudgetSource', 'ReceiverBudgetSource', 'FTBudget', 'Calculations', 'uarch_family']
    ft_specs_dict = dict()
    specs_dict = dict()
    for f in ft_specs:
        ft_specs_dict.update(read_spec_ft_file(f))
    for f in specs:
        specs_dict.update(read_spec_file(f))
    filter_file_tmp = prepare_hack_dir_filter_file(
        hack_dir_filter_file, filter_file, rtl_date)
    df_unbalance, df_unbalance_filtred, filters = read_unbalanced_spec_report(
        unbalance_report, filter_file_tmp)
    os.remove(filter_file_tmp)

    df_abutted = read_abutted_ports_report(abutted_report)
    uarchs = read_uarch_file(uarch_file)
    df = combine_unbalance_with_all_data(
        df_unbalance, specs_dict, ft_specs_dict, df_abutted, uarchs)
    df_uarch = df[~df['uarch_family'].isna()]
    df_unbalance_filtred = combine_unbalance_with_all_data(
        df_unbalance_filtred, specs_dict, ft_specs_dict, df_abutted, uarchs)
    return df[ret_columns], df_unbalance_filtred[ret_columns], df_uarch[ret_columns], filters


def add_range(df, column_name, bins):
    """ add_range() : add range column """
    df[f'hist_{column_name}'] = pd.cut(df[column_name], bins=bins)
    return df


def _make_excel(df, range_name, writer, tab_ext=""):
    a = df.groupby('partition')
    data = []
    # bins.append('more')
    cols = ['partition']
    u = sorted(df.hist_newUnbalance.unique())
    cols.extend(u)
    for par, group in a:
        counts = collections.OrderedDict()
        for uu in u:
            counts[uu] = 0
        l = [par]
        for uu in group[range_name]:
            counts[uu] += 1
        l.extend(counts.values())
        data.append(l)
    hist_df = pd.DataFrame(data, columns=cols)
    sheet_name = "Histogram" + tab_ext
    hist_df.to_excel(writer, sheet_name=sheet_name,
                     index=False, float_format='%.2f')
    worksheet = writer.sheets[sheet_name]
    workbook = writer.book
    (max_row, max_col) = hist_df.shape
    column_settings = [{"header": str(column)} for column in hist_df.columns]

    worksheet.add_table(0, 0, max_row, max_col - 1,
                        {"columns": column_settings})
    worksheet.set_column(0, max_col - 1, 12)

    chart1 = workbook.add_chart({"type": "column"})
    for i in range(1, max_row+1):
        chart1.add_series({
            "name": [sheet_name,  i, 0],
            "categories": [sheet_name, 0, 1, 0, max_col-1],
            "values": [sheet_name, i, 1, i, max_col-1],
        })
    chart1.set_size({'x_scale': 3.7, 'y_scale': 1.5})
    worksheet.insert_chart(max_row+2, 0, chart1)
    df.to_excel(writer, sheet_name='Data' + tab_ext,
                index=False, float_format='%.2f')
    return df


def make_excel(df, output_dir, range_name, df_unbalance_filtred, df_uarchs, filters, args):
    df.index.name='row_num'
    if args.corner:
        corner = args.corner.split(".")[1]
        df.to_csv(f'{output_dir}/unbalance_report.{corner}.csv', float_format='%.2f')
        output_excel = f'{output_dir}/unbalance_report.{corner}.xlsx'
    else:
        df.to_csv(f'{output_dir}/unbalance_report.csv', float_format='%.2f')
        output_excel = f'{output_dir}/unbalance_report.xlsx'
    if args.no_xlsx:
        return
    with pd.ExcelWriter(output_excel) as writer:
        df = _make_excel(df, range_name, writer, tab_ext="")
        _make_excel(df_uarchs, range_name, writer, tab_ext="_uarchs")
        _make_excel(df[(df['DriverBudgetSource'] == 'default') | (
            df['ReceiverBudgetSource'] == 'default')], range_name, writer, tab_ext="_defaut")
        _make_excel(df_unbalance_filtred, range_name, writer, tab_ext="_filt")
        filters.sort_values(by='count', ascending=False).to_excel(
            writer, sheet_name='filters', index=False, float_format='%.2f')
        workbook = writer.book
        worksheet = workbook.add_worksheet("args") # type: ignore

        i = 0
        for k, v in vars(args).items():
            worksheet.write(i, 0, k)
            worksheet.write(i, 1, str(v))
            i += 1
    return

if __name__ == '__main__':
    sys.exit(main())
