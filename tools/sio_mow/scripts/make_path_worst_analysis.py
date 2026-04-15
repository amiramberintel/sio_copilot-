#!/usr/intel/pkgs/python3/3.11.1/bin/python3.11

import UsrIntel.R1
# import UsrIntel.R2

import argparse
import pandas as pd

def main():
    parser = argparse.ArgumentParser(
        description="Read a CSV, create an Excel table with calculated columns (using formulas)."
    )
    parser.add_argument("--input", "-i", required=True, help="Path to input CSV file")
    parser.add_argument("--output", "-o", required=True, help="Path to output Excel file")
    args = parser.parse_args()

    # === Step 1: Read CSV ===
    df = pd.read_csv(args.input)

    # === Step 2: Create Excel with xlsxwriter ===
    with pd.ExcelWriter(args.output, engine="xlsxwriter") as writer:
        df.to_excel(writer, sheet_name="Data", index=False, startrow=0)
        workbook = writer.book
        worksheet = writer.sheets["Data"]

        # === Step 4: Define table columns ===
        table_columns = []

        # Add original columns
        for col in df.columns:
            table_columns.append({"header": col})

        # Add calculated columns with structured formulas
        table_columns.append({
            "header": "calculated arrival",
            "formula": ("=[@[logic_cell_delay]]+([@[manhattan_dist]]-[@[tip_dist]])*0.2+[@[tip_delay]]+[@[statistical_adjustment]]+20"),
        })
        table_columns.append({
            "header": "calculated slack",
            "formula": (
                "=[@required]-[@startCLK]-[@[calculated arrival]]"
            ),
        })

        # === Step 5: Add Excel table ===
        (max_row, max_col) = df.shape
        worksheet.add_table(
            0, 0, max_row, len(table_columns) - 1,
            {
                "columns": table_columns,
                "name": "DataTable",
            }
        )


if __name__ == "__main__":
    main()
