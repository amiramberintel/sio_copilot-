#!/nfs/site/disks/ayarokh_wa/tools/python/3.11.1/bin/python3

import argparse
import json
import logging
import os
import re
import sys
import asyncio
from lxml import etree

import pandas as pd


class vrf_data:
    corename = 'icore'
    compressed_columns = ['startpoint', 'endpoint']
    dfx_pattern = []
    dfx_clock_patterns = []
    vrf_file = None
    logger = None

    def __init__(self, vrf_file) -> None:
        self.vrf_file = vrf_file
        self.setup_logger()

    def tree_sort_and_write(self, tree, file_out, sort_by='slack'):
        tree.getroot()[:] = sorted(tree.getroot(),
                                   key=lambda x: float(x.get(sort_by)))
        tree.write(file_out)

    def set_compressed_columns(self, columns_to_compress):
        self.compressed_columns = columns_to_compress

    def setup_logger(self):
        """ setup_logger() : logger setup """
        logger = logging.getLogger(__name__)
        logging.basicConfig(
            level=logging.INFO, format='-%(levelname)-.1s- [%(asctime)s] : %(message)s')

        self.logger = logger

    def set_dfx_pattern(self, dfx_pattern):
        self.dfx_pattern = []
        for d in dfx_pattern:
            self.dfx_pattern.append(rf"{d}")

    def set_dfx_clock_patterns(self, dfx_clock_patterns):
        self.dfx_clock_patterns = dfx_clock_patterns

    def is_dfx(self, str_to_check):
        # return any(x in str_to_check for x in self.dfx_pattern)
        return any(re.search(x, str_to_check) is not None for x in self.dfx_pattern)

    def parse_xml_vrf(self):
        self.logger.debug("Start parse_xml_vrf") # type: ignore
        return etree.parse(self.vrf_file) # type: ignore

    async def write_not_dfx_only(self, file_out):
        sort_by = 'slack'
        tree = self.get_dfx(True)
        self.tree_sort_and_write(tree, file_out, sort_by)
        return tree

    async def write_dfx_only(self, file_out):
        sort_by = 'slack'
        tree = self.get_dfx(False)
        self.tree_sort_and_write(tree, file_out, sort_by)
        return tree

    async def dump_xml(self, file_out):
        self.logger.debug(f"Start dump_xml") # type: ignore
        tree = self.parse_xml_vrf()
        i = 0
        icore_exists = dict()
        for element in tree.getroot():
            stpl = element.get('startpoint').split("/")
            enpl = element.get('endpoint').split("/")
            stpoint = "/".join(stpl[1:])
            enpoint = "/".join(enpl[1:])
            # if enpl[0].startswith(self.corename):
            #     element.set('endpoint', enpoint)
            if stpl[0].startswith(self.corename):
                # element.set('startpoint', stpoint)
                if stpl[0] == enpl[0]:
                    key = f'{stpoint},{enpoint}'
                    if key not in icore_exists:
                        icore_exists[key] = []
                    icore_exists[key].append([stpl[0], element])
            i += 1
            if i % 100000 == 0:
                self.logger.debug(f'{i}') # type: ignore
        for key, value in icore_exists.items():
            for v in sorted(value, key=lambda x: x[0])[1:]:
                element = v[1]
                element.getparent().remove(element)
        for element in tree.getroot():
            for name, value in element.attrib.iteritems():
                any_changed = False
                _tmp = value.split(" ")
                to_out = []
                for _t in _tmp:
                    _tt = _t.split("/")
                    if _tt[0].startswith(self.corename):
                        to_out.append("/".join(_tt[1:]))
                        any_changed = True
                    elif _tt[0].startswith("{" + self.corename):
                        to_out.append("{" + "/".join(_tt[1:]))
                        any_changed = True
                    else: to_out.append("/".join(_tt))
                if any_changed: 
                    element.set(name, " ".join(to_out))
        tree.write(file_out)

    async def to_csv(self, outfile):
        self.logger.debug("Start to_csv") # type: ignore
        tree = self.parse_xml_vrf()
        df = pd.DataFrame([dict(e.items()) for e in tree.getroot()])

        for comp in self.compressed_columns:
            df = self.compress_it(df, comp)
        df['is_dfx'] = df.apply(lambda x: \
                                self.is_dfx(x['boundary_pins']) or \
                                self.is_dfx(x['endpoint']) or \
                                self.is_dfx(x['startpoint'] or \
                                x['endpoint_clock'].lower() in self.dfx_clock_patterns or \
                                x['startpoint_clock'].lower() in self.dfx_clock_patterns), axis=1)
        if type(outfile) == type(True):
            df.to_csv(sys.stdout, index=False)
        else:
            df.to_csv(outfile, index=False)
    @staticmethod
    def get_compressed_new(node):
        rr = []
        
        #sadasd[{123}]
        rr.append(r'(?<=\[)\d+(?=\])')
        
        #asdsad_{123}
        rr.append(r'(?<=_)\d+$')
        
        #asdd_{123}_asdasd
        rr.append(r'(?<=_)\d+(?=[_/])')
        
        #asdasd/d{123}
        rr.append(r'(?<=/d)\d+$')
        
        #icore{0}/asda/asdasd
        rr.append(r'(?<=^icore)\d(?=/)')
        
        r = re.compile(f'({"|".join(rr)})')
        nums = re.findall(r, node)
        res = re.sub(r, '*', node)
        return res, nums
    
    #naive way - replace all digiits, replaced 08/09/2024, backed up 09/09/2024
    @staticmethod
    def get_compressed(node):
        r = re.compile(r'\d+')
        nums = re.findall(r, node)
        res = re.sub(r, '*', node)
        return res, nums

    def groupby_compress(self, x, by):
        str = x[f'{by}_compress_tmp'].iloc[0]
        nums = x[f'{by}_compress_nums_tmp']
        for i in range(len(nums.iloc[0])):
            nums_to_compress = [int(val[i]) for val in nums]
            nums_seq = self.list_of_numbers_to_seq(nums_to_compress)
            str = str.replace("*", nums_seq, 1)
        x[f'{by}_compress'] = str
        return x

    def compress_it(self, df, by):
        df[f'{by}_compress_tmp'], df[f'{by}_compress_nums_tmp'] = zip(
            *df.apply(lambda x: __class__.get_compressed(x[by]), axis=1))
        df = df.groupby(f'{by}_compress_tmp', group_keys=False).apply(
            lambda x: self.groupby_compress(x, by))
        df.drop(columns=[f'{by}_compress_tmp',
                f'{by}_compress_nums_tmp'], inplace=True)
        return df

    def list_of_numbers_to_seq(self, nums):
        nset = list(set(sorted(nums)))
        if len(nset) == 1:
            return str(nums[0])
        last = start = nset[0]
        out = []
        for i in nset[1:]:
            if i != last + 1:
                out.append([start, last])
                start = i
            last = i
        out.append([start, last])
        return f'{{{",".join([":".join([str(y) for y in set(x)]) for x in out])}}}'

    def get_dfx(self, remove_dfx):
        self.logger.debug("Start get_dfx") # type: ignore
        tree = self.parse_xml_vrf()
        i = 0
        for element in tree.getroot():
            removed = False
            if element.get('startpoint') is None:
                break

            is_dfx = \
                self.is_dfx(element.get('boundary_pins')) or \
                self.is_dfx(element.get('startpoint')) or \
                self.is_dfx(element.get('endpoint')) or \
                element.get('endpoint_clock').lower() in self.dfx_clock_patterns or \
                element.get('startpoint_clock').lower() in self.dfx_clock_patterns
            if (remove_dfx and is_dfx):
                element.getparent().remove(element)
                removed = True
            if not removed and not remove_dfx and not is_dfx:
                element.getparent().remove(element)
                continue

            i += 1
            if i % 100000 == 0:
                self.logger.debug(f'{i}') # type: ignore

        return tree

    async def write_not_dfx_compressed(self, file_out):
        tree = self.get_dfx(True)
        mapping = dict()
        sort_by = 'normalized_slack'
        for element in tree.getroot():
            to_test = element.get('endpoint')
            if element.get('startpoint') is None:
                break
            compressed, nums = __class__.get_compressed(to_test)
            if compressed not in mapping:
                mapping[compressed] = []
            mapping[compressed].append({'node': element, 'nums': nums})

        for compressed, data in mapping.items():
            data_sorted = sorted(
                data, key=lambda x: x['node'].get(sort_by), reverse=True)
            for d in data_sorted[1:]:
                d['node'].getparent().remove(d['node'])

        self.tree_sort_and_write(tree, file_out, sort_by)
        return tree

def read_dfx_patterns_config(config_file = None):
    '''
        DFX patterns from file:
        $PNC_FCT_SCRIPTS/dfx_patterns.json
        or
        $GFC_FCT_SCRIPTS/dfx_patterns.json
    '''
    ret = dict()
    if config_file is None:
        file_name = 'dfx_patterns.json'
        product_name = os.getenv('PRODUCT_NAME', None)
        if product_name is None:
            raise Exception("PRODUCT_NAME is not set")
        dir_to_read = None
        if product_name.startswith('PNC78'):
            dir_to_read = os.getenv('PNC_FCT_SCRIPTS',f'/nfs/site/disks/pnc_fct_bu/work_area/fct_scripts/PNC')
        elif product_name.startswith('GFCN2'):
            dir_to_read = os.getenv('GFC_FCT_SCRIPTS',f'/nfs/site/disks/pnc_fct_bu/work_area/fct_scripts/gfc_clienta0')
        if dir_to_read is None:
            raise Exception(f"Unknown project {product_name} should be PNC78* or GFCN2*")
        config_file = os.path.join(dir_to_read,file_name)
    with open(config_file) as f:
        ret = json.load(f)
    return ret

def parse_args():
    patterns = read_dfx_patterns_config()
    """ parse_args() : command-line parser """
    parser = argparse.ArgumentParser(
        prog='vrf_reports.py',
        description="Get xml and create 4 types of reports")
    parser.add_argument('-report_in', type=str,
                        help="input xml file", required=True)
    parser.add_argument('-filter_not_dfx', type=str,
                        help="xml without dfx", required=False)
    parser.add_argument('-filter_dfx', type=str,
                        help="xml dfx only", required=False)
    parser.add_argument('-filter_not_dfx_compress', type=str,
                        help="get compressed by endpoint and output line with worst normalized_slack", required=False)
    parser.add_argument('-filter_dcm', type=str,
                        help="DCM filter", required=False)
    parser.add_argument('-to_csv', type=str,
                        help="output as csv", required=False, nargs='?', const=True)
    parser.add_argument('-to_csv_columns_to_compress', type=str,
                        help="add this columns as compressed as csv", required=False, default=['startpoint', 'endpoint'], nargs='+')
    parser.add_argument('-dfx_patterns', type=str,
                        help="Set dfx patterns", required=False, default=patterns['dfx_patterns'], nargs='+')
    parser.add_argument('-dfx_clock_patterns', type=str,
                        help="Set dfx clock patterns", required=False, default=patterns['dfx_clock_patterns'], nargs='+')

    args = parser.parse_args()
    return args


async def main():
    args = parse_args()
    vd = vrf_data(args.report_in)
    vd.set_compressed_columns(args.to_csv_columns_to_compress)
    if args.dfx_patterns is not None:
        vd.set_dfx_pattern(args.dfx_patterns)
    if args.dfx_clock_patterns is not None:
        vd.set_dfx_clock_patterns(args.dfx_clock_patterns)
    async with asyncio.TaskGroup() as tg:
        if args.filter_not_dfx is not None:
            tg.create_task(vd.write_not_dfx_only(args.filter_not_dfx))
        if args.filter_dfx is not None:
            tg.create_task(vd.write_dfx_only(args.filter_dfx))
        if args.filter_not_dfx_compress is not None:
            tg.create_task(vd.write_not_dfx_compressed(
                args.filter_not_dfx_compress))
        if args.filter_dcm:
            tg.create_task(vd.dump_xml(args.filter_dcm))

        if args.to_csv is not None:
            tg.create_task(vd.to_csv(args.to_csv))
    return 0

async def debug():
    vd = vrf_data('/nfs/site/disks/pnc_fct_bu/work_area/RTL_23ww09d_ww12_1_RCOs_refresh-FCT23WW19B_dcm-CLK018.bu_postcts//runs/core_server/1278.3/sta_pt/func.max_high.TT_100.tttt/reports/core_server.func.max_high.TT_100.tttt_timing_summary.xml.filtered')
    async with asyncio.TaskGroup() as tg:tg.create_task(vd.dump_xml('/tmp_proj/ayarokh/filter_dfx_compress.xml'))
    exit(0)
if __name__ == '__main__':
    # asyncio.run(debug())
    sys.exit(asyncio.run(main()))
