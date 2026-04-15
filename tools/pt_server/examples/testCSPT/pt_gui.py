#!/usr/bin/env python3
"""
pt_gui.py  —  Multi-server Tkinter GUI for the PT socket server.

Usage:
    python3 pt_gui.py

Reads testCSPT/ports automatically (one host:port per line).
"""

import os
import pathlib
import subprocess
import threading
import tkinter as tk
from tkinter import ttk
from datetime import datetime

import importlib.util
_here = pathlib.Path(__file__).parent
_spec = importlib.util.spec_from_file_location("pt_client", _here / "pt_client.py")
_mod  = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)
send_command = _mod.send_command

PORTS_FILE = _here / "ports"
NAME_FILE  = _here / "pt_server_name"
LOGS_DIR   = _here / "logs"
REFRESH_MS = 3000

# ── Corner definitions ────────────────────────────────────────────────────────
# (display_name, full_corner_dir_name, source_tcl_filename)
CORNERS = [
    ("func.max_high", "func.max_high.T_85.typical",          "source_func.max_high.tcl"),
    ("func.max_med",  "func.max_med.T_85.typical",           "source_func.max_med.tcl"),
    ("func.max_low",  "func.max_low.T_85.typical",           "source_func.max_low.tcl"),
    ("func.min_high", "func.min_high.T_85.typical",          "source_func.min_high.tcl"),
    ("func.min_low",  "func.min_low.T_85.typical",           "source_func.min_low.tcl"),
    ("func.min_fast", "fresh.min_fast.F_125.rcworst_CCworst","source_func.min_fast.tcl"),
]

DEFAULT_LAUNCH_CMD  = 'nbjob run --target sc8_express --qslot /c2dg/BE_BigCore/pnc/sd/sles12_sd --class "SLES12&&4C&&512G" /p/hdk/pu_tu/prd/fct_alias/latest/utils/load_session_cth.csh'
DEFAULT_BASE_PATH   = "$GFC_LINKS/daily_gfc0a_n2_core_client_bu_postcts/runs/core_client/n2p_htall_conf4/sta_pt"

FONT_LABEL = ("Helvetica", 13)
FONT_BOLD  = ("Helvetica", 13, "bold")
FONT_MONO  = ("Courier",   12)
FONT_ENTRY = ("Helvetica", 12)
FONT_BTN   = ("Helvetica", 12, "bold")
FONT_SMALL = ("Helvetica", 11)

LOGS_DIR.mkdir(exist_ok=True)


def _log_file(hp: str) -> pathlib.Path:
    return LOGS_DIR / f"{hp.replace(':', '_')}.log"


def _append_log(hp: str, cmd: str, output: str):
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(_log_file(hp), "a") as fh:
        fh.write(f"\n{'─'*70}\n")
        fh.write(f"[{ts}]  {hp}\n")
        fh.write(f"CMD: {cmd}\n")
        fh.write(f"{'─'*70}\n")
        fh.write(output if output.strip() else "(no output)")
        fh.write("\n")


# ─────────────────────────────────────────────────────────────────────────────
# Shared output text factory
# ─────────────────────────────────────────────────────────────────────────────
def _make_output_text(parent) -> tk.Text:
    frame = tk.Frame(parent)
    frame.pack(fill=tk.BOTH, expand=True)
    xsb = tk.Scrollbar(frame, orient=tk.HORIZONTAL)
    ysb = tk.Scrollbar(frame, orient=tk.VERTICAL)
    txt = tk.Text(frame, font=FONT_MONO, wrap=tk.NONE,
                  xscrollcommand=xsb.set, yscrollcommand=ysb.set,
                  bg="#1e1e1e", fg="#d4d4d4",
                  insertbackground="white", state=tk.DISABLED)
    txt.tag_config("header",    foreground="#4ec9b0", font=("Courier", 12, "bold"))
    txt.tag_config("timestamp", foreground="#888888", font=("Courier", 11))
    txt.tag_config("divider",   foreground="#444444")
    txt.tag_config("cmd_tag",   foreground="#dcdcaa")
    txt.tag_config("error",     foreground="#f44747")
    xsb.config(command=txt.xview)
    ysb.config(command=txt.yview)
    xsb.pack(side=tk.BOTTOM, fill=tk.X)
    ysb.pack(side=tk.RIGHT,  fill=tk.Y)
    txt.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
    return txt


def _write_results(txt: tk.Text, cmd: str, results: dict, first: bool = False):
    txt.config(state=tk.NORMAL)
    ts = datetime.now().strftime("%H:%M:%S")
    if not first:
        txt.insert(tk.END, "\n" + "═" * 80 + "\n", "divider")
    txt.insert(tk.END, f"[{ts}]  ", "timestamp")
    txt.insert(tk.END, f"CMD: {cmd}\n", "cmd_tag")
    for hp, output in results.items():
        txt.insert(tk.END, f"▶  {hp}\n", "header")
        tag = "error" if output.lstrip().startswith("[ERROR]") else None
        body = (output if output.strip() else "(no output)") + "\n"
        txt.insert(tk.END, body, tag) if tag else txt.insert(tk.END, body)
    txt.config(state=tk.DISABLED)
    txt.see(tk.END)


# ─────────────────────────────────────────────────────────────────────────────
# Output popup
# ─────────────────────────────────────────────────────────────────────────────
class OutputPopup(tk.Toplevel):
    def __init__(self, parent, cmd: str, results: dict):
        super().__init__(parent)
        self.title(f"PT Output  ▸  {cmd[:70]}")
        self.geometry("1000x640")
        self.minsize(600, 300)
        self._txt = _make_output_text(self)
        _write_results(self._txt, cmd, results, first=True)
        btn_row = tk.Frame(self)
        btn_row.pack(fill=tk.X, padx=10, pady=(0, 10))
        full = "\n".join(f"▶  {hp}\n{out}" for hp, out in results.items())
        tk.Button(btn_row, text="Copy all", font=FONT_ENTRY,
                  command=lambda: (self.clipboard_clear(),
                                   self.clipboard_append(full))
                  ).pack(side=tk.RIGHT, padx=6)
        tk.Button(btn_row, text="Close", font=FONT_ENTRY, width=8,
                  command=self.destroy).pack(side=tk.RIGHT)


# ─────────────────────────────────────────────────────────────────────────────
# Report Timing builder panel
# ─────────────────────────────────────────────────────────────────────────────
class ReportTimingPanel(tk.Frame):
    """Builds a report_timing command from GUI controls."""

    def __init__(self, parent):
        super().__init__(parent)
        self._history: dict[str, list] = {
            "from": [], "through": [], "to": [], "exclude": []
        }
        self._build()

    def _build(self):
        P = dict(padx=6, pady=3)

        # ── Row 0: delay type + pba_mode + nworst + max_paths + slack_lesser ─
        r0 = tk.Frame(self)
        r0.pack(fill=tk.X, **P)

        tk.Label(r0, text="Delay Type:", font=FONT_SMALL).pack(side=tk.LEFT)
        self._delay = ttk.Combobox(r0, values=["max", "min"], width=5,
                                   font=FONT_SMALL, state="readonly")
        self._delay.set("max")
        self._delay.pack(side=tk.LEFT, padx=(2, 14))

        tk.Label(r0, text="-pba_mode:", font=FONT_SMALL).pack(side=tk.LEFT)
        self._pba = ttk.Combobox(r0, values=["none", "path", "exhaustive",
                                              "ml_exhaustive"],
                                 width=13, font=FONT_SMALL, state="readonly")
        self._pba.set("none")
        self._pba.pack(side=tk.LEFT, padx=(2, 14))

        tk.Label(r0, text="-nworst:", font=FONT_SMALL).pack(side=tk.LEFT)
        self._nworst = tk.Entry(r0, width=5, font=FONT_SMALL)
        self._nworst.pack(side=tk.LEFT, padx=(2, 2))
        tk.Button(r0, text="✕", font=("Helvetica", 9), width=2,
                  command=lambda: self._nworst.delete(0, tk.END)
                  ).pack(side=tk.LEFT, padx=(0, 10))

        tk.Label(r0, text="-max_paths:", font=FONT_SMALL).pack(side=tk.LEFT)
        self._max_paths = tk.Entry(r0, width=5, font=FONT_SMALL)
        self._max_paths.pack(side=tk.LEFT, padx=(2, 2))
        tk.Button(r0, text="✕", font=("Helvetica", 9), width=2,
                  command=lambda: self._max_paths.delete(0, tk.END)
                  ).pack(side=tk.LEFT, padx=(0, 10))

        tk.Label(r0, text="-slack_lesser_than:", font=FONT_SMALL).pack(side=tk.LEFT)
        self._slack_lt = tk.Entry(r0, width=7, font=FONT_SMALL)
        self._slack_lt.pack(side=tk.LEFT, padx=(2, 2))
        tk.Button(r0, text="✕", font=("Helvetica", 9), width=2,
                  command=lambda: self._slack_lt.delete(0, tk.END)
                  ).pack(side=tk.LEFT)

        # ── Rows 1-4: from / through / to / exclude ───────────────────────
        self._combos: dict[str, ttk.Combobox] = {}
        for key, label in [("from", "-from"), ("through", "-through"),
                            ("to", "-to"), ("exclude", "-exclude")]:
            row = tk.Frame(self)
            row.pack(fill=tk.X, **P)
            tk.Label(row, text=f"{label:<12}", font=FONT_SMALL,
                     width=10, anchor="w").pack(side=tk.LEFT)
            cb = ttk.Combobox(row, values=self._history[key],
                               font=FONT_SMALL, width=70)
            cb.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(2, 2))
            tk.Button(row, text="✕", font=("Helvetica", 9), width=2,
                      command=lambda c=cb: c.set("")
                      ).pack(side=tk.LEFT)
            self._combos[key] = cb

        # ── Checkboxes ────────────────────────────────────────────────────
        chk_outer = tk.LabelFrame(self, text="  Flags  ", font=FONT_SMALL,
                                  padx=6, pady=4)
        chk_outer.pack(fill=tk.X, padx=6, pady=2)

        self._flags: dict[str, tk.BooleanVar] = {}
        flag_defs = [
            ("input_pins",              "-input_pins"),
            ("capacitance",             "-capacitance"),
            ("physical",                "-physical"),
            ("nets",                    "-nets"),
            ("transition_time",         "-transition_time"),
            ("include_hierarchical_pins", "-include_hierarchical_pins"),
            ("nosplit",                 "-nosplit"),
            ("trace_latch_borrow",      "-trace_latch_borrow"),
            ("exceptions_all",          "-exceptions all"),
            ("crosstalk",               "-crosstalk"),
            ("slack_lesser_than_inf",   "-slack_lesser_than inf"),
        ]
        cols = 4
        for idx, (key, label) in enumerate(flag_defs):
            var = tk.BooleanVar()
            self._flags[key] = var
            tk.Checkbutton(chk_outer, text=label, variable=var,
                           font=FONT_SMALL
                           ).grid(row=idx // cols, column=idx % cols,
                                  sticky="w", padx=4, pady=1)

        # ── Extra flags row ──────────────────────────────────────────────
        extra_row = tk.Frame(self)
        extra_row.pack(fill=tk.X, **P)
        tk.Label(extra_row, text="Extra flags:", font=FONT_SMALL,
                 width=10, anchor="w").pack(side=tk.LEFT)
        self._extra = tk.Entry(extra_row, font=FONT_SMALL)
        self._extra.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(2, 2))
        tk.Button(extra_row, text="✕", font=("Helvetica", 9), width=2,
                  command=lambda: self._extra.delete(0, tk.END)
                  ).pack(side=tk.LEFT)

        # ── Preview ──────────────────────────────────────────────────────
        prev_row = tk.Frame(self)
        prev_row.pack(fill=tk.X, **P)
        tk.Label(prev_row, text="Preview:", font=FONT_SMALL,
                 width=10, anchor="w").pack(side=tk.LEFT)
        self._preview_var = tk.StringVar(value="")
        tk.Label(prev_row, textvariable=self._preview_var,
                 font=("Courier", 10), fg="#888888",
                 anchor="w", wraplength=700, justify="left"
                 ).pack(side=tk.LEFT, fill=tk.X, expand=True)

        tk.Button(prev_row, text="Preview", font=FONT_SMALL,
                  command=lambda: self._preview_var.set(self.build_cmd())
                  ).pack(side=tk.RIGHT)

    def _update_history(self, key: str, val: str):
        if val and val not in self._history[key]:
            self._history[key].insert(0, val)
            del self._history[key][10:]
            self._combos[key]["values"] = self._history[key]

    def build_cmd(self) -> str:
        parts = ["report_timing"]

        delay = self._delay.get()
        if delay == "min":
            parts.append("-delay_type min")

        for key, flag in [("from", "-from"), ("through", "-through"),
                           ("to", "-to"), ("exclude", "-exclude")]:
            val = self._combos[key].get().strip()
            if val:
                self._update_history(key, val)
                parts.append(f"{flag} {val}")

        pba = self._pba.get()
        if pba != "none":
            parts.append(f"-pba_mode {pba}")

        nw = self._nworst.get().strip()
        if nw:
            parts.append(f"-nworst {nw}")
        mp = self._max_paths.get().strip()
        if mp:
            parts.append(f"-max_paths {mp}")
        slt = self._slack_lt.get().strip()
        if slt:
            parts.append(f"-slack_lesser_than {slt}")

        flag_map = {
            "input_pins":               "-input_pins",
            "capacitance":              "-capacitance",
            "physical":                 "-physical",
            "nets":                     "-nets",
            "transition_time":          "-transition_time",
            "include_hierarchical_pins":"-include_hierarchical_pins",
            "nosplit":                  "-nosplit",
            "trace_latch_borrow":       "-trace_latch_borrow",
            "exceptions_all":           "-exceptions all",
            "crosstalk":                "-crosstalk",
            "slack_lesser_than_inf":    "-slack_lesser_than inf",
        }
        for key, flag in flag_map.items():
            if self._flags[key].get():
                parts.append(flag)

        extra = self._extra.get().strip()
        if extra:
            parts.append(extra)

        return " ".join(parts)


# ─────────────────────────────────────────────────────────────────────────────
# Main window
# ─────────────────────────────────────────────────────────────────────────────
class PTClientGUI(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("PT Multi-Server Client")
        self.geometry("1020x860")
        self.minsize(800, 650)

        self._server_vars: dict[str, tk.BooleanVar] = {}
        self._last_results: dict = {}
        self._last_cmd: str = ""
        self._out_first_write: dict[str, bool] = {}  # entry → bool
        self._out_tabs:  dict[str, tk.Text]    = {}  # entry → Text widget
        self._out_frames: dict[str, tk.Frame]  = {}  # entry → tab frame

        self._build_ui()
        self._refresh_servers()
        self._schedule_refresh()

    # ── UI ────────────────────────────────────────────────────────────────────

    def _build_ui(self):
        P = dict(padx=14, pady=5)

        # ── Servers ──────────────────────────────────────────────────────────
        srv_frame = tk.LabelFrame(self, text="  PT Servers  ",
                                  font=FONT_BOLD, padx=8, pady=4)
        srv_frame.pack(fill=tk.X, **P)

        self._srv_canvas = tk.Canvas(srv_frame, height=100,
                                     highlightthickness=0)
        srv_vsb = tk.Scrollbar(srv_frame, orient=tk.VERTICAL,
                               command=self._srv_canvas.yview)
        self._srv_canvas.configure(yscrollcommand=srv_vsb.set)
        srv_vsb.pack(side=tk.RIGHT, fill=tk.Y)
        self._srv_canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        self._chk_frame = tk.Frame(self._srv_canvas)
        self._chk_win   = self._srv_canvas.create_window(
            (0, 0), window=self._chk_frame, anchor="nw")
        self._chk_frame.bind(
            "<Configure>",
            lambda e: self._srv_canvas.configure(
                scrollregion=self._srv_canvas.bbox("all")))
        self._srv_canvas.bind(
            "<Configure>",
            lambda e: self._srv_canvas.itemconfig(
                self._chk_win, width=e.width))

        sa = tk.Frame(srv_frame)
        sa.pack(fill=tk.X, pady=(4, 0))
        tk.Button(sa, text="↺ Refresh",   font=FONT_SMALL,
                  command=self._refresh_servers).pack(side=tk.LEFT)
        tk.Button(sa, text="Select all",  font=FONT_SMALL,
                  command=self._select_all).pack(side=tk.LEFT, padx=4)
        tk.Button(sa, text="Deselect all",font=FONT_SMALL,
                  command=self._deselect_all).pack(side=tk.LEFT)
        tk.Frame(sa, width=2, bg="gray70").pack(side=tk.LEFT,
                                                fill=tk.Y, padx=10, pady=2)
        tk.Button(sa, text="Ping",        font=FONT_SMALL,
                  command=self._ping_all).pack(side=tk.LEFT)
        tk.Button(sa, text="Stop Server", font=FONT_SMALL,
                  bg="#b85c00", fg="white",
                  activebackground="#7a3d00", activeforeground="white",
                  command=self._stop_servers).pack(side=tk.LEFT, padx=4)
        tk.Button(sa, text="Exit PT",     font=FONT_SMALL,
                  bg="#8b0000", fg="white",
                  activebackground="#5a0000", activeforeground="white",
                  command=self._exit_servers).pack(side=tk.LEFT)

        # ── Notebook: Free Command | Report Timing ────────────────────────
        nb_frame = tk.LabelFrame(self, text="  Command  ",
                                 font=FONT_BOLD, padx=8, pady=4)
        nb_frame.pack(fill=tk.X, **P)

        self._nb = ttk.Notebook(nb_frame)
        self._nb.pack(fill=tk.BOTH, expand=True)

        # Tab 1 – Free Command
        tab_free = tk.Frame(self._nb)
        self._nb.add(tab_free, text="  Free Command  ")

        cmd_inner = tk.Frame(tab_free)
        cmd_inner.pack(fill=tk.X, pady=(4, 0))
        cmd_vsb = tk.Scrollbar(cmd_inner)
        cmd_vsb.pack(side=tk.RIGHT, fill=tk.Y)
        self._cmd_text = tk.Text(cmd_inner, height=4, font=FONT_MONO,
                                 yscrollcommand=cmd_vsb.set, wrap=tk.NONE)
        self._cmd_text.pack(side=tk.LEFT, fill=tk.X, expand=True)
        cmd_vsb.config(command=self._cmd_text.yview)
        self._cmd_text.bind("<Control-Return>", lambda e: self._send())

        send_row = tk.Frame(tab_free)
        send_row.pack(fill=tk.X, pady=(4, 2))
        tk.Button(send_row, text="Send  ↵", font=FONT_BTN,
                  bg="#0066cc", fg="white",
                  activebackground="#004fa3", activeforeground="white",
                  command=self._send).pack(side=tk.RIGHT)

        # Tab 2 – Report Timing
        tab_rt = tk.Frame(self._nb)
        self._nb.add(tab_rt, text="  Report Timing  ")

        self._rt_panel = ReportTimingPanel(tab_rt)
        self._rt_panel.pack(fill=tk.BOTH, expand=True)

        rt_send_row = tk.Frame(tab_rt)
        rt_send_row.pack(fill=tk.X, pady=(4, 2))
        tk.Button(rt_send_row, text="Send Report Timing  ↵", font=FONT_BTN,
                  bg="#006633", fg="white",
                  activebackground="#004422", activeforeground="white",
                  command=self._send_report_timing).pack(side=tk.RIGHT)

        # Tab 3 – Launch PT Sessions
        tab_launch = tk.Frame(self._nb)
        self._nb.add(tab_launch, text="  Launch PT  ")
        self._build_launch_tab(tab_launch)

        # ── Output ───────────────────────────────────────────────────────────
        out_lf = tk.LabelFrame(self, text="  Output  ",
                               font=FONT_BOLD, padx=8, pady=4)
        out_lf.pack(fill=tk.BOTH, expand=True, **P)

        out_hdr = tk.Frame(out_lf)
        out_hdr.pack(fill=tk.X, pady=(0, 4))
        tk.Button(out_hdr, text="Clear current",  font=FONT_SMALL,
                  command=self._clear_output).pack(side=tk.RIGHT, padx=(4, 0))
        tk.Button(out_hdr, text="Clear all",      font=FONT_SMALL,
                  command=self._clear_all_output).pack(side=tk.RIGHT, padx=(4, 0))
        tk.Button(out_hdr, text="Open in Popup",  font=FONT_SMALL,
                  command=self._open_popup).pack(side=tk.RIGHT)

        self._out_nb = ttk.Notebook(out_lf)
        self._out_nb.pack(fill=tk.BOTH, expand=True)

        # ── Status bar ───────────────────────────────────────────────────────
        self._status_var = tk.StringVar(value="Ready")
        self._status_lbl = tk.Label(self, textvariable=self._status_var,
                                    font=FONT_SMALL, anchor="w", fg="gray45",
                                    relief=tk.SUNKEN)
        self._status_lbl.pack(fill=tk.X, side=tk.BOTTOM)

    # ── Server list ───────────────────────────────────────────────────────────

    @staticmethod
    def _parse_entry(line: str) -> tuple[str, str]:
        """Parse a ports-file line into (display_label, host:port).
        CFG format: #project,type,corner,model,process,machine,port
        Legacy format: 'name|host:port' or just 'host:port'.
        """
        line = line.strip()
        if line.startswith('#') and line.count(',') >= 6:
            clean = line.lstrip('#')
            parts = clean.split(',')
            corner  = parts[2].strip()
            machine = parts[5].strip()
            port    = parts[6].strip()
            return corner, machine + ":" + port
        if "|" in line:
            name, hp = line.split("|", 1)
            return name.strip(), hp.strip()
        return line, line

    def _read_ports(self):
        if not PORTS_FILE.exists():
            return []
        try:
            return [l.strip() for l in PORTS_FILE.read_text().splitlines()
                    if l.strip()]
        except Exception:
            return []

    def _refresh_servers(self):
        entries = self._read_ports()
        gone = [e for e in list(self._server_vars) if e not in entries]
        for e in gone:
            del self._server_vars[e]
            # remove output tab if server disappeared
            if e in self._out_frames:
                try:
                    self._out_nb.forget(self._out_frames[e])
                except Exception:
                    pass
                del self._out_frames[e]
                del self._out_tabs[e]
                self._out_first_write.pop(e, None)

        for w in self._chk_frame.winfo_children():
            w.destroy()
        if not entries:
            tk.Label(self._chk_frame,
                     text="No servers found in ports file",
                     font=FONT_LABEL, fg="gray50").pack(anchor="w", pady=4)
            self._status("No servers in ports file", "gray45")
            return
        for entry in entries:
            if entry not in self._server_vars:
                self._server_vars[entry] = tk.BooleanVar(value=True)
            name, hp = self._parse_entry(entry)
            # checkbox row
            row = tk.Frame(self._chk_frame)
            row.pack(fill=tk.X, pady=1)
            cb = tk.Checkbutton(row, text=name, font=FONT_LABEL,
                           variable=self._server_vars[entry],
                           anchor="w")
            cb.pack(side=tk.LEFT)
            tip = tk.Label(row, text=hp, font=("Helvetica", 10),
                           fg="gray60", anchor="w")
            tip.pack(side=tk.LEFT, padx=(4, 0))
            # output tab — create once, keep across refreshes
            if entry not in self._out_frames:
                tab_frame = tk.Frame(self._out_nb)
                txt = _make_output_text(tab_frame)
                self._out_nb.add(tab_frame, text=f"  {name}  ")
                self._out_frames[entry] = tab_frame
                self._out_tabs[entry]   = txt
                self._out_first_write[entry] = True

    def _schedule_refresh(self):
        self._refresh_servers()
        self.after(REFRESH_MS, self._schedule_refresh)

    def _select_all(self):
        for v in self._server_vars.values(): v.set(True)

    def _deselect_all(self):
        for v in self._server_vars.values(): v.set(False)

    def _checked_servers(self):
        """Return list of (entry, host:port) tuples for checked servers."""
        return [(e, self._parse_entry(e)[1])
                for e, v in self._server_vars.items() if v.get()]

    # ── Actions ───────────────────────────────────────────────────────────────

    def _ping_all(self):
        t = self._checked_servers()
        if not t: return self._status("No servers selected", "orange")
        self._status(f"Pinging {len(t)} server(s)…", "orange")
        self._dispatch(t, "ping")

    def _stop_servers(self):
        t = self._checked_servers()
        if not t: return self._status("No servers selected", "orange")
        self._status(f"Stopping {len(t)} server(s)…", "#b85c00")
        self._dispatch(t, "pt_server_stop")

    def _exit_servers(self):
        t = self._checked_servers()
        if not t: return self._status("No servers selected", "orange")
        self._status(f"Sending exit to {len(t)} server(s)…", "#8b0000")
        self._dispatch(t, "exit")

    def _send(self):
        t = self._checked_servers()
        if not t:
            return self._status("No servers selected — check at least one", "red")
        cmd = self._cmd_text.get("1.0", tk.END).strip()
        if not cmd:
            return self._status("Command is empty", "red")
        self._status(f"Sending to {len(t)} server(s)…", "orange")
        self._dispatch(t, cmd)

    def _send_report_timing(self):
        t = self._checked_servers()
        if not t:
            return self._status("No servers selected — check at least one", "red")
        cmd = self._rt_panel.build_cmd()
        self._rt_panel._preview_var.set(cmd)
        self._status(f"Sending report_timing to {len(t)} server(s)…", "orange")
        self._dispatch(t, cmd)

    def _dispatch(self, targets: list, cmd: str):
        """targets is a list of (entry, host:port) tuples."""
        results   = {}
        lock      = threading.Lock()
        done      = threading.Event()
        remaining = [len(targets)]

        def worker(entry, hp):
            name, _ = self._parse_entry(entry)
            host, port_s = hp.rsplit(":", 1)
            try:
                out = send_command(host, int(port_s), cmd)
            except ConnectionRefusedError:
                out = "[ERROR] Connection refused — is the server running?"
            except Exception as exc:
                out = f"[ERROR] {exc}"
            try:
                _append_log(hp, cmd, out)
            except Exception:
                pass
            # key in results is the display label so output is readable
            display = name if name != hp else hp
            with lock:
                results[display] = out
                remaining[0] -= 1
                if remaining[0] == 0:
                    done.set()

        for entry, hp in targets:
            threading.Thread(target=worker, args=(entry, hp),
                             daemon=True).start()

        def wait_and_show():
            done.wait()
            self.after(0, lambda: self._show_results(cmd, results))

        threading.Thread(target=wait_and_show, daemon=True).start()

    def _show_results(self, cmd: str, results: dict):
        """results keys are display names (corner names)."""
        self._last_cmd     = cmd
        self._last_results = results
        # route each server's output to its own tab
        for entry, txt in self._out_tabs.items():
            name, _ = self._parse_entry(entry)
            display = name if name != _ else _
            if display in results:
                first = self._out_first_write.get(entry, True)
                _write_results(txt, cmd, {display: results[display]}, first=first)
                self._out_first_write[entry] = False
                # bring this tab to front if it's the only one or first response
                if len(results) == 1:
                    self._out_nb.select(self._out_frames[entry])
        self._status(
            f"Done — {len(results)} server(s) responded  |  logs → {LOGS_DIR}",
            "#006600")

    def _clear_output(self):
        """Clear the currently visible tab."""
        try:
            current = self._out_nb.select()
            for entry, frame in self._out_frames.items():
                if str(frame) == current:
                    txt = self._out_tabs[entry]
                    txt.config(state=tk.NORMAL)
                    txt.delete("1.0", tk.END)
                    txt.config(state=tk.DISABLED)
                    self._out_first_write[entry] = True
                    self._status("Output cleared", "gray45")
                    return
        except Exception:
            pass

    def _clear_all_output(self):
        for entry, txt in self._out_tabs.items():
            txt.config(state=tk.NORMAL)
            txt.delete("1.0", tk.END)
            txt.config(state=tk.DISABLED)
            self._out_first_write[entry] = True
        self._status("All output cleared", "gray45")

    def _open_popup(self):
        """Open popup for the currently visible tab."""
        if not self._last_results:
            self._status("Nothing to show yet", "gray45")
            return
        try:
            current = self._out_nb.select()
            for entry, frame in self._out_frames.items():
                if str(frame) == current:
                    name, _ = self._parse_entry(entry)
                    display = name if name != _ else _
                    if display in self._last_results:
                        OutputPopup(self, self._last_cmd,
                                    {display: self._last_results[display]})
                        return
        except Exception:
            pass
        # fallback: open all
        OutputPopup(self, self._last_cmd, self._last_results)

    # ── Launch PT Sessions tab ────────────────────────────────────────────────

    def _build_launch_tab(self, parent):
        P = dict(padx=8, pady=3)

        # ── Base path ─────────────────────────────────────────────────────────
        r1 = tk.Frame(parent)
        r1.pack(fill=tk.X, **P)
        tk.Label(r1, text="Base path:", font=FONT_SMALL,
                 width=12, anchor="w").pack(side=tk.LEFT)
        self._base_path_var = tk.StringVar(value=DEFAULT_BASE_PATH)
        tk.Entry(r1, textvariable=self._base_path_var,
                 font=FONT_SMALL).pack(side=tk.LEFT, fill=tk.X, expand=True)

        tk.Label(parent,
                 text="Path resolved as:  {base_path}/{full_corner}/outputs/core_client.pt_session.{full_corner}/",
                 font=("Helvetica", 10), fg="gray55", anchor="w"
                 ).pack(fill=tk.X, padx=8, pady=(0, 4))

        # ── Separator ─────────────────────────────────────────────────────────
        ttk.Separator(parent, orient="horizontal").pack(fill=tk.X, padx=8, pady=4)

        # ── Per-corner rows ───────────────────────────────────────────────────
        self._launch_vars: dict[str, tk.BooleanVar] = {}

        grid = tk.Frame(parent)
        grid.pack(fill=tk.X, padx=8)

        headers = ["", "Corner", "Full corner dir", "Source file", ""]
        for col, h in enumerate(headers):
            tk.Label(grid, text=h, font=("Helvetica", 11, "bold"),
                     fg="gray40").grid(row=0, column=col, sticky="w",
                                       padx=4, pady=(0, 2))

        for row_idx, (display, full_corner, src_file) in enumerate(CORNERS, start=1):
            var = tk.BooleanVar(value=True)
            self._launch_vars[display] = var

            tk.Checkbutton(grid, variable=var).grid(
                row=row_idx, column=0, sticky="w")
            tk.Label(grid, text=display, font=FONT_LABEL,
                     width=16, anchor="w").grid(
                row=row_idx, column=1, sticky="w", padx=4)
            tk.Label(grid, text=full_corner, font=FONT_SMALL,
                     fg="gray40", anchor="w").grid(
                row=row_idx, column=2, sticky="w", padx=4)
            tk.Label(grid, text=src_file, font=("Courier", 10),
                     fg="#4488aa", anchor="w").grid(
                row=row_idx, column=3, sticky="w", padx=4)
            tk.Button(grid, text="Launch", font=FONT_SMALL,
                      bg="#334d00", fg="white",
                      activebackground="#223300", activeforeground="white",
                      command=lambda d=display, fc=full_corner, sf=src_file:
                          self._launch_corner(d, fc, sf)
                      ).grid(row=row_idx, column=4, padx=6, pady=2)

        # ── Bottom row ────────────────────────────────────────────────────────
        bot = tk.Frame(parent)
        bot.pack(fill=tk.X, padx=8, pady=(8, 4))
        tk.Button(bot, text="Launch all checked", font=FONT_BTN,
                  bg="#334d00", fg="white",
                  activebackground="#223300", activeforeground="white",
                  command=self._launch_checked).pack(side=tk.RIGHT)

    def _build_pt_cmd(self, display: str, full_corner: str, src_file: str) -> str:
        base  = os.path.expandvars(self._base_path_var.get().strip())
        path  = f"{base}/{full_corner}/outputs/core_client.pt_session.{full_corner}/"
        src   = str(_here / src_file)
        return f'{DEFAULT_LAUNCH_CMD} {path} -title "{display}" -file "{src}" -no_exit 0'

    def _launch_corner(self, display: str, full_corner: str, src_file: str):
        cmd = self._build_pt_cmd(display, full_corner, src_file)
        self._status(f"Launching {display}…", "#334d00")
        self._run_launch(display, cmd)

    def _launch_checked(self):
        to_launch = [(d, fc, sf) for (d, fc, sf) in CORNERS
                     if self._launch_vars.get(d, tk.BooleanVar()).get()]
        if not to_launch:
            self._status("No corners selected", "orange")
            return
        self._status(f"Launching {len(to_launch)} corner(s)…", "#334d00")
        for display, full_corner, src_file in to_launch:
            cmd = self._build_pt_cmd(display, full_corner, src_file)
            self._run_launch(display, cmd)

    def _run_launch(self, display: str, cmd: str):
        """Run a launch command in a background thread and log output."""
        def worker():
            try:
                result = subprocess.run(
                    cmd, shell=True, capture_output=True, text=True, timeout=30)
                out = result.stdout + result.stderr
            except subprocess.TimeoutExpired:
                out = "[timeout] command took too long to return"
            except Exception as exc:
                out = f"[ERROR] {exc}"
            self.after(0, lambda: self._status(
                f"Launch {display}: done", "#334d00"))
            try:
                _append_log(display, cmd, out)
            except Exception:
                pass
        threading.Thread(target=worker, daemon=True).start()

    def _status(self, msg: str, color: str = "gray45"):
        self._status_var.set(msg)
        self._status_lbl.config(fg=color)


# ─────────────────────────────────────────────────────────────────────────────
def main():
    PTClientGUI().mainloop()

if __name__ == "__main__":
    main()
