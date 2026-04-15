#!/nfs/site/disks/ayarokh_wa/tools/python/3.11.1/bin/python3

import glob
import os
from pathlib import Path
import re
import sys
from os import path
import xml.etree.ElementTree as ET
import compare_ports_between_releases as cpbr
import compress_ports


def get_pins(fin, name):
    out = list()
    with open(fin, "r") as f:
        out = list(name + "/" + l.strip() for l in f.read().split('\n'))
        out = filter(lambda x: not re.match(r'^\s*$', x), out)
    return out


def read_list_of_pins_files(fins, compress):
    out = list()
    for fin in fins:
        hip = Path(fin).stem
        out.extend(get_pins(fin, hip))
    if compress:
        return compress_ports.main(out)
    return out


def compare_files(old_file_path, new_file_path, compress):
    old_lines = read_list_of_pins_files(old_file_path, compress)
    new_lines = read_list_of_pins_files(new_file_path, compress)
    return cpbr.comp(old_lines, new_lines)


def main():
    # script arguments
    colors = cpbr.bcolors()
    if (len(sys.argv) < 3):
        print("please re-run with the following arguments:")
        print(sys.argv[0] + " <old_model_dir> <new_model_dir> <?compress?>")
        print("example:   " + sys.argv[0] + " /p/hdk/rtl/models/xhdk74/pnc/core/core-pnc-a0-master-23ww08a/target/core/fusion/server_1278p4 /p/hdk/rtl/models/xhdk74/pnc/core/core-pnc-a0-master-23ww06c/target/core/fusion/server_1278p4/")
        exit(1)
    compress = len(sys.argv) == 4
    old_model_dir = sys.argv[1]
    new_model_dir = sys.argv[2]
    per_par = dict()
    paritions_list = {"par_exe": "par_exe", "par_exe_int": "par_exe_int", "par_fe": "par_fe", "par_fma": "par_fma", "par_meu": "par_meu", "par_mlc": "par_mlc", "par_msid": "par_msid",
                      "par_ooo_int": "par_ooo_int", "par_ooo_vec": "par_ooo_vec", "par_pm": "par_pm", "par_pmhglb": "par_pmh", "par_tmul": "par_tmul", "par_fmav0": "par_fmav0", "par_fmav1": "par_fmav1"}
    # paritions_list = ["par_exe_int"]
    hips_per_par = {}
    for parfrom, parto in paritions_list.items():
        oldfiles = None
        newfiles = None
        local_paths = [f'/{parfrom}/synth_elab',
                       f'/{parfrom}/syn/1278/ebbs_pins',
                       f'/{parfrom}/{parfrom}/syn/1278/ebbs_pins',
                       f'/{parto}/synth_elab',
                       f'/{parto}/syn/1278/ebbs_pins',
                       f'/{parto}/{parto}/syn/1278/ebbs_pins',
                       f'/{parto}/syn/n2/ebbs_pins',
                       f'/{parto}/{parto}/syn/n2/ebbs_pins',
                       f'/{parto}/{parto}/syn/n2/original_ebbs_pins',
                       f'/{parfrom}/syn/n2/ebbs_pins',
                       f'/{parfrom}/{parfrom}/syn/n2/ebbs_pins',
                       f'/{parfrom}/{parfrom}/syn/n2/original_ebbs_pins',
                       ]
        for local_path in local_paths:
            if os.path.exists(old_model_dir + local_path):
                oldfiles = glob.glob(old_model_dir + local_path + "/*.pins")
                break

        for local_path in local_paths:
            if os.path.exists(new_model_dir + local_path):
                newfiles = glob.glob(new_model_dir + local_path + "/*.pins")
                break
        if oldfiles is None:
            oldfiles = []
        if newfiles is None:
            newfiles = []
        hips_old = set(Path(fin).stem for fin in oldfiles)
        hips_new = set(Path(fin).stem for fin in newfiles)

        removed_ports, added_ports, total_old, total_new = compare_files(
            oldfiles, newfiles, compress)
        cur = {"block": parto, "total_old": total_old,
               "total_new": total_new, "removed": 0, "added": 0, "mapped": 0}
        per_par[parto] = cpbr.compit(
            removed_ports, added_ports, total_old, total_new, parto)
        hips_per_par[parto] = {"all": set(list(Path(fin).stem for fin in oldfiles) +
                                          list(Path(fin).stem for fin in newfiles)),
                               "changed": set(filter(lambda x: not re.match(r'^\s*$', x), list(i.split("/")[0] for i in removed_ports) +
                                                     list(i.split("/")[0] for i in added_ports))),
                               "added": hips_new.difference(hips_old),
                               "removed": hips_old.difference(hips_new)}
    cpbr.print_header()
    for cur in per_par.values():
        cpbr.print_one(cur)
    print("*"*100 + "\n"*2)
    cols = cpbr.bcolors()
    for par in per_par.keys():
        print(f"{'*'*10} {par} hips changes")
        for cur in hips_per_par[par]["all"]:
            changed = 'Not changed'
            if cur in hips_per_par[par]["changed"]:
                changed = cols.colored('Changed')
            if cur in hips_per_par[par]["removed"]:
                changed = cols.colored('Removed')
            if cur in hips_per_par[par]["added"]:
                changed = cols.colored('Added')
            print("{:<14} {:<40} {:<12}".format("", cur, changed))


if __name__ == '__main__':
    sys.exit(main())
