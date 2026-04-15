#!/usr/intel/bin/python3.11.1

# scipt that compress the ports with range
# how to run :
# python <script> <input.file>
# input.file is a file that conotins the port to compress ,  each port at different line

import re
import os
import sys
import itertools

def debugger_is_active() -> bool:
    """Return if the debugger is currently active"""
    return (gettrace := getattr(sys, 'gettrace')) and gettrace()


def to_ranges(iterable):
    iterable = sorted(set(iterable), key= lambda k: int(k))
    for key, group in itertools.groupby(enumerate(iterable),
                                        lambda t: int(t[1]) - int(t[0])):
        group = list(group)
        yield group[0][1], group[-1][1]


def get_compressed(node):
    rr = []

    # sadasd[{123}]
    rr.append(r'(?<=\[)\d+(?=\])')

    # asdsad_{123}
    rr.append(r'(?<=_)\d+$')

    # asdd_{123}_asdasd
    rr.append(r'(?<=_)\d+(?=[_/])')

    # asdasd/d{123}
    rr.append(r'(?<=/d)\d+$')

    # icore{0}/asda/asdasd
    rr.append(r'(?<=^icore)\d(?=/)')

    r = re.compile(f'({"|".join(rr)})')
    # nums = re.findall(r, node)
    res = re.sub(r, '*', node)
    s = re.split(r,  node)
    return res, s


def check_patterns(strings):
    d = dict()
    for s in strings:
        s = s.strip()
        c, spl = get_compressed(s)
        if c not in d:
            d[c] = list()
        d[c].append({"s": s, "spl": spl})
    ret = []
    for k, v in d.items():
        if len(v) == 1:
            ret.append(v[0]['s'])
        else:
            rrr = ""
            for i in range(len(v[0]['spl'])):
                if not i % 2:
                    rrr += v[0]['spl'][i]
                else:
                    ranges = [(r[0] if r[0] == r[1] else f'{r[0]}:{r[1]}') for r in to_ranges(
                        [vv['spl'][i] for vv in v])]
                    try:
                        ranges = sorted(ranges,key= lambda k: int(k.split(":")[0]))
                    except:
                        pass 
                    rrr += f"{{{','.join(ranges)}}}" if len(
                        ranges) > 1 or ':' in ranges[0] else ranges[0]
            ret.append(rrr)
    return ret


def main(strings):
    return check_patterns(strings)

def debug(strings):
    return check_patterns(strings)
if __name__ == '__main__':
    if debugger_is_active() is not None:
        print(f'{"!"*20} Run in DEBUG mode {"!"*20}')
        # strings = ["a/bx/[0]"]
        # strings.append("a/bx/[3]")
        # strings.append("a/bx/[4]")
        # strings.append("a/bx/[5]")
        # strings.append("a/bx/[33]")
        # strings.append("a/bc/[33]")
        # print("\n".join(main(strings)))
        # sys.exit(0)
        sys.argv = sys.argv[0:2]
        sys.argv[1] = '/nfs/site/proj/pnc/pnc.models.29/core/core-pnc-b0-master-25ww02a//target/core/RTP/server_1278p6/par_fmav1/par_fmav1/syn/1278/par_fmav1.ports'
    if (len(sys.argv) == 2):
        file_name = sys.argv[1]
        if os.path.isfile(file_name):
            ff = open(file_name)
        else:
            sys.stderr.write(f"File '{file_name}' not exists\n")
            sys.exit(1)
    else:
        if not os.isatty(sys.stdin.fileno()):
            ff = sys.stdin
        else:
            sys.stderr.write(f"File or pipe not given\n")
            sys.exit(1)
    strings = ff.readlines()
    print("\n".join(main(strings)))
    sys.exit(0)
