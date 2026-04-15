#!/usr/bin/env python3
import csv
import re
import sys

def filter_csv(input_file, output_file, search_pattern):
    with open(input_file, 'r') as f_in, open(output_file, 'w', newline='') as f_out:
        writer = csv.writer(f_out)
        
        # Pattern to match the search string
        pattern = re.compile(re.escape(search_pattern))
        
        for line in f_in:
            # Split line by multiple spaces/tabs (for RPT files) or commas (for CSV)
            if ',' in line:
                # It's already CSV format
                row = line.strip().split(',')
            else:
                # It's RPT format - split by multiple spaces/tabs
                row = re.split(r'\s{2,}|\t+', line.strip())
            
            # Always keep first 4 columns
            filtered_row = row[:4]
            
            # Check columns 5 and above for the pattern
            for col in row[4:]:
                if pattern.search(col):
                    # Clean up braces if present
                    cleaned_col = col
                    if col.startswith('{') and col.endswith('}'):
                        cleaned_col = col[1:-1]  # Remove { and }
                    elif col.startswith('{'):
                        cleaned_col = col[1:]    # Remove only {
                    elif col.endswith('}'):
                        cleaned_col = col[:-1]   # Remove only }
                    
                    filtered_row.append(cleaned_col)
            
            writer.writerow(filtered_row)

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python3 covert_to_csv.py <input_file> <output_file> <search_pattern>")
        print("Example: python3 covert_to_csv.py input.rpt output.csv par_mlc")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    search_pattern = sys.argv[3]
    
    filter_csv(input_file, output_file, search_pattern)