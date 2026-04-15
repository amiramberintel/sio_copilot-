#!/usr/intel/pkgs/python3/3.11.1/bin/python3
import argparse
from doctest import Example
from token import NEWLINE
import UsrIntel.R2
import os
import sys
import pandas as pd
import os
import subprocess
from datetime import datetime
# from zoneinfo import ZoneInfo
import xml.etree.ElementTree as ET
import glob
import filecmp
import re

def debugger_is_active() -> bool:
    """Return if the debugger is currently active"""
    return (gettrace := getattr(sys, 'gettrace')) and gettrace()

def summary_mail(wa,par,corners,tables,main_corner,dfx_corner):
    tag,reftag,ts,rtl,contour = get_global_indicators(par,wa,corners[0])
    table_lines = []
    fixed = False
    if main_corner:
        for corner in corners:
            if main_corner == corner.split('.')[1]:
                main_corner = corner
                fixed = True
            if corner.split('.')[0]=='spec' and fixed:
                break
    else:
        main_corner = corners[0]
    fixed = False
    if dfx_corner:
        for corner in corners:
            if dfx_corner == corner.split('.')[1]:
                dfx_corner = corner
                fixed = True
            if corner.split('.')[0]=='spec' and fixed:
                break
    else:
        dfx_corner = corners[-1]
    # attachments = []
    #table[corner][int/ext/clk]
    uArc_cor = main_corner.split('.')[0] + '.' + main_corner.split('.')[1]
    DFX_cor = dfx_corner.split('.')[0] + '.' + dfx_corner.split('.')[1]
    table_lines.append(f'    <h2>uArcs {uArc_cor}</h2>')
    table_lines.append(tables[main_corner]['uArc'])
    table_lines.append(f'    <h2>DFX {DFX_cor}</h2>')
    table_lines.append('    <p>EXT:</p>')
    table_lines.append(tables[dfx_corner]['dfx_ext'])
    table_lines.append('    <p>INT:</p>')
    table_lines.append(tables[dfx_corner]['dfx_int'])
    for corner in corners:
        # attachments.append(get_itable_file(wa,corner,'xlsx'))
        cor = corner.split('.')[0] + '.' + corner.split('.')[1]
        table_lines.append(f'    <h2>{cor}</h2>')
        table_lines.append('    <p>EXT:</p>')
        table_lines.append(tables[corner]['ext'])
        table_lines.append('    <p>INT:</p>')
        table_lines.append(tables[corner]['int'])
        table_lines.append('    <p>CLK:</p>')
        table_lines.append(tables[corner]['clk'])
    table_lines = '\n'.join(table_lines)
    #Mail itself
    full_html = f"""
    <html>
    <head>
        <style>
            p {{font-weight: bold; color: #00c0e5; font-size: 14px;}}
            ul {{padding-left: 20px;}}
            div {{font-family: Arial; font-size: 14px; color: #333;}}
            h1 {{text-align: center; color: #009bb9; font-weight: bold; font-size: 24px;}}
            h2 {{font-weight: bold; color: #00c0e5; font-size: 22px; text-align: center; margin-top: 60;}}
            td {{width: 100px;}}
        </style>
    </head>
    <body>
        <div>
        <h1>{tag} CI results</h1>
        <p>Run properties:</p>
        <ul>
            <li><b>RTL:</b> {rtl}</li>
            <li><b>IO constraints:</b> {contour}</li>
            <li><b>TS:</b> {ts}</li>
            <li><b>REF model:</b> {reftag}</li>
            <li><b>WA:</b> {os.path.abspath(wa)}</li>
            <li>All indicators are <u><b>uncompressed</b></u></li>
        </ul>
        <p>Comments</p>
        <ul>
            <li>here</li>
        </ul>
        {table_lines}
    </body>
    </html>
    """
    # attachments = ' '.join(attachments)
    attachments = glob.glob(wa + '/runs/core*/*/sta_pt/*/reports/csv/indicator_table*.xlsx')
    attachments = ' '.join(attachments)
    html_path = os.path.join(wa,'release_mail.html')
    try:
        with open(html_path, "w") as file:
            file.write(full_html)
    except:
        html_path = 'release_mail.html'
        with open(html_path, "w") as file:
            file.write(full_html)

    print('Sending mail')
    sub_res = subprocess.run(f"mutt $USER -a {attachments} -e 'set content_type=text/html' -s '{par}: {tag} CI results' < {os.path.abspath(html_path)}", shell=True, capture_output=True, text=True)
    if sub_res.stdout:
        print (sub_res.stdout)
    if sub_res.stderr:
        print (sub_res.stderr)


def get_itable_list(html_file,table_name):
    out_table = []
    start = False
    with open(html_file, 'r') as f:
        lines = f.readlines()
    for line in lines:
        if not start:
            if (f'<em>{table_name}</em>' not in line):
                continue
            else:
                start = True
                continue
        if ('</table>' not in line):
            out_table.append(line)
        else:
            out_table.append('</table>')
            break

    return out_table

def extract_cells_itable(table,row_sls,col_sl):
    start = False
    grepped_table = []
    table_rows = []
    row_idx = 0
    col_range = range(col_sl.start,col_sl.stop)
    col_idx = 0
    for line in table:
        if '</table>' in line:
            break
        if not start:
            if('<tr>' not in line):
                grepped_table.append(line)
                continue
            else:
                start = True
        if '<tr>' in line:
            table_rows.append(line)
            continue
        if col_idx in col_range:
            table_rows[row_idx]+=line
        col_idx+=1
        if '</tr>' in line:
            row_idx+=1
            col_idx = 0

    for row_sl in row_sls:
        grepped_table+=table_rows[row_sl]
    grepped_table+='</table>'
    return ''.join(grepped_table)

def get_itable_file(wa,corner,suffix):
    csv_path = os.path.join(wa,'runs','core_'+os.getenv('PROJECT').split('_')[-1],os.getenv('tech'),'sta_pt',corner,'reports/csv')
    itable_file = glob.glob(csv_path + f'/indicator_table_*.{suffix}')
    try:
        if itable_file[0]:
            return itable_file[0]
    except:
        return False

def get_uarc_rows(wa,corner,par):
    pattern = par + '/'
    xlsx_file = get_itable_file(wa,corner,'xlsx')
    df = pd.read_excel(xlsx_file,sheet_name='uArch_sum')
    row_numbers = []
    # print(xlsx_file)
    for index, row in df.iterrows():
        if pattern in str(row['drv_par/drv_signal (example)']) or pattern in str(row['rcv_par/rcv_signal (example)']) or pattern in str(row['drv_units']) or pattern in str(row['rcv_units']):
            row_numbers.append(int(index))
            # print (str(index) + row['drv_par/drv_signal (example)'] + row['rcv_par/rcv_signal (example)'])
    return row_numbers

def get_clk_rows(wa,corner,par):
    pattern = re.sub('par','mclk',par)
    xlsx_file = get_itable_file(wa,corner,'xlsx')
    df = pd.read_excel(xlsx_file,sheet_name='clk_latency')
    row_numbers = []
    # print(xlsx_file)
    for index, row in df.iterrows():
        if pattern in str(row['#clk_name']):
            row_numbers.append(int(index))
    return row_numbers

def get_itables(wa,par,corners):
    if (par == 'par_meu'):
        ext_vrf_row_sls = [slice(0,5),slice(9,13),slice(15,19)]
        int_vrf_row_sls = [slice(0,1),slice(9,11)]
        # clk_row_sls = [slice(0,1),slice(9,11)]
    elif (par == 'par_msid'):
        ext_vrf_row_sls = [slice(0,1),slice(3,5),slice(13,19)]
        int_vrf_row_sls = [slice(0,1),slice(13,15)]
        # clk_row_sls = [slice(0,1),slice(15,17)]
    elif (par == 'par_mlc'):
        ext_vrf_row_sls = [slice(0,1),slice(3,5),slice(9,11),slice(11,13)]
        int_vrf_row_sls = [slice(0,1),slice(11,13)]
        # clk_row_sls = [slice(0,1),slice(13,15)]
    elif (par == 'par_fe'):
        ext_vrf_row_sls = [slice(0,1),slice(3,5),slice(9,11),slice(11,13),slice(13,15),slice(15,17),slice(17,19)]
        int_vrf_row_sls = [slice(0,1),slice(3,5)]
    elif (par == 'par_pm'):
        ext_vrf_row_sls = [slice(0,1),slice(11,13),slice(19,21)]
        int_vrf_row_sls = [slice(0,1),slice(19,21)]
    else:
        print('partition unsupported')
        exit()
    left_vrf_cols = slice(0,12)
    right_vrf_cols = slice(12,24)
    clk_cols = slice(0,4)
    itables = {}
    for corner in corners:
        itables[corner] = {}
        html_file = get_itable_file(wa,corner,'html')
        table_name = 'vrf_uncomp'
        table = get_itable_list(html_file,table_name)
        itables[corner]['ext'] = extract_cells_itable(table,ext_vrf_row_sls,left_vrf_cols)
        itables[corner]['int'] = extract_cells_itable(table,int_vrf_row_sls,right_vrf_cols)

        table_name = 'clk_latency'
        table = get_itable_list(html_file,table_name)
        clk_rows = get_clk_rows(wa,corner,par)
        clk_row_sls = [slice(0,1)]
        for crow in clk_rows:
            clk_row_sls.append(slice(crow+1,crow+2))
        itables[corner]['clk']= extract_cells_itable(table,clk_row_sls,clk_cols)

        table_name = 'vrf_dfx'
        table = get_itable_list(html_file,table_name)
        itables[corner]['dfx_ext'] = extract_cells_itable(table,ext_vrf_row_sls,left_vrf_cols)
        itables[corner]['dfx_int'] = extract_cells_itable(table,int_vrf_row_sls,right_vrf_cols)

        table_name = 'uArch_sum'
        table = get_itable_list(html_file,table_name)
        uarc_rows = get_uarc_rows(wa,corner,par)
        row_sls = [slice(0,1)]
        for urow in uarc_rows:
            row_sls.append(slice(urow+1,urow+2))
        itables[corner]['uArc']= extract_cells_itable(table,row_sls,slice(0,8))
    return itables

        

def get_global_indicators(par,wa,corner):
    func_corner = re.sub('spec\.','func.',corner)
    block = 'core_' + os.getenv('PROJECT').split('_')[-1]
    tech = os.getenv('tech')
    parchive = os.getenv('PROJ_ARCHIVE')
    pstep = os.getenv('PROJECT_STEPPING')
    lastcontour = None
    csv_folder = os.path.join(wa,'runs',block,tech,'sta_pt',corner,'reports','csv')
    xlsx_path = glob.glob(csv_folder + f'/indicator_table_*.xlsx')
    df = pd.read_excel(xlsx_path[0], sheet_name='par_status')
    tag = df.loc[(df['TST'] == 'TST') & (df['par'] == par), 'sta_tag'].iloc[0]
    reftag = df.loc[(df['TST'] == 'REF') & (df['par'] == par), 'sta_tag'].iloc[0]
    ts = df.loc[(df['TST'] == 'TST') & (df['par'] == par), 'par_version'].iloc[0]
    rtl = df.loc[(df['TST'] == 'TST') & (df['par'] == par), 'par_rtl'].iloc[0]
    ######IO constraints######
    timing_collateral = os.path.join(parchive,'arc',par,'timing_collateral')
    cfolders = glob.glob(timing_collateral + f'/{pstep}*CONTOUR*')
    cfolders.sort(key = os.path.getctime)
    cfolders = cfolders[-1::-1]
    for fold in cfolders:
        if 'LATEST' in fold.split('/')[-1]:
            continue
        p = os.path.join(fold,func_corner,f'{par}_io_constraints.tcl')
        # w = os.path.join(wa,'runs',par,tech,'release','latest','timing_collateral',func_corner,f'{par}_io_constraints.tcl')
        w = os.path.join(parchive,'arc',par,'sta_primetime',tag,'timing_collateral',func_corner,f'{par}_io_constraints.tcl')
        if filecmp.cmp(p, w):
            lastcontour = fold.split('/')[-1]
            break

    return tag,reftag,ts,rtl,lastcontour

def get_clock_period(corner,wa,par,product,tech):
    p = re.sub('par_','mclk_',par)
    clock_params_tcl = os.path.join(wa,'runs/core_'+product,tech,'release/latest/clock_collateral/'+corner,'core_'+product+'_clock_params.tcl')
    pattern = rf'set cmd "set ::periodCache\({p},\$::clock_scenario\) (\d+)"'
    with open(clock_params_tcl, 'r') as file:
        for line in file:
            match = re.search(pattern, line)
            if match:
                extracted_value = match.group(1)
                return int(extracted_value)

def get_used_corners(wa,par,main_corner):
    tech = os.getenv('tech')
    product = os.getenv('PROJECT').split('_')[-1]
    sta_pt = os.path.join(wa,'runs','core_' + product,tech,'sta_pt')
    patterns = ['func.*', 'spec.*', 'fresh.*']
    #excluding .ct*
    all_corner_paths = [item for pattern in patterns for item in glob.glob(os.path.join(sta_pt, pattern)) if not re.search(r'\.ct\d+$', item)]
    itable_corners = {}
    for corner_p in all_corner_paths:
        corner = corner_p.split('/')[-1]
        clk_period = get_clock_period(corner,wa,par,product,tech)
        if get_itable_file(wa,corner,'xlsx'):
            if clk_period not in itable_corners.keys():
                itable_corners[clk_period] = [corner]
            else:
                itable_corners[clk_period].append(corner)
    max_corner_sorted_list = []
    sorted_keys = sorted(itable_corners.keys(), reverse=False)

    for k in sorted_keys:
        for c in itable_corners[k]:
            short_c = c.split('.')[1]
            if 'max' in short_c:
                max_corner_sorted_list.append(c)
            elif 'max' not in short_c and 'min' not in short_c:
                print(f'-E- not min or max corner: {c}')
    # only_max_corners = {key: value for key, value in itable_corners.items() if "min" not in value}
    # max_corner_sorted_list = [value for key, value in sorted(only_max_corners.items())]
    
    main_string = None
    if main_corner:
        for entry in max_corner_sorted_list:
            if main_corner in entry:
                main_string = entry
    if main_string:
        max_corner_sorted_list.remove(main_string)
        max_corner_sorted_list.insert(0, main_string)
    return max_corner_sorted_list

def argument_selector():
    parser = argparse.ArgumentParser(prog='xml compare',description='',epilog='')
    args_to_parse = None
    #for debugger runs
    if debugger_is_active() is not None:
        args_to_parse = ['-wa', '/nfs/site/disks/idc_gfc_fct_bu_daily/work_area/GFC_CLIENT_25ww49b_ww51_1_TIP_update-FCT26WW02A_dcm_daily-CLK023.bu_postcts/']
        args_to_parse += ['-par', 'par_msid']
        args_to_parse += ['-main_corner', 'max_high']
        args_to_parse += ['-dfx_corner', 'max_low']
        os.environ['tech'] = 'n2p_htall_conf4'
        os.environ['PROJECT'] = 'gfc_n2_client'
        os.environ['PROJ_ARCHIVE'] = '/nfs/site/disks/gfc_n2_client_arc_proj_archive'
        os.environ['PROJECT_STEPPING'] = 'GFCN2CLIENTA0'
    #end for debugger runs
    parser.add_argument('-wa', type=str, default = None, metavar = '<path>')
    parser.add_argument('-par', type=str, default = None, metavar = '<str>')
    parser.add_argument('-main_corner', type=str, default = None, metavar = '<str> - ex: max_med')
    parser.add_argument('-dfx_corner', type=str, default = None, metavar = '<str> - ex: max_med')
    # parser.add_argument('-add_corners', type=str, nargs='+', default=None, metavar = '<corner1_name> <corner2_name> ...')
    args = parser.parse_args(args=args_to_parse)

    # return args.wa, args.par, args.add_corners
    return args.wa, args.par, args.main_corner, args.dfx_corner

def main():
    # wa,par,add_corners = argument_selector()
    wa,par,main_corner,dfx_corner = argument_selector()
    #corner list -> from highest priority to lowest - highest for uArc table, lowest for dfx table
    
    corners = get_used_corners(wa,par,main_corner)
    print(corners)
    # if add_corners:
    #     for a in add_corners:
    #         init_corners.append(a)
    # corners = []
    # for corner in init_corners:
    #     if corner in all_model_corners:
    #         print(f'{corner} included in summery mail')
    #         corners.append(corner)
    # if len(corners) == 0:
    #     print('None of the init corners are in, reporting all ran corners in mail')
    #     corners = all_model_corners
    tables = get_itables(wa,par,corners)
    summary_mail(wa,par,corners,tables,main_corner,dfx_corner)

if __name__=="__main__":
    main()