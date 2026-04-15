#!/nfs/site/disks/ayarokh_wa/tools/python/3.11.1/bin/python3

import os
from pathlib import Path
import sys
from os import path
import compress_ports # type: ignore
import jellyfish
from tabulate import tabulate

compress = False
chars_to_remove = "_[]:{}"
max_diff_size = 5


class bcolors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

    def colored(_self_, str):
        return f'{_self_.FAIL}{str}{_self_.ENDC}'


def find_renamed_ports(removed_ports, added_ports):
    data_removed = ports_to_dict(removed_ports)
    data_added = ports_to_dict(added_ports)
    done = dict()
    removed_to_del = []
    for port_r, data_r in data_removed.items():
        todel = []
        for port_a, data_a in data_added.items():
            if False and data_r["length"] == data_a["length"]:
                count = 0
                for a, b in zip(data_r["ascii"], data_a["ascii"]):
                    if a != b:
                        count += 1
                if count <= max_diff_size:
                    todel.append([count, port_a])
            elif not False:
                ratio = jellyfish.damerau_levenshtein_distance(port_r.translate(str.maketrans(
                    '', '', chars_to_remove)), port_a.translate(str.maketrans('', '', chars_to_remove)))
                if (ratio <= max_diff_size):
                    todel.append([ratio, port_a])
        if len(todel) > 0:
            d = sorted(todel, key=lambda x: x[0])[0][1]
            done[port_r] = d
            del data_added[d]
            removed_to_del.append(port_r)
    for p in removed_to_del:
        del data_removed[p]
    return data_removed.keys(), data_added.keys(), done


def ports_to_dict(ports_list):
    ret = dict()
    for p in ports_list:
        pp = p.translate(str.maketrans('', '', chars_to_remove))
        l = list(ord(x) for x in pp)
        ret[p] = {"ascii": l, "length": len(l), "sum": sum(l)}

    return ret


def get_ports(fin):
    out = list()
    with open(fin, "r") as f:
        for l in f:
            line = l.strip()
            if line.startswith("#"):
                continue
            out.append(line)
    if len(out) == 0:
        print(f'-W- No ports found in {fin}')
    if compress:
        return compress_ports.main(out)
    return out


def compare_files(old_file_path, new_file_path):
    if not path.exists(old_file_path) or not path.exists(new_file_path):
        print(
            f"-E- input files don't exist. Check: '{old_file_path}' '{new_file_path}'")
        return
    try:
        old_lines = get_ports(old_file_path)
        new_lines = get_ports(new_file_path)
    except Exception as E:
        print("-E- couldn't open port files")
        return
    return comp(old_lines, new_lines)


def comp(old_lines, new_lines):
    added_ports = []
    removed_ports = []
    for line in new_lines:
        if line not in old_lines:
            added_ports.append(line)
    for oldline in old_lines:
        if oldline not in new_lines:
            removed_ports.append(oldline)
    return removed_ports, added_ports, len(old_lines), len(new_lines)


def compit(removed_ports, added_ports, total_old, total_new, partition):
    print(f"  {'*'*33} Comparing releases for - {partition} {'*'*33}")

    cur = {"block": partition, "total_old": total_old,
           "total_new": total_new, "removed": 0, "added": 0, "mapped": 0}
    if added_ports or removed_ports:
        removed_ports, added_ports, ports_renamed = find_renamed_ports(
            removed_ports, added_ports)
        cur["removed"] = len(removed_ports)
        cur["added"] = len(added_ports)
        cur["mapped"] = len(ports_renamed.keys())
        print("**** New Ports ****")
        print("\n".join(sorted(added_ports)))
        print("**** Removed Ports ****")
        print("\n".join(sorted(removed_ports)))
        print("**** Mapped Ports ****")
        toprint_all = []
        for f in sorted(ports_renamed.keys()):
            t = ports_renamed[f]
            if len(t.split(" ")) == 2:
                toprint = get_colorized(t.split(" ")[0], f.split(" ")[0])
                toprint_all.append([toprint[0], toprint[1], t.split(" ")[1]])
            else:
                print(f"-E-: port: {t}")
        print("\n", tabulate(toprint_all, ["FROM", "TO", "DIRECTION"]))
        print_header()
        print_one(cur)
        print("*"*100 + "\n"*2)
    return cur


def get_colorized(t, f):
    toprint = ["", ""]
    j = i = 0
    colors = bcolors()
    while (i < len(f) or j < len(t)):
        if i < len(f) and j >= len(t):
            toprint[0] += colors.colored(f[i:])
            i = len(f)+1
            break
        if j < len(t) and i >= len(f):
            toprint[1] += colors.colored(t[j:])
            j = len(t)+1
            break
        z1 = f[i]
        z2 = t[j]
        if i < len(f) and j < len(t) and z1 == z2:
            toprint[0] += z1
            toprint[1] += z2
        else:
            if i < len(f) and z1 in chars_to_remove:
                toprint[0] += colors.colored(z1)
                i += 1
                continue
            if j < len(t) and z2 in chars_to_remove:
                toprint[1] += colors.colored(z2)
                j += 1
                continue
        if i < len(f) and j < len(t) and z1 != z2:
            if i < len(f):
                toprint[0] += colors.colored(z1)
            if j < len(t):
                toprint[1] += colors.colored(z2)

        i += 1
        j += 1
    return toprint


def debugger_is_active() -> bool:
    """Return if the debugger is currently active"""
    return (gettrace := getattr(sys, 'gettrace')) and gettrace()


def main():
    # script arguments
    global compress
    old_model_dir = ""
    new_model_dir = ""
    if debugger_is_active():
        compress = 0
        old_model_dir = r'/nfs/site/proj/pnc/pnc.models.35/core/core-pnc-a0-master-24ww41b/target/core/RTP/server_1278p6/'
        new_model_dir = r'/nfs/site/proj/pnc/pnc.gk.workarea.45/core/integrate_bundle109812//target/core/RTP/server_1278p6/'
    else:
        if (len(sys.argv) < 3):
            print("please re-run with the following arguments:")
            print(sys.argv[0] +
                  " <old_model_dir> <new_model_dir> <?compress?>")
            print("example:   " + sys.argv[0] + " /p/hdk/rtl/models/xhdk74/pnc/core/core-pnc-a0-master-23ww08a/target/core/fusion/server_1278p4 /p/hdk/rtl/models/xhdk74/pnc/core/core-pnc-a0-master-23ww06c/target/core/fusion/server_1278p4/")
            exit(1)
        print(sys.argv)
        compress = len(sys.argv) == 4
        old_model_dir = sys.argv[1]
        new_model_dir = sys.argv[2]
    per_par = dict()
    # paritions_list = {"core_client": "core_client", "core_server": "core_server", "par_exe": "par_exe", "par_exe_int": "par_exe_int", "par_fe": "par_fe", "par_fma": "par_fma", "par_meu": "par_meu", "par_mlc": "par_mlc",
    #                   "par_msid": "par_msid", "par_ooo_int": "par_ooo_int", "par_ooo_vec": "par_ooo_vec", "par_pm": "par_pm", "par_pmhglb": "par_pmh", "par_tmul": "par_tmul", "par_fmav0": "par_fmav0", "par_fmav1": "par_fmav1"}
    paritions_list = {"par_exe": "par_exe", "par_fe": "par_fe", "par_meu": "par_meu", "par_mlc": "par_mlc",
                      "par_msid": "par_msid", "par_ooo_int": "par_ooo_int", "par_ooo_vec": "par_ooo_vec", "par_pm": "par_pm", "par_pmh": "par_pmh", "par_tmul_stub": "par_tmul_stub", "par_fmav0": "par_fmav0", "par_fmav1": "par_fmav1"}
    if "server" in new_model_dir:
        paritions_list['core_server'] = 'core_server'
    else:
        paritions_list['core_client'] = 'core_client'

    for parfrom, parto in paritions_list.items():
        oldfile = None
        newfile = None
        local_dirs = [f"{parto}/{parto}/syn/n2", f"{parfrom}/{parfrom}/syn/n2", 
                      f"{parto}/syn/n2", f"{parfrom}/syn/n2", 
                      f"{parfrom}/syn/1278p6", f"{parto}/syn/1278p6",
                      f"syn/1278p6/{parfrom}", f"{parfrom}/{parfrom}/syn/1278p6", f"syn/1278p6/{parto}", f"{parto}/{parto}/syn/1278p6",
                      f"{parfrom}/synth_elab", f"{parfrom}/syn/1278", f"{parto}/synth_elab", f"{parto}/syn/1278",
                      f"syn/1278/{parfrom}", f"{parfrom}/{parfrom}/syn/1278", f"syn/1278/{parto}", f"{parto}/{parto}/syn/1278"]
        for par in [parfrom, parto]:
            for local_dir in local_dirs:
                oldfile = f"{old_model_dir}/{local_dir}/{par}.ports"
                if os.path.exists(oldfile):
                    break
            if os.path.exists(oldfile): # type: ignore
                break
        for par in [parto, parfrom]:
            for local_dir in local_dirs:
                newfile = f"{new_model_dir}/{local_dir}/{par}.ports"
                if os.path.exists(newfile):
                    break
            if os.path.exists(newfile): # type: ignore
                break
        if not os.path.exists(newfile) or not os.path.exists(oldfile): # type: ignore
            print(
                f'-E- {parto}: one or both files don\'t exist: {oldfile} {newfile}')
        else:
            removed_ports, added_ports, total_old, total_new = compare_files(
                oldfile, newfile) # type: ignore
            per_par[parto] = compit(
                removed_ports, added_ports, total_old, total_new, parto)

    print_header()
    for cur in per_par.values():
        print_one(cur)
    print("*"*100 + "\n"*2)


def print_one(cur):
    print("{:<12} {:<12} {:<12} {:<10} {:<10} {:<10}".format(
        cur['block'], cur['total_old'], cur['total_new'], cur['removed'], cur['added'], cur['mapped'],))


def print_header():
    print("\n"*2 + "*"*100)
    print("{:<12} {:<12} {:<12} {:<10} {:<10} {:<10}".format(
        'Block', 'Before', 'Now', "Removed", "Added", "Mapped"))


if __name__ == '__main__':
    sys.exit(main())
