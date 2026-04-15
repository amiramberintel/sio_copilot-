#!/usr/intel/pkgs/python3/3.11.1/bin/python3
import argparse
from doctest import FAIL_FAST, Example
from html import parser
from token import NEWLINE
import UsrIntel.R1
import os
import sys
import pandas as pd # type: ignore
import os
import subprocess
from datetime import datetime
# from zoneinfo import ZoneInfo
import xml.etree.ElementTree as ET
import glob
import filecmp

def debugger_is_active() -> bool:
    """Return if the debugger is currently active"""
    return (gettrace := getattr(sys, 'gettrace')) and gettrace()

def summary_mail(wa,par,corners,tables,tables2=""):
    tag,reftag,ts,rtl,contour = get_global_indicators(par,wa,corners[0])
    table_lines = []
    attachments = []
    #table[corner][int/ext/clk]
    for corner in corners:
        attachments.append(get_itable_file(wa,corner,'xlsx'))

        cor = corner.split('.')[1]
        table_lines.append(f'    <h2>{cor}</h2>')
        table_lines.append('    <p>EXT:</p>')
        table_lines.append(tables[corner]['ext'])
        if tables2:
                table_lines.append(tables2[corner]['ext'])  
        table_lines.append('    <p>INT:</p>')
        table_lines.append(tables[corner]['int'])
        if tables2:
                table_lines.append(tables2[corner]['int'])          
        table_lines.append('    <p>CLK:</p>')
        table_lines.append(tables[corner]['clk'])
    corner_name=corners[0].split('.')[1]
    table_lines.append(f'    <h2>uArcs {corner_name}</h2>')
    table_lines.append(tables[corners[0]]['uArc'])
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
        <p>Was run with:</p>
        <ul>
            <li><b>RTL:</b> {rtl}</li>
            <li><b>IO constraints:</b> {contour}</li>
            <li><b>TS:</b> {ts}</li>
        </ul>
        <p>Notes</p>
        <ul>
            <li><b>WA:</b> {os.path.abspath(wa)}</li>
            <li><b>Tag:</b> {tag}</li>
            <li><b>Ref WA</b> {os.path.realpath(wa+"/ref/")}</li>
            <li><b>Ref TAG</b> {reftag}</li>
            <li>All indicators are <u><b>uncompressed</b></u>, uArc status at end of mail</li>
        </ul>
        {table_lines}
    </body>
    </html>
    """
    # attachments.append('--')
    attachments = ' '.join(attachments)
    html_path = os.path.join(wa,'release_mail.html')
    try:
        with open(html_path, "w") as file:
            file.write(full_html)
    except PermissionError:
        html_path =os.path.join('/tmp/','release_mail.html')
        print(f'writing html at {html_path}')
        with open(html_path, "w") as file:
            file.write(full_html)


    subprocess.run(f"mutt $USER -a {attachments} -e 'set content_type=text/html' -s '{par}: {tag} CI results' < {os.path.abspath(html_path)}", shell=True, capture_output=True, text=True)
    print(f"worked on Scenraios : {corners}")
    print(f"Mail sent to {os.environ['USER']}")

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
    html_file = glob.glob(csv_path + f'/indicator_table_*.{suffix}')
    if not html_file:
        print(f"indicator_table File not found for scenario {corner} \nExiting")
        exit(1)
    return html_file[0]

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
# Legend for table rows
# title	0:1
# par_exe	1:3
# par_fe	3:5
# par_fmav0	5:7
# par_fmav1	7:9
# par_meu	9:11
# par_mlc	11:13
# par_msid	13:15
# par_ooo_int	15:17
# par_ooo_vec	17:19
# par_pm	19:21
# par_pmh	21:23
# par_tmul_stub	23:25
# Total	25:27

def get_itables(wa,par,corners ):
    if (par == 'par_meu'):
        ext_vrf_row_sls = [slice(0,5),slice(9,13),slice(15,19)]
        int_vrf_row_sls = [slice(0,1),slice(9,11)]
        clk_row_sls = [slice(0,1),slice(9,11)]
    elif (par == 'par_msid'):
        ext_vrf_row_sls = [slice(0,1),slice(3,5),slice(13,19)]
        int_vrf_row_sls = [slice(0,1),slice(13,15)]
        clk_row_sls = [slice(0,1),slice(13,15)]
    elif (par == 'par_fe'):
        #fe,msid,ooo_int,ooo_vec,pmh,mlc
        ext_vrf_row_sls = [slice(0,1),slice(3,5),slice(13,19),slice(21,23)]
        int_vrf_row_sls = [slice(0,1),slice(3,5)]
        clk_row_sls = [slice(0,1),slice(3,5)]
    elif (par == 'par_mlc'):
        #fe,meu.mlc,pm,pmh
        ext_vrf_row_sls = [slice(0,1),slice(3,5),slice(9,13),slice(19,23)]
        int_vrf_row_sls = [slice(0,1),slice(11,13)]
        clk_row_sls = [slice(0,1),slice(11,13)]
    elif (par == 'par_pm'):
        ext_vrf_row_sls = [slice(0,1),slice(11,13),slice(19,21)]
        int_vrf_row_sls = [slice(0,1),slice(19,21)]
        clk_row_sls = [slice(0,1),slice(19,21)]
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
        itables[corner]['clk']= extract_cells_itable(table,clk_row_sls,clk_cols)

        table_name = 'uArch_sum'
        table = get_itable_list(html_file,table_name)
        uarc_rows = get_uarc_rows(wa,corner,par)
        row_sls = [slice(0,1)]
        for urow in uarc_rows:
            row_sls.append(slice(urow+1,urow+2))
        itables[corner]['uArc']= extract_cells_itable(table,row_sls,slice(0,8))
    return itables


def get_itables_only_tst(wa,par,corners ):
    if (par == 'par_meu'):
        #exe,fe,meu,mlc,ooo_int,ooo_vec
        ext_vrf_row_sls = [slice(1,2),slice(3,4),slice(9,10),slice(15,16),slice(17,18)]
        int_vrf_row_sls = [slice(9,10)]
        clk_row_sls = [slice(9,10)]
    elif (par == 'par_msid'):
        #fe,msid,ooo_int,ooo_vec
        ext_vrf_row_sls = [slice(3,4),slice(13,14),slice(15,16),slice(17,18)]
        int_vrf_row_sls = [slice(13,14)]
        clk_row_sls = [slice(13,14)]
    elif (par == 'par_fe'):
        #fe,msid,ooo_int,ooo_vec,pmh,mlc
        ext_vrf_row_sls = [slice(3,4),slice(13,14),slice(15,15),slice(21,22),slice(11,12)]
        int_vrf_row_sls = [slice(3,4)]
        clk_row_sls = [slice(3,4)]
    elif (par == 'par_mlc'):
        #fe,meu.mlc,pm,pmh
        ext_vrf_row_sls = [slice(0,1),slice(3,5),slice(9,13),slice(19,23)]
        int_vrf_row_sls = [slice(11,12)]
        clk_row_sls = [slice(11,12)]
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
        itables[corner]['clk']= extract_cells_itable(table,clk_row_sls,clk_cols)

        table_name = 'uArch_sum'
        table = get_itable_list(html_file,table_name)
        uarc_rows = get_uarc_rows(wa,corner,par)
        row_sls = [slice(0,1)]
        for urow in uarc_rows:
            row_sls.append(slice(urow+1,urow+2))
        itables[corner]['uArc']= extract_cells_itable(table,row_sls,slice(0,8))
    return itables
        

def get_global_indicators(par,wa,corner):
    block = 'core_' + os.getenv('PROJECT').split('_')[-1]
    tech = os.getenv('tech')
    parchive = os.getenv('PROJ_ARCHIVE')
    pstep = os.getenv('PROJECT_STEPPING')

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
    lastcontour = ""
    for fold in cfolders:
        if 'LATEST' in fold.split('/')[-1]:
            continue
        p = os.path.join(fold,corner.replace('spec','func'),f'{par}_io_constraints.tcl')
        w = os.path.join(wa,'runs',par,tech,'release','latest','timing_collateral',corner.replace('spec','func'),f'{par}_io_constraints.tcl')
        if filecmp.cmp(p, w):
            lastcontour = fold.split('/')[-1]
            break

    return  tag,reftag,ts,rtl,lastcontour

def corner_finder(wa):
    proj=os.getenv('PROJECT').split('_')[0]
    match proj:
        case "pnc":
            main_crnr='func.max_med.ttttcmaxtttt_100.tttt'
        case 'gfc':
            main_crnr='func.max_high.T_85.typical'
        case _:
            main_crnr='func.max_med.T_85.typical'
    if os.getenv('FCT_SCENARIOS'):
        if main_crnr in os.getenv('FCT_SCENARIOS').split(','):
            corners =os.getenv('FCT_SCENARIOS').split(',')
            corners.remove(main_crnr)
            corners.insert(0,main_crnr)
        else:
            fct_scenarios=os.getenv('FCT_SCENARIOS').split(',')
            temp_main_crnr=os.getenv('FCT_SCENARIOS').split(',')[0]
            print(f'The main corner {main_crnr} does not exit in {fct_scenarios} Pleas check env/script using {temp_main_crnr}' )
            corners =os.getenv('FCT_SCENARIOS').split(',')
            print(f'Using corner:  {corners[0]} as main corner')
    else:
        crnr_dir_path=os.path.join(wa,'runs','core_'+os.getenv('PROJECT').split('_')[-1],os.getenv('tech'),'sta_pt')
        corners_paths = glob.glob(crnr_dir_path+'/f*')
        corners=[]
        for crnr in corners_paths:
            corners.append(crnr.split('/')[-1])
        if main_crnr in corners:
            corners.remove(main_crnr)
            corners.insert(0,main_crnr)
        else:
            print(f'The main corner {main_crnr} does not exit in {corners} Pleas check env/script')
            exit(1)

    return corners
    

def argument_selector():
    parser = argparse.ArgumentParser(description='Partition model Timing review mail',epilog='')
    args_to_parse = None
    parser.add_argument('-wa', type=str, default = os.getenv("ward"), metavar = '<path>')
    parser.add_argument('-par', type=str, default = 'par_fe', metavar = 'Partition name')
    parser.add_argument('-other_wa',type=str,required=False ,metavar='Other wa <Not eorking yet under development',default='')
    parser.add_argument('-scenarios',type=str,required=False ,metavar='scenarios list',default='')
    
    #for debugger runs
    if debugger_is_active() is not None:
        print("Runnig in Debug mode")
        args_to_parse =[]
    #     # args_to_parse = ['-original', '/nfs/site/disks/idc_bei_hip/PNC78CLIENTB0_HIPLIST/PNCPRODCLIENTV78_WA/latest_w_ckt_w_ssa.xml']
    #     # args_to_parse += ['-private_wa', '/nfs/site/disks/idc_bei_hip/PNC78CLIENTB0_HIPLIST/PNCPRODCLIENTV78_WA/private_hips/']
    #     # args_to_parse += ['-out_path', '/nfs/site/disks/idc_bei_hip/PNC78CLIENTB0_HIPLIST/PNCPRODCLIENTV78_WA/latest_w_ckt_w_ssa_w_joseph.xml']
        os.environ['PROJECT_STEPPING'] = 'PNC78CLIENTB0'
        os.environ['PROJECT'] = 'pnc_78_client'
        os.environ['PROJ_ARCHIVE'] = '/nfs/site/disks/pnc_78_client_arc_proj_archive'
        os.environ['tech'] = '1278.6'
        os.environ['FCT_SCENARIOS'] = 'func.max_high.ttttcmaxtttt_100.tttt,func.max_med.ttttcmaxtttt_100.tttt'
        args_to_parse = ["-wa",'/nfs/site/disks/ahaimovi_wa/RTLB0_25ww25a_client_ww25_5-FCT25WW29A_par_fe__Fsh_FrfipClkWW28_4-CLK022.bu_postcts/']
        args_to_parse += ["-other_wa",'/nfs/site/disks/ahaimovi_wa/RTLB0_25ww25a_client_ww25_5-FCT25WW28C_fe_ww28_2_short_fix-CLK022.bu_postcts/']
        args_to_parse += ["-par","par_fe"]
        
    # #end for debugger runs
 
    args = parser.parse_args(args=args_to_parse)
    return args.wa, args.par ,args.other_wa

def main():
    wa,par,wa2 = argument_selector() 
    # corners = ['func.max_med.ttttcmaxtttt_100.tttt', 'func.max_high.ttttcmaxtttt_100.tttt']
    corners = corner_finder(wa)
    # corners = ['func.max_med.ttttcmaxtttt_100.tttt', 'func.max_nom.ttttcmaxtttt_100.tttt', 'func.max_high.ttttcmaxtttt_100.tttt']
    tables = get_itables(wa,par,corners)
    
    if wa2 :
        tables2 = get_itables_only_tst(wa2,par,corners)
        summary_mail(wa,par,corners,tables,tables2)
    else:
        summary_mail(wa,par,corners,tables)

if __name__=="__main__":
    main()
