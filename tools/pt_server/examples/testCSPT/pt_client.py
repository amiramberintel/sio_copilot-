#!/usr/bin/env python3
"""
pt_client.py  —  Send a Tcl command to a running PT socket server and print
                  the result.

Usage:
    pt_client.py <host> <port> <command>
    pt_client.py <host>:<port> <command>

Examples:
    pt_client.py localhost 9877 "get_object_name [get_designs]"
    pt_client.py localhost:9877 ping
    pt_client.py localhost 9877 "report_timing -nworst 1"

The command can be any Tcl expression valid in the PT session.
Output is printed exactly as PT produces it.
"""

import socket
import sys


DEFAULT_TIMEOUT = 60  # seconds to wait for PT to respond


def send_command(host: str, port: int, command: str, timeout: float = DEFAULT_TIMEOUT) -> str:
    """Connect to the PT server, send one command, collect and return all output."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(timeout)
        s.connect((host, port))
        s.sendall(f"{command}\n".encode())

        chunks = []
        while True:
            try:
                chunk = s.recv(65536)
            except socket.timeout:
                break
            if not chunk:
                break
            chunks.append(chunk.decode(errors="replace"))

        return "".join(chunks).replace("\r\n", "\n").replace("\r", "\n")


def parse_target(args):
    """Parse CLI arguments into (host, port, command)."""
    if len(args) == 3:
        # pt_client.py <host> <port> <command>
        host = args[0]
        try:
            port = int(args[1])
        except ValueError:
            sys.exit(f"ERROR: port must be an integer, got: {args[1]}")
        command = args[2]
    elif len(args) == 2 and ":" in args[0]:
        # pt_client.py <host>:<port> <command>
        host_port, command = args[0], args[1]
        host, port_str = host_port.rsplit(":", 1)
        try:
            port = int(port_str)
        except ValueError:
            sys.exit(f"ERROR: port must be an integer in '{host_port}'")
    else:
        print(__doc__)
        sys.exit(1)
    return host, port, command


def main():
    args = sys.argv[1:]
    host, port, command = parse_target(args)

    try:
        result = send_command(host, port, command)
    except ConnectionRefusedError:
        sys.exit(f"ERROR: connection refused — is the PT server running on {host}:{port}?")
    except socket.timeout:
        sys.exit(f"ERROR: timed out waiting for {host}:{port}")
    except OSError as e:
        sys.exit(f"ERROR: {e}")

    print(result, end="")


if __name__ == "__main__":
    main()
