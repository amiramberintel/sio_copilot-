#!/nfs/site/disks/ayarokh_wa/tools/python/3.11.1/bin/python3

import argparse
import gzip
import logging
import os
import pathlib

import numpy as np


class open_file(object):
    def __init__(self, file_name):
        self.file_name = file_name

    def __enter__(self):
        if '.gz' in pathlib.Path(self.file_name).suffixes:
            self.out = gzip.open(self.file_name, 'rt')
        else:
            self.out = open(self.file_name, 'r')
        return self.out

    def __exit__(self, *args):
        self.out.close()


def logger_init(verbose):
    global logger
    """ setup_logger() : logger setup """
    logger = logging.getLogger(__name__)
    logging.basicConfig(
        level=logging.INFO if verbose else logging.WARNING, format='-%(levelname)-.1s- [%(asctime)s] : %(message)s')
    return logger


def read_loc(file_in):
    logger.info(f"Read .loc file:\n   {file_in}")
    loc_out = dict()
    with open(file_in) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#'):
                keys = ['template', 'inst', 'x', 'y', 'flip', 'rotate']
                vals = line.split(' ')
                d = dict(zip(keys, vals))
                d["depth"] = d["inst"].count('/')+1
                d['transform'] = dict(x=int(d['x'])/1000,y=int(d['y'])/1000, flip=d['flip'], rotate=d['rotate'])
                if vals[0] not in loc_out:
                    loc_out[vals[0]] = list()
                loc_out[vals[0]].append(d)
    return loc_out

def apply_matrix(x,y , matrix):
    a, b, _ = matrix @ [x, y, 1]
    return a, b

def oasis_transform_to_matrix_6(flip, rotate, x, y):
    m = [[1, 0, x], [0, 1, y], [0, 0, 1]]
    if flip == "flip_y":
        m = [[-1, 0, x], [0, 1, y], [0, 0, 1]]
    if flip == "flip_x":
        m = [[1, 0, x], [0, -1, y], [0, 0, 1]]
    return np.array(m)


def read_spef(spef_in_file, out_file, matrx = None, ports_only = True):
    logger.info(f'Converting {spef_in_file} to {out_file}')
    count_errors = 0
    count_errors_max = 10
    round_precision = 4
    with open(out_file, 'w') as out:
        if matrx:
            out.write('inst_name,name,direction,cell,x,y,x_inst,y_inst\n')
        else:
            out.write('name,direction,cell,x,y\n')
        with open_file(spef_in_file) as f:
            names_dict = dict()
            layers_dict = dict()
            delimeter = conn_count = None
            start = layers_map = name_map = is_conn = False
            count_line = 0
            for line_ref in f:
                count_line += 1
                line = line_ref.strip()
                if not start:
                    if line.startswith('*C_UNIT'):
                        lline = line.split(' ')
                        cscale = float(lline[1])
                        if cscale != 1.0:
                            c_factor = cscale
                        if lline[2] == 'PF':
                            c_factor *= 1000
                    if line.startswith('*R_UNIT'):
                        lline = line.split(' ')
                        cscale = float(lline[1])
                        if cscale != 1.0:
                            r_factor = cscale
                        if lline[2] == 'KOHM':
                            r_factor *= 1000
                    if line.startswith('*DELIMITER'):
                        delimeter = line[-1]
                        continue
                    if line.startswith('*NAME_MAP'):
                        name_map = True
                        continue
                    if line.startswith('// *LAYER_MAP'):
                        layers_map = True
                        continue
                    if line.startswith('*D_NET'):
                        start = True
                        logger.info('End definition')
                        name_map = layers_map = False
                    if name_map and len(line) > 0:
                        lline = line.split(' ')
                        names_dict[int(lline[0][1:])] = lline[1]
                    if layers_map and len(line) > 0:
                        lline = line.split(' ')
                        layer = (lline[3].split('=')[1] if len(
                            lline) == 4 else lline[2]).lower()
                        layers_dict[int(lline[1][1:])] = layer.replace('metal', 'm').replace('met', 'm').replace('via', 'v')
                    if len(line) == 0:
                        if names_dict:
                            name_map = False
                        if layers_dict:
                            layers_map = False
                        continue
                if start:
                    if len(line) == 0:
                        is_conn = False
                    if is_conn and line.startswith('*'):
                        lline = line.split(' ')
                        cell = ''
                        pin = ''
                        direction = ''
                        ls = lline[1].split(delimeter)
                        namestr = ls[0]
                        name_ref = ''
                        x = ""
                        y = ""
                        if '*C' in lline[3:]:
                            x = lline[(s:=lline.index('*C', 3))+1]
                            y = lline[s+2]
                        if len(ls) > 1:
                            pin = ls[1]
                        if lline[0]== '*P':
                            direction = lline[2]
                            name_ref = names_dict[int(lline[1][1:])]
                            if matrx:
                                for inst, m in matrx.items():
                                    try:
                                        x_tr, y_tr = apply_matrix(float(x), float(y), m)
                                        out.write(f'{inst}/{name_ref},{name_ref},{direction},{cell},{x},{y},{round(x_tr,round_precision)},{round(y_tr,round_precision)}\n')
                                    except Exception as e:
                                        if count_errors < count_errors_max:
                                            logger.warning(f'Error in line (probably spef was\'t created in StarRC) {count_line}: "{line}"')
                                        count_errors += 1
                                        
                            else:
                                out.write(f'{name_ref},{direction},{cell},{x},{y}\n')
                        if not ports_only and lline[0] == '*I':
                            if '*D' in lline[4:]:
                                cell_id = lline.index('*D', 4)+1
                                cell = lline[cell_id]
                            direction = lline[2]
                            name_ref = f'{names_dict[int(namestr[1:])]}/{pin}'
                            if matrx:
                                for inst, m in matrx.items():
                                    x_tr, y_tr = apply_matrix(float(x), float(y), m)
                                    out.write(f'{inst}/{name_ref},{name_ref},{direction},{cell},{x},{y},{round(x_tr,round_precision)},{round(y_tr,round_precision)}\n')
                            else:
                                out.write(f'{name_ref},{direction},{cell},{x},{y}\n')
                    else:
                        is_conn = False
                    if line.startswith('*CONN'):
                        is_conn = True
        logger.info('Done')
        if count_errors > 0:
            logger.warning(f'Found {count_errors} errors')
def get_args():
    parser = argparse.ArgumentParser(description='Dump SPEF\'s ports locations to CSV')
    parser.add_argument('-spef_file', required=True, type=str, help='Input block\'s SPEF file')
    parser.add_argument('-out_file', required=False, type=str, help='Output CSV file')
    parser.add_argument('-loc_file', required=False, type=str, help='Location file (aka .loc file)')
    parser.add_argument('-name', required=False, type=str, help='partition name, if not given will use name from the spef file')
    parser.add_argument('-verbose', required=False, action='store_true', help='Verbose mode')
    args = parser.parse_args()
    name = args.name
    if args.name is None and args.spef_file is not None:
        name = args.spef_file.split('/')[-1].split('.')[0]
    
    out_file = args.out_file
    if out_file is None:
        out_file = f'./{name}.ports_from_spef.csv'
        # make realpath from out_file
        out_file = os.path.realpath(out_file)
    spef_file = args.spef_file
    loc_file = args.loc_file
    if not loc_file:
        loc_file = os.getenv('PROJ_ARCHIVE') + "/arc/" + os.getenv('MODEL_BLOCK') + "/self_collateral/" + os.getenv('SELF_COLLATERAL_TAG') + "/standard/" + os.getenv('MODEL_BLOCK') + ".loc"
    verbose = args.verbose
    return spef_file, out_file, loc_file, name, verbose
if __name__ == '__main__':

    # spef_file = '/nfs/site/disks/gfc_n2_client_arc_transaction_0000/par_vpmm/sta_primetime/GFCN2CLIENTA0_SC8_VER_005/par_vpmm.typical_85.spef.gz'
    # out_file = f'/nfs/site/disks/ayarokh_wa/tmp/read_spef.csv'
    # name = 'par_vpmm'
    # loc_file = '/nfs/site/disks/gfc_n2_client_arc_proj_archive/arc/core_client/self_collateral//GFC_25ww11a_ww15_2_RCOs/standard/core_client.loc'
    spef_file, out_file, loc_file, name, verbose = get_args()
    logger = logger_init(verbose)
    logger.info(f'\n{spef_file=}\n{out_file=}\n{loc_file=}\n{name=}')
    matrx = None
    if loc_file:
        ld = read_loc(loc_file)
        matrx = {m['inst']:oasis_transform_to_matrix_6(**m['transform']) for m in ld[name]}
    else:
        logger.warning(f'No location file provided')
    read_spef(spef_file, out_file, matrx)
