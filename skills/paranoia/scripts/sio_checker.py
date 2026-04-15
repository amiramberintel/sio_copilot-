#!/nfs/site/disks/ayarokh_wa/tools/python/3.11.1/bin/python3
import argparse
import datetime
import glob
import logging
import os
import resource
import sys
import xml.etree.ElementTree as ET

logger = None


def setup_logger():
    global logger
    """ setup_logger() : logger setup """
    logger = logging.getLogger(__name__)
    logging.basicConfig(
        level=logging.INFO, format='-%(levelname)-.1s- [%(asctime)s] : %(message)s')
    return logger


def sizeof_fmt(num, suffix="B"):
    for unit in ["", "Ki", "Mi", "Gi", "Ti", "Pi", "Ei", "Zi"]:
        if abs(num) < 1024.0:
            return f"{num:3.1f} {unit}{suffix}"
        num /= 1024.0
    return f"{num:.1f} Yi{suffix}"

def check_hips_xml(hips_xml):
    problems = []
    try:
        hips_xml_string = []
        with open(hips_xml) as f:
            hips_xml_string = f.readlines()
        
        hips_xml_string = list(filter(lambda x: x != '', [x.strip() for x in hips_xml_string]))
        if hips_xml_string[0].strip() != '<xml>':
            hips_xml_string.insert(0,'<xml>')
            
        if hips_xml_string[-1].strip() != '</xml>':
            hips_xml_string.append('</xml>')
        tree = ET.ElementTree(ET.fromstringlist(hips_xml_string))
    except:
        problems.append(f"HIP_XML: path: {hips_xml} - XML read failed")
        return problems
    root = tree.getroot()
    line = 0
    for child in root:
        line += 1
        hip_name = child.get('name')
        hip_path = child.get('path')
        if hip_name is None or hip_name == "":
            problems.append(f"Line {line} - HIP name not found")
        elif hip_path is None or hip_path == "":
            problems.append(f"Line {line} - HIP path not found")
        else:
            have_ldb = len(glob.glob(os.path.join(hip_path,'timing',f'{hip_name}[.,_]*.ldb'))) > 0
            if not have_ldb:
                problems.append(f"path:'{hip_path}' hip: '{hip_name}'  - LDB not found")
    return problems
def main():
    st = datetime.datetime.now()
    setup_logger()
    ret = 0
    args = parse_args()
    if args.hip_xml is not None:
        chx = check_hips_xml(args.hip_xml)
        for problem in chx:
            logger.warning(f'check_hips_xml: {problem}')
        ret = ret or len(chx)
        if len(chx) > 0:
            logger.warning(f'check_hips_xml: {args.hip_xml} failed')
    et = datetime.datetime.now()
    elapsed_time = et - st
    logger.debug(f'Execution time: {elapsed_time}, seconds')
    logger.debug(
        f'MaxRSS: {sizeof_fmt(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss)}')
    return ret


def parse_args():
    """ parse_args() : command-line parser """
    parser = argparse.ArgumentParser(
        description="Checker for sio")

    parser.add_argument('-hip_xml', type=str,
                        help="Check hips xml file, read and location",  required=False)
    args = parser.parse_args()
    return args


if __name__ == '__main__':

    sys.exit(main())
