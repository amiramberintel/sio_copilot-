#!/nfs/site/disks/ayarokh_wa/tools/python/3.11.1/bin/python3
import os
import sys
import glob

from def_parser import *


class def_loc:
    tag = None
    defs_dir = None
    defs_data = dict()
    inst_to_template = dict()
    transform_per_template = None
    root = None

    def __init__(self, tag=os.getenv('TD_COLLATERAL_TAG'), defs_dir=os.getenv('PROJ_ARCHIVE') + '/arc', root="core_server"):
        self.tag = tag
        self.defs_dir = defs_dir
        self.root = root
        self.get()

    def port_from_def_to_root(self, port):
        inst = self.check_if_instance_exists(port)
        template = self.inst_to_template[inst]
        port_name = port[len(inst)+1:]
        d = next(item for item in self.transform_per_template[template] if item["inst"] == inst)
        ddata = self.defs_data.get(template)
        if ddata is None:
            return -1,-1
        pin = ddata.pins.get_pin(port_name)
        if pin is None or pin.placed is None:
            return -1,-1
        mat = oasis_transform_to_matrix_6(d['flip'],d['rotate'],int(d['x'])/1000,int(d['y'])/1000)
        return self.apply_matrix((pin.placed[0])/ddata.scale,(pin.placed[1])/ddata.scale,mat)

    def read_loc(self, file_in):
        print(f"Read .loc file:\n   {file_in}")
        loc_out = dict()
        with open_file(file_in) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#'):
                    keys = ['template', 'inst', 'x', 'y', 'flip', 'rotate']
                    vals = line.split(' ')
                    d = dict(zip(keys, vals))
                    d["depth"] = d["inst"].count('/')+1
                    if vals[0] not in loc_out:
                        loc_out[vals[0]] = list()
                    loc_out[vals[0]].append(d)
                    self.inst_to_template[d["inst"]] = d["template"]
        self.transform_per_template = loc_out

    def check_if_instance_exists(self, instance):
        instl = instance.split("/")
        for i in range(len(instl),0,-1):
            inst = "/".join(instl[0:i])
            if inst in self.inst_to_template:
                return inst
        return None
    
    def point_to_root(self,x,y,instance):
        inst = self.check_if_instance_exists(instance=instance)
        template = self.inst_to_template[inst]
        d = next(item for item in self.transform_per_template[template] if item["inst"] == inst)
        mat = oasis_transform_to_matrix_6(d['flip'],d['rotate'],int(d['x'])/1000,int(d['y'])/1000)
        return self.apply_matrix(x,y,mat)


    def read_def(self, file_in, partitions):
        def_parser = DefParser(file_in)
        def_parser.parse()
        self.defs_data[partitions] = def_parser

    def get(self):
        done = dict()
        self.read_loc(
            f'{self.defs_dir}/{self.root}/self_collateral/{self.tag}/standard/{self.root}.loc')
        for f in glob.glob(f'{self.defs_dir}/{self.root}/self_collateral/{self.tag}/standard/{self.root}.def') +\
                glob.glob(f'{self.defs_dir}/*/td_collateral/{self.tag}/standard/[par_,icore]*.def'):
            par = '_'.join(os.path.basename(f).split('_')[:-1])
            if par not in self.transform_per_template and par == self.root:
                self.transform_per_template[par] = [{'template': par, 'inst': par, 'x': 0, 'y': 0,
                'flip': 'flip_none', 'rotate': 'rotate_none', 'depth': 0}]
            if par not in self.transform_per_template or par in done:
                continue
                # self.transform_per_template[par] = [{'template': par, 'inst': par, 'x': 0, 'y': 0,
                #               'flip': 'flip_none', 'rotate': 'rotate_none', 'depth': 0}]
            print(f"Read .def file:\n   {f}")
            done[par] = True
            self.read_def(f,par)
            shape = self.defs_data[par].dieshape
            for p in self.transform_per_template[par]:
                p["shape"] = shape
        return self.transform_per_template

    def apply_matrix(self,x, y, m):
        x *= m[0]
        y *= m[3]
        x += m[4]
        y += m[5]
        return round(x,2), round(y,2)


def oasis_transform_to_matrix_6(flip, angle, x, y):
    m = [1, 0, 0, 1, x, y]
    if flip == "flip_y":
        m = [-1, 0, 0, 1, x, y]
    if flip == "flip_x":
        m = [1, 0, 0, -1, x, y]
    return m


if __name__ == '__main__':
    sys.exit(0)
