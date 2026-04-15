#!/usr/intel/bin/python3.7.4

import csv
import argparse

parser = argparse.ArgumentParser(description='SCALE SPEC CSV FILE')
parser.add_argument('scale_factor', type=float, help='scaling factor for specs')
parser.add_argument('in_file', type=str, help='CSV file name')
parser.add_argument('out_file',type=str , help='output CSV file')

args = parser.parse_args()

with open(args.in_file, mode='r') as csv_file:
    firstline = True
    csv_reader = csv.reader(csv_file)
    rows = []
    match_rows =[]
    for row in csv_reader:
        if firstline:    #skip first line
            firstline = False
            rows.append(row)
            continue
        row[2] = round(float(row[2])*args.scale_factor)
        rows.append(row)

with open(args.out_file, mode='w', newline='') as csv_file:
    csv_writer = csv.writer(csv_file)
    csv_writer.writerows(rows)
