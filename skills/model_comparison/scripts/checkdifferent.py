import sys

def check_lines_in_file(input_file, other_file):
    # Read all lines from the input file
    with open(input_file, 'r') as f:
        input_lines = [line.strip() for line in f]

    # Read all lines from the other file into a set for fast lookup
    with open(other_file, 'r') as f:
        other_lines = set(line.strip() for line in f)

    # Print lines from input_file not found in other_file
    for line in input_lines:
        if line not in other_lines:
            print(f"{line}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 checkdifferent.py <original_ports> <new_ports>")
        sys.exit(1)
    input_file = sys.argv[1]
    other_file = sys.argv[2]
    print("------ New added ports ------")
    check_lines_in_file(other_file,input_file)
    print("\n########################################\n")
    print("------ Removed ports ------")
    check_lines_in_file(input_file, other_file)
