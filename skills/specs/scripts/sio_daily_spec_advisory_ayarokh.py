#!/nfs/site/disks/ayarokh_wa/tools/python/3.11.1/bin/python3

import argparse
import os
import re
import sys
import logging
import numpy as np
import pandas as pd
log = logging.getLogger('default')


DEBUG = True
log.setLevel(logging.ERROR if not DEBUG else logging.DEBUG)


def parse_args():
    parser = argparse.ArgumentParser(
        description='SIO advisor \n* Compress the file – write for each bus, WC FCT slack (column 5) and WC partition slack (column 4) \n* Add comments according to the following: \n   V If FCT < 0 and PAR > 0: “consider stress spec" \n   V If FCT > 0 and PAR < 0: "consider to relax spec"')
    parser.add_argument('-slack_files', type=str,
                        help='Slack files', required=True, nargs='+')
    args = parser.parse_args()
    return args


def add_compress_to_df(df, by):
    regex = r'(?<=\[)\d+?(?=\])|(?<=_)\d+?(?=_)|(?<=_)\d+$'
    compressed_name = f'{by}_compress'
    df[compressed_name] = df[by].apply(lambda x: re.sub(
        regex, '*', str(x)) if isinstance(x, str) else "")
    return [df, compressed_name]


def read_slack_file(slack_file):
    cols_to_use = ['post_par_pt_slack', 'fct_bu_slack']
    df_slack = pd.read_csv(slack_file, index_col=None)
    df_slack[cols_to_use] = df_slack[cols_to_use].replace(
        [np.inf, -np.inf, 'Unconstrained'], np.nan)
    df_slack.dropna(subset=cols_to_use, inplace=True)
    df_slack[cols_to_use] = df_slack[cols_to_use].astype('float64')
    cols = df_slack.columns
    df_slack, compressed_name = add_compress_to_df(df_slack, cols[0])
    df_compressed = df_slack.groupby(compressed_name)

    df = df_compressed[cols_to_use].min().reset_index()

    def spec_advisory(row):
        if row[cols_to_use[0]] < 0 and row[cols_to_use[1]] > 0:
            return 'consider to relax spec'
        if row[cols_to_use[0]] > 0 and row[cols_to_use[1]] < 0:
            return 'consider stress spec'
        return None
    df['spec advisory'] = df[cols_to_use].apply(spec_advisory, axis=1)
    return df
    # post_par_pt_slack fct_bu_slack


def get_model_from_file(fin):
    sw = '#model='
    with open(fin) as f:
        for line in f:
            line = line.strip()
            if line.startswith(sw):
                return line


def main():
    args = parse_args()
    slack_files = args.slack_files
    for slack_file in slack_files:
        df = read_slack_file(slack_file)

        model_from = os.path.split(slack_file)
        par = os.path.basename(model_from[0])
        model_fin = os.path.join(model_from[0], f'{par}_io_constraints.tcl')
        model = get_model_from_file(model_fin)
        fout = os.path.join(model_from[0], f'{par}_advisory.csv')
        f = open(fout, 'w')
        f.write(f'{model}\n')
        df.to_csv(f, index=False)
        f.close()
    return 0


if __name__ == '__main__':
    sys.exit(main())
