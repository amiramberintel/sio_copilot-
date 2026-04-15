#!/nfs/site/disks/ayarokh_wa/tools/python/3.11.1/bin/python3

import argparse
import os
import sys
import logging

import pandas as pd
log = logging.getLogger('default')



DEBUG = True
log.setLevel(logging.ERROR if not DEBUG else logging.DEBUG)

def parse_args():
    parser = argparse.ArgumentParser(
        description='SIO merges slack files by abutted ports')
    parser.add_argument('-slack_files', type=str,
                        help='Slack files', required=True, nargs='+')
    parser.add_argument('-abutted_ports', type=str,
                        help='abutted ports file', required=True)
    parser.add_argument('-output_file', type=str,
                        help='Output merged file', required=True)
    args = parser.parse_args()
    return args

def read_abutted_ports(fin):
    '''
        Read abutted ports: format port,port_abutted
    '''
    ret = dict()
    with open(fin) as f:
        for line in f:
            line = line.strip()
            p1, p2 = line.split(",")
            if p2 != "": ret[p1] = p2
    log.debug(f'read_abutted_ports: readed: {len(ret)}')
    return ret

def read_all_slack_files(files):
    dfs = [pd.read_csv(f) for f in files]
    df = pd.concat(dfs, ignore_index=True)
    return df

def df_add_abutted_port(df, abutted_ports):
    def add_abutted_ports(port):
        done = set([port])
        abutted_port = abutted_ports[port] if port in abutted_ports else None
        while True:
            if abutted_port is None:
                break
            if abutted_port in abutted_ports and abutted_ports[abutted_port] in done:
                break
            abutted_port = abutted_ports[abutted_port] if abutted_port in abutted_ports else None
            done.add(abutted_port)
        return abutted_port
    df['abutted_port'] = df.iloc[:, 0].apply(add_abutted_ports)
    return df

def merge_by_abutted_port(df):
    df = df.merge(df, how='left', suffixes=('','_abutted'), left_on=df.columns[0], right_on='abutted_port')
    return df.drop(columns = ['abutted_port','abutted_port_abutted'])

def check_data(df, outfile):
    df = df.dropna(subset=['fct_bu_slack_abutted'])
    bad = df[df['fct_bu_slack'] != df['fct_bu_slack_abutted']]
    if len(bad) > 0:
        bad.to_csv(outfile, index = False)
        print(f'problem with data: fct_bu_slack != fct_bu_slack_abutted\nPlease review file: {outfile}')

def main():
    args = parse_args()
    abutted_ports = read_abutted_ports(args.abutted_ports)
    if len(abutted_ports) == 0:
        log.error(f'No abutted ports readed')
        return 1
    slack_df = read_all_slack_files(args.slack_files)
    slack_df = df_add_abutted_port(df = slack_df, abutted_ports=abutted_ports)
    slack_df = merge_by_abutted_port(slack_df)
    check_data(slack_df, f'{args.output_file}.problems')
    slack_df.to_csv(args.output_file, index = False)
    return 0


if __name__ == '__main__':
    sys.exit(main())
