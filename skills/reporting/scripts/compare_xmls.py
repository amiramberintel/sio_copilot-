#!/usr/intel/pkgs/python3/3.11.1/bin/python3
import argparse
import sys
import UsrIntel.R1
from io import StringIO, BytesIO

from lxml import etree
import pandas as pd

# columns = ['endpoint', 'slack']

def debugger_is_active() -> bool:
    """Return if the debugger is currently active"""
    return (gettrace := getattr(sys, 'gettrace')) and gettrace()



def run(xmls, outfile, columns, sort_by):
    dfs = dict()
    i = 1
    name = None
    file = None
    names = []
    add_fields = 'endpoint'
    for xml in xmls:
      if len(xml.split(':')) == 2:
        name, file = xml.split(':')
      else:
          name = f'{i}'
          file = xml
      tree = parse_xml_vrf(file)
      c = list(set([add_fields] + columns))
      dfs[name] = pd.DataFrame(tree)[c].convert_dtypes().apply(pd.to_numeric, errors="ignore").sort_values(columns,ascending=True).drop_duplicates(subset=add_fields,ignore_index=True, keep='first').set_index(add_fields)

      if len(xmls) > 1:
            dfs[name].rename(lambda x: f'{name}_{x}', axis='columns',inplace=True)

      i += 1
      names.append(name)
    new_df = dfs[names[0]]
    for name in names[1:]:
        new_df = new_df.merge(dfs[name],on=add_fields,  suffixes=(f'_{names[0]}', f'_{name}'), how='outer')
    sort_by_set = set()
    if sort_by is not None:
        sort_by_set = list(set(sort_by).intersection(new_df.columns))
        if sort_by_set and len(sort_by_set)>0:
            new_df = new_df.sort_values(sort_by_set)
    new_df.to_csv(outfile, index=True)


def parse_xml_vrf(xml):
    # parser = etree.XMLParser(recover=True)
    # return etree.parse(xml, parser) # type: ignore
    with open(xml) as f:
        ff = f.read()
        fff = ff.strip()
        if not fff.startswith('<xml'):
            ff = "<xml>\n" + ff
        if not fff.endswith('/xml>'):
            ff = ff + "\n</xml>"
        events = ("start", "end")
        context= etree.iterparse(BytesIO(ff.encode('utf-8')), huge_tree=True, tag="path",events=events) # type: ignore
        ret = []
        for action, elem in context:
            ret.append(dict(elem.attrib))
        return ret


def debug():
    xml='/nfs/site/disks/pnc_fct_bu_2/work_area/RTL_24ww16a_ww20_1_TIP_and_RCOs-FCT24WW22A_dcm-CLK172.bu_postcts/runs/core_server/1278.6/release/latest/sta_primetime/run_dir/func.min_nom_client.ttttcmintttt_100.tttt/reports/core_server.func.min_nom_client.ttttcmintttt_100.tttt_timing_summary_only_mclk_ext_10.xml'
    xml1='PROP:/nfs/site/disks/pnc_bei_ebb/core_server_etm/RTL_24ww13d_ww15_5_meu_dop_fix-FCT24WW21D_dcm_prop_clk-CLK174.bu_postcts/mlc_prop.xml'
    xml2='NO_PROP:/nfs/site/disks/pnc_bei_ebb/core_server_etm/RTL_24ww13d_ww15_5_meu_dop_fix-FCT24WW21D_dcm_prop_clk-CLK174.bu_postcts/mlc_no_prop.xml'
    run([xml1, xml2], '/tmp_proj/ayarokh/test.csv', ['slack'], None)
    return 0

def main():
    # return (debug())
    args_to_parse = None

    if debugger_is_active() is not None:
        print(f'{"!"*20} Run in DEBUG mode {"!"*20}')
        args_to_parse = ['-xmls']
        args_to_parse.append('TST:/nfs/site/disks/pnc_fct_bu_2/work_area/RTL_24ww45b_ww46_2_TIP_cells_change-FCT24WW47C_ebb_skew_paranoia-CLK077.bu_postcts/runs/core_client/1278.6/sta_pt/func.min_nom.ttttcmintttt_100.tttt/reports/core_client.func.min_nom.ttttcmintttt_100.tttt_timing_summary.xml.filtered')
        args_to_parse.append('REF:/nfs/site/disks/pnc_fct_bu_2/work_area/RTL_24ww45b_ww46_2_TIP_cells_change-FCT24WW47A_dcm-CLK077.bu_postcts/runs/core_client/1278.6/sta_pt/func.min_nom.ttttcmintttt_100.tttt/reports/core_client.func.min_nom.ttttcmintttt_100.tttt_timing_summary.xml.filtered ')
        args_to_parse.append('-csv')
        args_to_parse.append('~/tmp/output.csv')
        args_to_parse.append('-fields')
        args_to_parse.append('slack')
        args_to_parse.append('endpoint')
    args = parse_args(args_to_parse)
    out = args.csv if args.csv else sys.stdout
    run(args.xmls, out, args.fields, args.sort_by)
    return 0


def parse_args(args_to_parse=None):
    parser = argparse.ArgumentParser(
        prog='compare_xmls', description="compare xmls", formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument('-xmls', type=str,
                        help="input xml files, could be file or name:file", required=True, nargs='+',)
    parser.add_argument(
        '-csv', type=str, help="output csv file", required=False)
    parser.add_argument(
        '-fields', type=str, help="fields from xml, will be sorted also by these fields", required=False, nargs='+', default=['slack'])
    parser.add_argument(
        '-sort_by', type=str, help="list of columns to sort by, should be new names", required=False, nargs='+')
    args = parser.parse_args(args_to_parse)
    return args


if __name__ == '__main__':
    sys.exit(main())
