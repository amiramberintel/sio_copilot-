#!/nfs/site/disks/ayarokh_wa/tools/python/3.11.1/bin/python3

import argparse
import os
import sys
import pandas as pd
import get_points_from_def


class ports_report:
    report = None
    transform_per_template = None
    tag = None

    def __init__(self, root, report_from_pt, tag=os.getenv('TD_COLLATERAL_TAG')):
        self.root = root
        self.report_from_pt = report_from_pt
        self.tag = tag
        self.main()

    def main(self):
        dl = get_points_from_def.def_loc(root=self.root, tag=self.tag)
        self.transform_per_template = dl.transform_per_template
        report = self.read_pt_report(self.report_from_pt)
        self.report = self.add_ports_from_defs(report, dl)

    def add_ports_from_defs(self, df, dl):
        a1 = df.apply(lambda x: pd.Series(
            dl.port_from_def_to_root(x.port_out),
            index=['port_out_def_x_um', 'port_out_def_y_um']), axis=1)
        a2 = df.apply(lambda x: pd.Series(
            dl.port_from_def_to_root(x.port_in),
            index=['port_in_def_x_um', 'port_in_def_y_um']), axis=1)
        df = pd.concat([df, a1, a2], axis=1)
        df.reset_index()
        df['distance_um'] = round(abs(df['port_out_x_um']-df['port_in_x_um']) + \
            abs(df['port_out_y_um']-df['port_in_y_um']),3)
        df['distance_def_um'] = round(abs(df['port_out_def_x_um']-df['port_in_def_x_um']) + \
            abs(df['port_out_def_y_um']-df['port_in_def_y_um']),3)
        return df

    def read_pt_report(self, fin):
        out = pd.read_csv(fin)
        return out


def parse_args():
    """ parse_args() : command-line parser """
    parser = argparse.ArgumentParser(
        prog='ports_pt_to_td',
        description='Reports ports from def files')
    parser.add_argument(
        '-pt_ports_file', type=str, help="report from PT, format:csv\nHeader:\nport_out,port_in,port_out_x,port_out_y,port_in_x,port_in_y,port_out_max_slack", required=True)
    parser.add_argument(
        '-root', type=str, help="Root of report, e.g icore or core_server", default=os.getenv('MODEL_BLOCK'))
    parser.add_argument(
        '-output_report', type=str, help="output_report", required=True)
    parser.add_argument(
        '-input_tag', type=str, help="tag for reading DEFs files", default=os.getenv('TD_COLLATERAL_TAG'))
    args = parser.parse_args()
    return args


if __name__ == '__main__':
    args = parse_args()
    fin = args.pt_ports_file
    root = args.root
    output_file = args.output_report
    tag = args.input_tag
    pr = ports_report(report_from_pt=fin, root=root, tag=tag)
    pr.report.to_csv(output_file, index=False)
    sys.exit(0)
