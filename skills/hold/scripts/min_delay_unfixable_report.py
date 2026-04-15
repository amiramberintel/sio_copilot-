#!/nfs/site/disks/ayarokh_wa/tools/python/3.11.1/bin/python3

# import UsrIntel.R2

import argparse
import asyncio
from collections import OrderedDict
import datetime
import os
import pickle
import pprint
import random
import shlex
import string
from subprocess import PIPE, Popen
import sys
import time
from lxml import etree
import multiprocessing as mp
from pathlib import Path
import pandas as pd
import signal
import xlsxwriter.utility

DEBUG = 0


def print_it(msg, do_print=True):
    if do_print:
        print(
            f'-DEBUG- {datetime.datetime.now().strftime("%d/%m/%Y, %H:%M:%S.%f")}: {msg}')
        sys.stdout.flush()


class queue_corners:
    __queues: dict

    def __init__(self, names: list[str]) -> None:
        self.__queues = {s: dict(lock=mp.Lock(
        ), jobs=dict(), not_done_count=0, finished=False) for s in set(names)}

    def add_job(self, name, key, todo):
        ''' Return True if job added, False if job exists and None if no such name'''
        if name in self.__queues:
            q = self.__queues[name]
            with q['lock']:
                if not q['finished'] and key not in q['jobs']:
                    q['jobs'][key] = dict(todo=todo, done=None, tries=0)
                    q['not_done_count'] += 1
                else:
                    return False
            return True
        return None

    def get_full_status(self):
        ret = []
        for name, q in self.__queues.items():
            with q['lock']:
                for key, value in q['jobs'].items():
                    ret.append(dict(name=name, key=key, done=value['done']))
        return ret

    def add_job_to_others(self, name, key, todo):
        for n in self.__queues.keys():
            if n != name:
                self.add_job(n, key, todo)

    def set_finished(self, name):
        '''Set this queue as finished - no more job will be added'''
        if name in self.__queues:
            q = self.__queues[name]
            with q['lock']:
                q['finished'] = True

    def is_done(self, name):
        if name in self.__queues:
            q = self.__queues[name]
            with q['lock']:
                return q['finished'] and q["not_done_count"] == 0

    def __get_next_job__(self, name, key, value, i):
        print_it(f'Todo: {name}, {key}, {i}, {value["tries"]}')
        value['done'] = False
        return key, value['todo']

    def get_next_job(self, name):
        if name in self.__queues:
            q = self.__queues[name]
            min_tries = 10
            with q['lock']:
                for key, value in q['jobs'].items():
                    if value['done'] is None:
                        value['tries'] = value['tries'] + 1
                        return self.__get_next_job__(name, key, value, q["not_done_count"])
                    elif not value['done']:
                        min_tries = min(min_tries, value['tries'])
                if min_tries < 10:
                    for key, value in q['jobs'].items():
                        if value['done'] is not None and not value['done'] and value["tries"] == min_tries:
                            return self.__get_next_job__(name, key, value, q["not_done_count"])
        return None, None

    def set_results(self, name, key, data):
        if name in self.__queues:
            q = self.__queues[name]
            with q['lock']:
                q['jobs'][key]['done'] = True
                if 'data' not in q['jobs'][key]:
                    q['not_done_count'] -= 1
                q['jobs'][key]['data'] = data
                print_it(f'Done: {name}, {key}, {q["not_done_count"]}')
                return q["not_done_count"]
        return -1

    def get_all_data(self):
        ret = dict()
        for name, q in self.__queues.items():
            with q['lock']:
                ret[name] = {key: data.get('data', None)
                             for key, data in q.get('jobs', {}).items()}
        return ret
    
    def get_count(self, name):
        return len(self.__queues.get(name, {}).get('jobs',{}))
    
    def is_fully_done(self):
        for q in self.__queues.values():
            with q['lock']:
                if q['not_done_count'] > 0:
                    return False
        return True


class server:
    __queues: queue_corners
    __port: int
    __server = None
    __random_start = ''.join(random.choices(
        string.ascii_uppercase + string.digits, k=30))
    __random_end = ''.join(random.choices(
        string.ascii_uppercase + string.digits, k=30))

    def __init__(self, queue, formatter):
        self.__queues = queue
        self.__port = -1
        self.__formatter = formatter
        if DEBUG:
            self.__random_start = 'StartMsg'
            self.__random_end = 'EndMsg'

    async def __readline_no_limit(self, reader: asyncio.StreamReader):
        """ Return a bytes object.  If there has not been a buffer
        overrun the returned value will end with include the line terminator,
        otherwise not.

        The length of the returned value may be greater than the limit
        specified in the original call to open_connection."""

        discard = False
        first_chunk = b''
        while True:
            try:
                chunk = await reader.readuntil(b'\n')
                if not discard:
                    return chunk
                break
            except asyncio.LimitOverrunError as e:
                # print(f"Overrun detected, buffer length now={e.consumed}")
                chunk = await reader.readexactly(e.consumed)
                if not discard:
                    first_chunk = chunk
                discard = True
        return first_chunk

    async def __handle_client_get_lines(self, reader: asyncio.StreamReader) -> list[str] | None:
        is_start = False
        lines = []
        while True:
            line = await self.__readline_no_limit(reader)
            line_striped = line.decode().rstrip()
            if line_striped == self.__random_end:
                break
            if is_start:
                lines.append(line_striped)
            if line_striped == self.__random_start:
                is_start = True
            if line is not None and line != '' and not is_start:
                return None
        return lines

    async def __handle_client(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
        name = None
        lines = await self.__handle_client_get_lines(reader)
        msg = b'WAIT\n'
        if lines is not None:
            got = lines[0].split(":")
            if got[0] == 'GET_STATUS':
                msg = '\n'.join([f'{b}: {c}' for a in self.__queues.get_full_status(
                ) for b, c in a.items()]).encode()
            elif got[0] == 'NEED_ME':
                _name = got[1]
                if not self.__queues.is_done(_name):
                    msg = b'NEED_YOU\n'
            elif got[0] == 'I_AM_READY':
                name = got[1]
                if self.__queues.is_done(name):
                    msg = b'WE_ARE_DONE\n'
                    name = None
            elif got[0] == 'DATA_FOR_JOB':
                _, _name, key = got
                data = lines[1:]
                formatted_data = self.__formatter(self.__queues, _name, data)
                self.__queues.set_results(_name, key, formatted_data)

        if name is not None:
            key, job = self.__queues.get_next_job(name)
            if key is not None:
                msg = f'JOB_FOR_YOU:{key}:{job}\n'.encode()
        if msg:
            writer.write(msg)
            await writer.drain()
        writer.close()
        await writer.wait_closed()
        if self.__queues.is_fully_done():
            print_it('SERVER FINISHED')
            self.close()  # type: ignore

    def close(self):
        if self.__server and self.__server.is_serving():
            self.__server.close()

    async def run_server(self, host=None, port=0):
        self.__server = await asyncio.start_server(self.__handle_client, host, port)

        self.__port = self.__server.sockets[0].getsockname()[1]
        print_it(f'Listening on {os.getenv("HOST")}:{self.__port}...')
        return self.__server

    @property
    def get_start_end(self):
        return self.__random_start, self.__random_end

    @property
    def port(self):
        return None if self.__port < 0 else self.__port


def min_delay_formatter(queue: queue_corners, name: str, data) -> dict:
    logic_count = [x for x in data if x != '' and x is not None]
    if len(logic_count) > 1 and logic_count[0] != 'NOT_ALLOWED_COMMAND':
        dd = dict(zip([x.strip() for x in logic_count[0].split(',')], [
            x.strip() for x in logic_count[1].split(',')]))
        if is_min_in_name(name):
            slack = float(dd.get('slack', None))
            if slack is not None and slack < 0.0:
                if 'all_points' in dd:
                    key, cmd = min_delay_checker_make_key_cmd(
                        dd.get("all_points", "").split(" "))
                    queue.add_job_to_others(name, key, cmd)
                else:
                    print_it(
                        f'-ERROR-: all_points not exists in {pprint.pp(dd)}')
        return dd
    return {}


def min_delay_checker_make_key(startpoint, endpoint):
    return f'{startpoint} {endpoint}'


def min_delay_checker_make_key_cmd(l):
    cmd = f'sio_mow_min_delay_min_max_logic_count {{-pba_mode path}} {{{" ".join(l)}}}'
    return min_delay_checker_make_key(l[0], l[-1]), cmd


def run_session(session, server, port, name, start, end, nb_target, nb_qslot, nb_class):
    cur_dir = os.path.dirname(__file__)
    script_to_run = f'{cur_dir}/run_pt_as_client.tcsh {session} {server} {port} {name} {start} {end}'
    nbcommand = f'nbjob run --class "{nb_class}" --qslot {nb_qslot} --target {nb_target} --properties \'sio_mow_min="{start},{end}"\' {script_to_run}'
    # print(nbcommand)
    return execute(nbcommand)


def run_sessions(sessions, server, port, start, end, number_of_nbjobs, nb_target='sc8_express', nb_qslot='bc12_pnc_fct', nb_class='SLES12&&128G&&2C'):
    i = 0
    min_to_max_ratio = 1
    while True:
        for name, session in sessions.items():
            if i >= number_of_nbjobs:
                return
            run_session(session['session'], server, port,
                        name, start, end, nb_target, nb_qslot, nb_class)
            i += 1
        j = 0
        while j < min_to_max_ratio:
            j += 1
            for name, session in sessions.items():
                if not is_min_in_name(name):
                    if i >= number_of_nbjobs:
                        print(f'2:{i}')
                        return
                    run_session(session['session'], server, port,
                                name, start, end, nb_target, nb_qslot, nb_class)
                    i += 1


def execute(cmd):
    # print(f'Start {cmd}')
    process = Popen(cmd, shell=True, stdout=PIPE)
    output = process.communicate()[0].decode().strip().split("\n")
    process.wait()
    exit_code = process.returncode
    if len(output) < 3 and ": Command not found." in output[0]:
        response = f'{cmd} command not found'
    else:
        response = output
    print_it(f'Done {cmd}: {response}')
    return response, exit_code

def get_initial_data_from_xml(xmls):
    dfs = [parse_xml(x) for x in xmls]
    df = pd.concat(dfs)
    print_it(f'Read xmls: Readed {len(df)}')
    
    # df = df[df['int_ext'] == "external"][['startpoint', 'endpoint']]
    # print_it(f'Read xmls: Externals only {len(df)}')
    df = df.drop_duplicates(subset=['startpoint','endpoint'])
    print_it(f'Read xmls: after remove duplicates {len(df)}')
    r = [dict(startpoint=row['startpoint'].strip(), endpoint=row['endpoint'].strip())
         for i, row in df.iterrows()]
    return r


def parse_xml(xmlin):
    tree = etree.parse(xmlin, parser=None)
    df = pd.DataFrame([dict(e.items()) for e in tree.getroot()])
    return df


def parse_args():
    parser = argparse.ArgumentParser(
        description='SIO MOW create report on min delay',formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument("-sessions", help="PT sessions",
                        required=True, nargs='+')
    parser.add_argument("-xmls", help="XMLs to parse",
                        required=True, nargs='+')
    parser.add_argument("-output_file", help="Output Excel file, should ends with .xlsx",
                        required=True)
    parser.add_argument("-number_of_nbjobs", help="Number of parallel sessions",
                        required=False, type=int, default=10)
    parser.add_argument("-nb_target", help="Netbatch target",
                        required=False, type=str, default="sc8_express")
    parser.add_argument("-nb_qslot", help="Netbatch qslot",
                        required=False, type=str, default="bc12_pnc_fct")
    parser.add_argument("-nb_class", help="Netbatch class",
                        required=False, type=str, default="SLES12&&128G&&2C")
    parser.add_argument("-hold_margin", help="Hold margin", required=False, type=int, default=5)
    parser.add_argument("-setup_margin", help="Setup margin", required=False, type=int, default=10)
    args = parser.parse_args()
    if args.number_of_nbjobs < len(args.sessions):
        raise Exception('Number of jobs should be greater than number of sessions')
    if not args.output_file.endswith('.xlsx'):
        raise Exception('The output file should ends with .xlsx')

    return args


async def debug_queue():
    queue = queue_corners(['a', 'b', 'c'])
    a = queue.is_fully_done()
    queue.add_job('a', 'k1', 'd1')
    queue.add_job('a', 'k2', 'd2')
    queue.add_job('a', 'k3', 'd3')
    queue.add_job_to_others('a', 'ko3', 'do3')
    a = queue.is_fully_done()
    for i in ['a', 'a', 'a', 'a', 'a', 'b', 'c', 'c']:
        key, job = queue.get_next_job(i)
        if key is not None:
            queue.set_results(i, key, 'done')

    a2 = queue.is_fully_done()
    all_data = queue.get_all_data()
    return 0


async def debug_server():
    queue = queue_corners(['a'])
    queue.add_job('a', 'k1', 'd1')
    queue.add_job('a', 'k2', 'd2')
    queue.add_job('a', 'k3', 'd3')
    ser = server(queue=queue, formatter=min_delay_formatter)
    t = await ser.run_server()
    async with t:
        await t.wait_closed()
    return


def debug_formatter():
    data = [
        'slack,cycles,norm_slack,startCLK,endCLK,startPointType,startPoint,endPointType,endPoint,prev_cycle_slack,next_cycle_slack,sio_buffs_delay,logic_cells,buff/inv,seq,ports,pars,minimum_(max_slack_on_path),maximum_(max_slack_on_path),path_group,prev_args,next_args,all_points']
    data.append('-13.958701,1.0,,136.041351,262.549530,F,icore0/par_exe/exe_vec/miv0std1d/auto_vector_MBIT_miStDataM307H_reg_v_0__hi_8__MBIT_miStDataM307H_reg_v_0__hi_9__MBIT_miStDataM307H_reg_v_0__hi_10__MBIT_miStDataM307H_reg_v_0__hi_11__MBIT_miStDataM307H_reg_v_0__hi_12__MBIT_miStDataM307H_reg_v_0__hi_13__MBIT_miStDataM307H_reg_v_0__hi_14__MBIT_miStDataM307H_reg_v_0__hi_15_/clk,F,icore0/par_fmav0/vfpbypdpv0/auto_vector_MBIT_dcLdDataM806H_reg_21__79__MBIT_dcLdDataM806H_reg_21__78__MBIT_dcLdDataM806H_reg_21__77__MBIT_dcLdDataM806H_reg_21__76__MBIT_dcLdDataM806H_reg_21__75__MBIT_dcLdDataM806H_reg_21__74__MBIT_dcLdDataM806H_reg_21__73__MBIT_dcLdDataM806H_reg_21__72_/d5,1000191.437500,1000030.625000,0.0,2,1,2,"( icore0/par_exe/miqsfstdatam307h_10_[75] icore0/par_fmav0/miqsfstdatam307h_10_[75] )",icore0/par_exe icore0/par_fmav0,999982.125,1000041.8125,mclk_fmav0,"-to icore0/par_exe/exe_vec/miv0std1d/auto_vector_MBIT_miStDataM307H_reg_v_0__hi_8__MBIT_miStDataM307H_reg_v_0__hi_9__MBIT_miStDataM307H_reg_v_0__hi_10__MBIT_miStDataM307H_reg_v_0__hi_11__MBIT_miStDataM307H_reg_v_0__hi_12__MBIT_miStDataM307H_reg_v_0__hi_13__MBIT_miStDataM307H_reg_v_0__hi_14__MBIT_miStDataM307H_reg_v_0__hi_15_/d4","-from icore0/par_fmav0/vfpbypdpv0/auto_vector_MBIT_dcLdDataM806H_reg_21__79__MBIT_dcLdDataM806H_reg_21__78__MBIT_dcLdDataM806H_reg_21__77__MBIT_dcLdDataM806H_reg_21__76__MBIT_dcLdDataM806H_reg_21__75__MBIT_dcLdDataM806H_reg_21__74__MBIT_dcLdDataM806H_reg_21__73__MBIT_dcLdDataM806H_reg_21__72_/clk -through icore0/par_fmav0/vfpbypdpv0/auto_vector_MBIT_dcLdDataM806H_reg_21__79__MBIT_dcLdDataM806H_reg_21__78__MBIT_dcLdDataM806H_reg_21__77__MBIT_dcLdDataM806H_reg_21__76__MBIT_dcLdDataM806H_reg_21__75__MBIT_dcLdDataM806H_reg_21__74__MBIT_dcLdDataM806H_reg_21__73__MBIT_dcLdDataM806H_reg_21__72_/o5",icore0/par_exe/exe_vec/miv0std1d/auto_vector_MBIT_miStDataM307H_reg_v_0__hi_8__MBIT_miStDataM307H_reg_v_0__hi_9__MBIT_miStDataM307H_reg_v_0__hi_10__MBIT_miStDataM307H_reg_v_0__hi_11__MBIT_miStDataM307H_reg_v_0__hi_12__MBIT_miStDataM307H_reg_v_0__hi_13__MBIT_miStDataM307H_reg_v_0__hi_14__MBIT_miStDataM307H_reg_v_0__hi_15_/clk icore0/par_exe/exe_vec/miv0std1d/auto_vector_MBIT_miStDataM307H_reg_v_0__hi_8__MBIT_miStDataM307H_reg_v_0__hi_9__MBIT_miStDataM307H_reg_v_0__hi_10__MBIT_miStDataM307H_reg_v_0__hi_11__MBIT_miStDataM307H_reg_v_0__hi_12__MBIT_miStDataM307H_reg_v_0__hi_13__MBIT_miStDataM307H_reg_v_0__hi_14__MBIT_miStDataM307H_reg_v_0__hi_15_/o4 icore0/par_exe/exe_vec/miv0std1d/p0043A4521/b icore0/par_exe/exe_vec/miv0std1d/p0043A4521/o icore0/par_exe/exe_vec/miv0std1d/miQSFStDataM307H[10][75] icore0/par_exe/exe_vec/miqsfstdatam307h_10_[75] icore0/par_exe/invs_place_FE_OFC715728_miqsfstdatam307h_10__75/a icore0/par_exe/invs_place_FE_OFC715728_miqsfstdatam307h_10__75/o icore0/par_exe/miqsfstdatam307h_10_[75] icore0/par_fmav0/miqsfstdatam307h_10_[75] icore0/par_fmav0/vfpbypdpv0/miQSFStDataM307H[10][75] icore0/par_fmav0/vfpbypdpv0/ctmi_356552/sa icore0/par_fmav0/vfpbypdpv0/ctmi_356552/o icore0/par_fmav0/vfpbypdpv0/auto_vector_MBIT_dcLdDataM806H_reg_21__79__MBIT_dcLdDataM806H_reg_21__78__MBIT_dcLdDataM806H_reg_21__77__MBIT_dcLdDataM806H_reg_21__76__MBIT_dcLdDataM806H_reg_21__75__MBIT_dcLdDataM806H_reg_21__74__MBIT_dcLdDataM806H_reg_21__73__MBIT_dcLdDataM806H_reg_21__72_/d5')
    r = min_delay_formatter(queue_corners(['.min_']), '.min_', data)
    sys.exit(0)
    return r
def tcl_list_add_element(cache, element):
    if element != '':
        cache[-1].append(element)
    return ''

def tcl_list_parse(tcl_list):
    """ Parse TCL list to Python list """    
    out = []
    cache = [out]
    element = ''
    escape = False
    for char in tcl_list:
        if escape:
            element += char
            escape = False
        elif char == "\\":
            escape = True
        elif char in [" ", "\t", "\r", "\n"]:
            element = tcl_list_add_element(cache, element)
        elif char == "{":
            a = []
            cache[-1].append(a)
            cache.append(a)
        elif char == "}":
            element = tcl_list_add_element(cache, element)
            cache.pop()
        else:
            element += char
    return out[0]

def is_min_in_name(name):
    return '.min_' in name


def init_queue(sessions, xmls):
    names = dict()
    for n in sessions:
        p = Path(n)
        if not p.exists():
            raise Exception(f'Session not exists: {n}')
        if not p.is_dir():
            raise Exception(f'Session not directory: {n}')
        if p.name in names:
            raise Exception(f'Session already exists directory: {n}')
        names[p.name] = {'is_min': is_min_in_name(p.name), 'session': n}
    if DEBUG == 1:
        data = [dict(startpoint='icore0/par_meu/channel_repeater_par_tmul_via_par_meu/i_ult_channel_repeater/uscan_so_reg_5_/clkb',
                     endpoint='icore0/par_pmh/ssn_scan_host_pmh_ssh/ssn_scan_host_pmh_ssh/ssn_scan_host_pmh_ssh_wrapper_tessent_ssn_scan_host_1_inst/datapath/from_scan_out_clst_ultiscan_tmul_ret_p_reg_5_/d')]
    else:
        data = get_initial_data_from_xml(xmls)
    data = [x for x in data if not (x['startpoint'].startswith(
        'icore1') and x['endpoint'].startswith('icore1'))]
    print_it(f'After removed icore1 - icore1: {len(data)}')
    if DEBUG:
        data = data[0:1000]

    queue = queue_corners(list(names.keys()))
    for n in [key for key, v in names.items() if v['is_min']]:
        for d in data:
            key, cmd = min_delay_checker_make_key_cmd(
                [d.get("startpoint"), d.get("endpoint")])
            queue.add_job(n, key, cmd)
        queue.set_finished(n)
    return queue, names

def find_nom_corner(min_corners):
    k = list(filter(lambda k: not min_corners[k] and '_nom' in k, min_corners.keys()))
    if len(k)> 0:
        return k[0]
    else:
        print_it(f'Error: cannot find nominal corner, use first corner as period basis: {list(min_corners.keys())[0]}')
        return list(min_corners.keys())[0]
def make_min_max_csv(results, outfile, setup_margin, hold_margin):
    setup_to_hold_factor = 2
    # ct = dict(high=182, nom=294, low=414, fast=178,
    #           med=214, turbo=178, ulow=758)
    # ct_by_corner = {name: ct[next(x for x in ct.keys(
    # ) if f'_{x}' in name)] for name in results.keys()}

    filters = dict(min=['norm_slack', 'prev_cycle_slack', 'minimum_(max_slack_on_path)', 'maximum_(max_slack_on_path)', 'all_points', 'next_cycle_slack',], all=[
        'prev_args', 'next_args', 'debug_data'])
    all_keys = {key for i in results.values() for key in i.keys()}
    min_corners = {name: is_min_in_name(name) for name in results.keys()}
    ret = []
    nom_corner = find_nom_corner(min_corners=min_corners)
    for key in all_keys:
        d = OrderedDict()
        for name, value_per_session in results.items():
            d[('-', f'key')] = key
            d[('-', f'unified worst setup slack ({setup_margin} gb)')] = None
            d[('-', f'(hold and setup)<0')] = None
            d[('-', f'|{setup_to_hold_factor}*hold|>setup')] = None
            d[('-', f'unfixable')] = None
            d[('-', f'unified worst hold slack (to {hold_margin})')] = None
            for k, v in value_per_session.get(key, {}).items():
                if name in min_corners and k in filters['min']:
                    continue
                if k in filters['all']:
                    continue
                d[(name, k)] = v.strip()
        ret.append(d)
    df = pd.DataFrame.from_records(ret)
    df = df.apply(pd.to_numeric, errors='coerce').fillna(df)
    df = df[df[[(n, 'slack') for n in set(
        [i[0] for i in df.columns if min_corners.get(i[0], False)])]].min(axis=1) < 0]
    df.sort_values(by=[(n, 'slack') for n in set([i[0] for i in df.columns if min_corners.get(
        i[0], False)])], axis=0, inplace=True)  # type: ignore

    df.columns = pd.MultiIndex.from_tuples(df.columns)
    df = df.set_index([('-', 'key')]).rename_axis(index=None,
                                                  columns=('-', 'key'))
    print_it(outfile)
    with pd.ExcelWriter(outfile, engine='xlsxwriter') as writer:
        df.to_excel(writer, sheet_name='data')
        worksheet = writer.sheets['data']
        i = 3
        min_slacks = [(n, 'slack') for n in set([i[0]
                                               for i in df.columns if min_corners.get(i[0], False)])]
        ct = df.columns.get_loc((nom_corner, 'end_point_period'))+1 # type: ignore
        xlsx_ct = xlsxwriter.utility.xl_rowcol_to_cell(row=i,col=ct)
        for _, row in df[min_slacks].iterrows():
            d = []
            for ii in row.keys():
                k = df.columns.get_loc(ii)+1  # type: ignore
                
                ct_by_corner = df.columns.get_loc((ii[0], 'end_point_period'))+1 # type: ignore
                xlsx_ct_by_corner = xlsxwriter.utility.xl_rowcol_to_cell(row=i,col=ct_by_corner)
                d.append(
                    f'({xlsxwriter.utility.xl_rowcol_to_cell(row=i,col=k)} - {hold_margin})*{xlsx_ct}/{xlsx_ct_by_corner}')
            worksheet.write_formula(xlsxwriter.utility.xl_rowcol_to_cell(
                row=i, col=5), f'=MIN({",".join(d)})')
            i += 1

        i = 3
        max_slasks = [(n, 'max_of(max_slack)_(maximum_max_slack)_path_from_min_corner')
                      for n in set([i[0] for i in df.columns if not min_corners.get(i[0], True)])]
        for _, row in df[max_slasks].iterrows():
            d = []
            for ii in row.keys():
                k = df.columns.get_loc(ii)+1  # type: ignore
                ct_by_corner = df.columns.get_loc((ii[0], 'end_point_period'))+1 # type: ignore
                xlsx_ct_by_corner = xlsxwriter.utility.xl_rowcol_to_cell(row=i,col=ct_by_corner)
                d.append(
                    f'({xlsxwriter.utility.xl_rowcol_to_cell(row=i,col=k)}-{setup_margin})*{xlsx_ct}/{xlsx_ct_by_corner}')
            worksheet.write_formula(xlsxwriter.utility.xl_rowcol_to_cell(
                row=i, col=1), f'=MIN({",".join(d)})')
            worksheet.write_formula(xlsxwriter.utility.xl_rowcol_to_cell(
                row=i, col=2), f'=IF({xlsxwriter.utility.xl_rowcol_to_cell(row=i,col=1)}<0,1,0)')
            worksheet.write_formula(xlsxwriter.utility.xl_rowcol_to_cell(
                row=i, col=3), f'=IF(ABS({setup_to_hold_factor}*{xlsxwriter.utility.xl_rowcol_to_cell(row=i,col=5)})>{xlsxwriter.utility.xl_rowcol_to_cell(row=i,col=1)},1,0)')
            worksheet.write_formula(xlsxwriter.utility.xl_rowcol_to_cell(
                row=i, col=4), f'=OR({xlsxwriter.utility.xl_rowcol_to_cell(row=i,col=2)},{xlsxwriter.utility.xl_rowcol_to_cell(row=i,col=3)})')
            i += 1

    return


def debug_xmls():
    sessions = ['/nfs/site/disks/pnc_fct_bu/work_area/fct_scripts/PNC/links//latest_pnc0a_1278_core_server_bu_postcts/runs/core_server/1278.6/sta_pt/func.min_nom_client.ttttcmintttt_100.tttt/outputs/core_server.pt_session.func.min_nom_client.ttttcmintttt_100.tttt/']
    xmls = ['/nfs/site/disks/pnc_fct_bu/work_area/fct_scripts/PNC/links/latest_pnc0a_1278_core_server_bu_postcts/runs/core_server/1278.6/sta_pt/func.min_nom_client.ttttcmintttt_100.tttt/reports/core_server.func.min_nom_client.ttttcmintttt_100.tttt_timing_summary.xml']
    output_file = '/nfs/site/home/ayarokh/tmp/async_data.csv'
    return sessions, xmls, output_file


def sigterm_handler(queue, output_file, server: server):
    save_data(queue.get_all_data(), f'{output_file}.pkl')
    server.close()
    make_min_max_csv(queue.get_all_data(), output_file, 20, 5)
    sys.exit(1)


def debug_csv():
    fin = '/nfs/site/disks/pnc_bei_ebb/ayarokh/PTECO/ww26d24_exe/min_delay_unfixable_after_loop6'
    with open(f'{fin}.xlsx.pkl', 'rb') as f:
        data = pickle.load(f)
    make_min_max_csv(data, f'{fin}_test.xlsx', 20, 5)
    sys.exit(0)
    return


async def main():
    # sessions, xmls, output_file = debug_xmls()
    # debug_csv()
    # debug_fromatter()
    print_it(shlex.join(sys.argv[:]))
    args = parse_args()
    sessions = args.sessions
    xmls = args.xmls
    output_file = args.output_file
    number_of_nbjobs = args.number_of_nbjobs
    nb_target = args.nb_target
    nb_qslot = args.nb_qslot
    nb_class = args.nb_class
    queue, names = init_queue(sessions, xmls)
    
    ser = server(queue=queue, formatter=min_delay_formatter)
    start, end = ser.get_start_end
    print_it(list(names.keys()))
    print_it(f'{start} {end}')
    t = await ser.run_server(port=9924)
    if DEBUG == 0:
        run_sessions(names, os.getenv('HOST'), ser.port,
                     start, end, number_of_nbjobs, nb_target=nb_target, nb_qslot=nb_qslot, nb_class=nb_class)
    signal.signal(signal.SIGINT, lambda signum, frame: sigterm_handler(
        queue, output_file, ser))
    async with t:
        await t.wait_closed()
    save_data(queue.get_all_data(), f'{output_file}.pkl')
    make_min_max_csv(queue.get_all_data(), output_file, args.setup_margin ,  args.hold_margin)


def save_data(data, output):
    with open(output, 'wb') as f:
        pickle.dump(data, f)


if __name__ == '__main__':
    # debug_csv()
    asyncio.run(main())
