#!/usr/intel/bin/python3.11.1

from tkinter import *
from tkinter import filedialog
from tkinter.ttk import Combobox
from tkinter import ttk
import tkinter as tk
import os
import sys
import time
import os
from pathlib import Path
from tkinter import messagebox
import textwrap
import glob
import re

def report_timing():
    global viewer
    global from_txt
    corner = selected_corner.get()
    if ((corner == "")):
        messagebox.showerror('Python Error', 'Please define the corner')
        return
    cmd = "/nfs/site/proj/lnc/c2dgbcptserver_sc8_fct/cth2_ptserver/cth2_ptserver_root/pt_client.pl -m " + tag + " -c \"report_timing "

    if "min_" in corner:   
        cmd = cmd + " -delay_type min "

#    if (from_txt.get("1.0","end-1c") != ""):
#        cmd = cmd + " -from " + from_txt.get("1.0","end-1c") 
#    if (through_txt.get("1.0","end-1c") != ""):
#        cmd = cmd + " -through " + through_txt.get("1.0","end-1c") 
#    if (to_txt.get("1.0","end-1c") != ""):
#        cmd = cmd + " -to " + to_txt.get("1.0","end-1c") 
#    if (exclude_txt.get("1.0","end-1c") != ""):
#        cmd = cmd + " -exclude " + exclude_txt.get("1.0","end-1c") 
    if (from_txt.get() != ""):
        cmd = cmd + "\ \-from\ " + from_txt.get()
        from_history_data.insert(0,from_txt.get())
        del from_history_data[10:]
        from_txt['values']  = from_history_data 
    if (through_txt.get() != ""):
        cmd = cmd + "\ \-through\ " + through_txt.get()
        th_history_data.insert(0,through_txt.get())
        del th_history_data[10:]
        through_txt['values']  = th_history_data 
    if (to_txt.get() != ""):
        cmd = cmd + "\ \-to\ " + to_txt.get() 
        to_history_data.insert(0,to_txt.get())	    
        del to_history_data[10:]
        to_txt['values']  = to_history_data 
    if (exclude_txt.get() != ""):
        cmd = cmd + "\ \-exclude\ " + exclude_txt.get() 
        exclude_history_data.insert(0,exclude_txt.get())	    
        del exclude_history_data[10:]
        exclude_txt['values']  = exclude_history_data 
    if (pba_mode_type.get() != "none"):
        cmd = cmd + " -pba_mode " + pba_mode_type.get()
    if (input_pins_var.get()):
        cmd = cmd + " -input_pins "
    if (capacitance_var.get()):
        cmd = cmd + " -capacitance "
    if (physical_var.get()):
        cmd = cmd + " -physical "
    if (nets_var.get()):
        cmd = cmd + " -nets "
    if (transition_time_var.get()):
        cmd = cmd + " -transition_time "
    if (exception_all_var.get()):
        cmd = cmd + " -exceptions all "
    if (crosstalk_var.get()):
        cmd = cmd + " -crosstalk "
    if (slack_lesser_than_inf_var.get()):
        cmd = cmd + " -slack_lesser_than inf "
    if (include_hierarchical_pins_var.get()):
        cmd = cmd + " -include_hierarchical_pins "
    if (nosplit_var.get()):
        cmd = cmd + " -nosplit "
    if (trace_latch_borrow_var.get()):
        cmd = cmd + " -trace_latch_borrow "
    if (manual_txt.get("1.0","end-1c") != ""):
        cmd = cmd + " " + manual_txt.get("1.0","end-1c") + " " 

    cmd = cmd + " \" | /usr/bin/less > /tmp/results_" + USER + " ; xterm -fn fixed -ls -sb -geometry 295x40+100+80 -T \"/usr/bin/less xl\" -e " + viewer + " -S /tmp/results_" + USER + " & "
#    print(cmd )	
    os.system(cmd)
    
def send_timing_report_to_mail():
    global from_txt
    corner = selected_corner.get()
    if ((corner == "")):
        messagebox.showerror('Python Error', 'Please define the corner')
        return


    cmd = "echo \"Subject: report_timing from the server tool\" > /tmp/results_" + USER 
    os.system(cmd)
    cmd = "echo \"Content-Type: text/html; charset=UTF-8\" >> /tmp/results_" + USER 
    os.system(cmd)
    cmd = "echo \"MIME-Version: 1.0\" >> /tmp/results_" + USER  
    os.system(cmd)
    cmd = "echo \"<pre>\" >> /tmp/results_" + USER  
    os.system(cmd)

    cmd = "/nfs/site/proj/lnc/c2dgbcptserver_sc8_fct/cth2_ptserver/cth2_ptserver_root/pt_client.pl -m " + tag + " -c \"report_timing "
    
    if "min_" in corner:   
        cmd = cmd + " -delay_type min "
#    if (from_txt.get("1.0","end-1c") != ""):
#        cmd = cmd + " -from " + from_txt.get("1.0","end-1c") 
#    if (through_txt.get("1.0","end-1c") != ""):
#        cmd = cmd + " -through " + through_txt.get("1.0","end-1c") 
#    if (to_txt.get("1.0","end-1c") != ""):
#        cmd = cmd + " -to " + to_txt.get("1.0","end-1c") 
#    if (exclude_txt.get("1.0","end-1c") != ""):
#        cmd = cmd + " -exclude " + exclude_txt.get("1.0","end-1c") 
    if (from_txt.get() != ""):
        cmd = cmd + "\ \-from\ " + from_txt.get()
        from_history_data.insert(0,from_txt.get())	    
        del from_history_data[10:]
        from_txt['values']  = from_history_data 
    if (through_txt.get() != ""):
        cmd = cmd + "\ \-through\ " + through_txt.get()
        th_history_data.insert(0,through_txt.get())	    
        del th_history_data[10:]
        through_txt['values']  = th_history_data 
    if (to_txt.get() != ""):
        cmd = cmd + "\ \-to\ " + to_txt.get() 
        to_history_data.insert(0,to_txt.get())	    
        del to_history_data[10:]
        to_txt['values']  = to_history_data 
    if (exclude_txt.get() != ""):
        cmd = cmd + "\ \-exclude\ " + exclude_txt.get() 
        exclude_history_data.insert(0,exclude_txt.get())	    
        del exclude_history_data[10:]
        exclude_txt['values']  = exclude_history_data 
    if (pba_mode_type.get() != "none"):
        cmd = cmd + " -pba_mode " + pba_mode_type.get()
    if (input_pins_var.get()):
        cmd = cmd + " -input_pins "
    if (capacitance_var.get()):
        cmd = cmd + " -capacitance "
    if (physical_var.get()):
        cmd = cmd + " -physical "
    if (nets_var.get()):
        cmd = cmd + " -nets "
    if (transition_time_var.get()):
        cmd = cmd + " -transition_time "
    if (exception_all_var.get()):
        cmd = cmd + " -exceptions all "
    if (crosstalk_var.get()):
        cmd = cmd + " -crosstalk "
    if (slack_lesser_than_inf_var.get()):
        cmd = cmd + " -slack_lesser_than inf "
    if (include_hierarchical_pins_var.get()):
        cmd = cmd + " -include_hierarchical_pins "
    if (nosplit_var.get()):
        cmd = cmd + " -nosplit "
    if (trace_latch_borrow_var.get()):
        cmd = cmd + " -trace_latch_borrow "
    if (manual_txt.get("1.0","end-1c") != ""):
        cmd = cmd + " " + manual_txt.get("1.0","end-1c") + " " 
    
    
    cmd = cmd + " \" | /usr/bin/less >> /tmp/results_" + USER 
    os.system(cmd)
    cmd = "echo \"</pre>\" >> /tmp/results_" + USER 
    os.system(cmd)

    cmd = "cat /tmp/results_" + USER + " | sendmail " + USER
    os.system(cmd)

def mail_path_report():
    cmd = "cp /tmp/results_"+ USER + "_new /tmp/timing_report_paths" + USER + ".txt"
    os.system(cmd)
    cmd = "mail -a /tmp/timing_report_paths" + USER + ".txt -s \"Timing Report\" " + USER + " < /dev/null"
    os.system(cmd)


def draw_path():
# TODO: draw the correct top die :)
    global from_txt
    corner = selected_corner.get()
    if ((corner == "")):
        messagebox.showerror('Python Error', 'Please define the corner')
        return
    cmd = "/nfs/site/proj/lnc/c2dgbcptserver_sc8_fct/cth2_ptserver/cth2_ptserver_root/pt_client.pl -m " + tag +  " -c \"report_timing "

    if "min_" in corner:   
        cmd = cmd + " -delay_type min "
#    if (from_txt.get("1.0","end-1c") != ""):
#        cmd = cmd + " -from " + from_txt.get("1.0","end-1c") 
#    if (through_txt.get("1.0","end-1c") != ""):
#        cmd = cmd + " -through " + through_txt.get("1.0","end-1c") 
#    if (to_txt.get("1.0","end-1c") != ""):
#        cmd = cmd + " -to " + to_txt.get("1.0","end-1c") 
#    if (exclude_txt.get("1.0","end-1c") != ""):
#        cmd = cmd + " -exclude " + exclude_txt.get("1.0","end-1c") 
    if (from_txt.get() != ""):
        cmd = cmd + "\ \-from\ " + from_txt.get()
        from_history_data.insert(0,from_txt.get())	    
        del from_history_data[10:]
        from_txt['values']  = from_history_data 
    if (through_txt.get() != ""):
        cmd = cmd + "\ \-through\ " + through_txt.get()
        th_history_data.insert(0,through_txt.get())	    
        del th_history_data[10:]
        through_txt['values']  = th_history_data 
    if (to_txt.get() != ""):
        cmd = cmd + "\ \-to\ " + to_txt.get() 
        to_history_data.insert(0,to_txt.get())	    
        del to_history_data[10:]
        to_txt['values']  = to_history_data 
    if (exclude_txt.get() != ""):
        cmd = cmd + "\ \-exclude\ " + exclude_txt.get() 
        exclude_history_data.insert(0,exclude_txt.get())	    
        del exclude_history_data[10:]
        exclude_txt['values']  = exclude_history_data 
    if (pba_mode_type.get() != "none"):
        cmd = cmd + " -pba_mode " + pba_mode_type.get()
    cmd = cmd + " -physical "
    cmd = cmd + " -include_hierarchical_pins "
    cmd = cmd + " -nosplit "

    cmd = cmd + " \" | grep -e \"(.*.000,.*.000)\" | perl -pe 's/.*\(([0-9]*.[0-9]*,[0-9]*.[0-9]*)\).*/$1/g' | awk -F \",\" '{print $1/1000 , $2/1000 }' > path.location " 
    os.system(cmd)
    pro=selected_project.get()
    if pro == "lncn3lnlcliena0":
         cmd = "cat ~baselibr/lnc/Core_plot/lnc_client/Draw_Core.gnuplot_temp  > path.location.gnuplot  " 
    elif pro== "pnc78clienta0":
        cmd = "cat ~baselibr/pnc/Core_plot/core_client/Draw_block.gnuplot_temp  > path.location.gnuplot  "
    elif pro== "pnc78clientb0":
        cmd = "cat ~baselibr/pnc/Core_plot/core_client/Draw_block.gnuplot_temp  > path.location.gnuplot  "
    elif pro== "pnc78servera0":
        cmd = "cat ~baselibr/pnc/Core_plot/core_server/Draw_block.gnuplot_temp  > path.location.gnuplot  "
    elif pro== "pnc78icorea0":
        cmd = "cat ~baselibr/pnc/Core_plot/icore/Draw_block.gnuplot_temp  > path.location.gnuplot  "    
    elif pro== "lnc78b0":
        cmd = "cat ~baselibr/lnc/Core_plot/lnc_client_20a/Draw_Core.gnuplot_temp  > path.location.gnuplot  " 
    elif pro== "lnc78a0":
        cmd = "cat ~baselibr/lnc/Core_plot/lnc_client_20a/Draw_Core.gnuplot_temp  > path.location.gnuplot  "     
    elif pro== "gfcn2clienta0":
        cmd = "cat ~baselibr/gfc/Core_plot/core_client/Draw_block.gnuplot_temp  > path.location.gnuplot  "
    else:
        return 
    os.system(cmd)
    cmd = "echo \" '`pwd`/path.location' with linespoints linestyle 3\" >>path.location.gnuplot "
    os.system(cmd)
    cmd = "echo \"pause -1\" >> path.location.gnuplot "
    os.system(cmd)
    cmd = "xterm -fn fixed -ls -sb -geometry 50x2+100+80 -T \"Exit me once done\" -e gnuplot path.location.gnuplot & "
    os.system(cmd)

def all_corner_slack():
    global viewer
    global from_txt
    cmd = "echo \"Corner                      Slack\" > /tmp/results_" + USER 
    os.system(cmd)
    pattern=selected_project.get()+","+selected_type.get()
    matching_lines = [line for line in open('/nfs/site/proj/lnc/c2dgbcptserver_sc8_fct/cth2_ptserver/cth2_ptserver_root//pt_server_c2dgbcptserver_cron.cfg').readlines() if pattern in line]
    corner_list = []
    if len(matching_lines):
        for line in matching_lines:
            if line.split(",")[3] == selected_model.get():
                corner_list.append(line.split(",")[2])
    # "func.max_turbo.T_85.typical","func.max_high.T_85.typical","func.max_nom.T_85.typical","func.max_low.T_85.typical","func.min_turbo.T_85.typical","func.min_high.T_85.typical","func.min_nom.T_85.typical","func.min_low.T_85.typical"}
    for cor in corner_list:
        cmd = "echo "+ cor + " `/nfs/site/proj/lnc/c2dgbcptserver_sc8_fct/cth2_ptserver/cth2_ptserver_root/pt_client.pl -m " + selected_model.get() + "_" +selected_project.get() + "_" +selected_type.get() + "_" + cor + " -c \"get_attribute [get_timing_path  "
        if "min_" in cor:
            cmd = cmd + " -delay_type min "
        if (from_txt.get() != ""):
            cmd = cmd + "\ \-from\ " + from_txt.get()
        if (through_txt.get() != ""):
            cmd = cmd + "\ \-through\ " + through_txt.get()
        if (to_txt.get() != ""):
            cmd = cmd + "\ \-to\ " + to_txt.get() 
        if (exclude_txt.get() != ""):
            cmd = cmd + "\ \-exclude\ " + exclude_txt.get() 
        if (pba_mode_type.get() != "none"):
            cmd = cmd + " -pba_mode " + pba_mode_type.get()
        cmd = cmd + " ] slack \" | grep -e \"^[-0-9]\" | grep -v MODE ` | /usr/bin/less >> /tmp/results_" + USER 
        os.system(cmd)
    cmd = "cat /tmp/results_" + USER + " | column -t | sort > /tmp/results_aligned_" + USER + "  ; xterm -fn fixed -ls -sb -geometry 60x20+100+80 -T \"/usr/bin/less xl\" -e " + viewer + " -S /tmp/results_aligned_" + USER + " &"
    os.system(cmd)


def create_report():
    corner = selected_corner.get()
#    if ((corner == "")):
#        messagebox.showerror('Python Error', 'Please define the corner')
#        return
    cmd = "source ~baselibr/LNC_script/Server/logic_count " + tag + " "
    if "min_" in corner:   
        cmd = cmd + "\ \-delay_type\ min\ "
    if (from_txt.get() != ""):
        cmd = cmd + "\ \-from\ " + from_txt.get()
        from_history_data.insert(0,from_txt.get())	    
        del from_history_data[10:]
        from_txt['values']  = from_history_data 
    if (through_txt.get() != ""):
        cmd = cmd + "\ \-through\ " + through_txt.get()
        th_history_data.insert(0,through_txt.get())	    
        del th_history_data[10:]
        through_txt['values']  = th_history_data 
    if (to_txt.get() != ""):
        cmd = cmd + "\ \-to\ " + to_txt.get() 
        to_history_data.insert(0,to_txt.get())	    
        del to_history_data[10:]
        to_txt['values']  = to_history_data 
    if (exclude_txt.get() != ""):
        cmd = cmd + "\ \-exclude\ " + exclude_txt.get() 
        exclude_history_data.insert(0,exclude_txt.get())	    
        del exclude_history_data[10:]
        exclude_txt['values']  = exclude_history_data 
    if (pba_mode_type.get() != "none"):
        cmd = cmd + "\ \-pba_mode\ " + pba_mode_type.get()
    if (max_path.get() != "" ):
        cmd = cmd + "\ \-max_paths\ " + max_path.get()
    if (nworst.get() != "" ):
        cmd = cmd + "\ \-nworst\ " + nworst.get()
    if (slack_lesser.get() != ""):
        cmd = cmd + "\ \-slack_lesser_than\ " + slack_lesser.get()
#   print(cmd)
    os.system(cmd)

def run_any_cmd():
    global viewer
#    corner = selected_corner.get()
#    if ((corner == "")):
#        messagebox.showerror('Python Error', 'Please define the corner')
#        return
    cmd = "/nfs/site/proj/lnc/c2dgbcptserver_sc8_fct/cth2_ptserver/cth2_ptserver_root/pt_client.pl -m " + tag + " -c \""
    if (free_cmd.get("1.0","end-1c") != ""):
        cmd = cmd + " " + free_cmd.get("1.0","end-1c") + " "   
        cmd = cmd + " \" | /usr/bin/less > /tmp/results_" + USER + " ; xterm -fn fixed -ls -sb -geometry 295x40+100+80 -T \"/usr/bin/less xl\" -e " + viewer + " -S /tmp/results_" + USER + " & "
        os.system(cmd)

def min_max_window():
#    if (from_txt.get() == "") or (to_txt.get() == "" ):
#        messagebox.showerror('Python Error', 'Please define start and end point')
#        return
    corner = selected_corner.get()
    if ("max_" in corner) or (corner == ""):
        messagebox.showerror('Python Error', 'Please define Min Delay corner')
        return
    
    cmd = "/nfs/site/proj/lnc/c2dgbcptserver_sc8_fct/cth2_ptserver/cth2_ptserver_root/pt_client.pl -m " + tag  + " -c \"get_attribute [get_attribute [get_timing_paths "
    if (from_txt.get() != ""):
        cmd = cmd + " -from " + from_txt.get()
    if (through_txt.get() != ""):
        cmd = cmd + " -through " + through_txt.get()
    if (to_txt.get() != ""):
        cmd = cmd + " -to " + to_txt.get() 
    if (exclude_txt.get() != ""):
        cmd = cmd + " -exclude " + exclude_txt.get() 
    if (pba_mode_type.get() != "none"):
        cmd = cmd + " -pba_mode " + pba_mode_type.get()
    cmd = cmd + " -delay_type min ] points ]  object\" | grep -v Warning | grep par | tr -d '\"{},' | sed 's/\\r//g'  > /tmp/" + USER + "_objects "
    os.system(cmd)
    with open('/tmp/'+USER+'_objects', 'r') as file:
        lines = file.readlines()
        line_count = len(lines)
    if (line_count > 0 ):
        cmd = "xterm -fn fixed -ls -sb -geometry 10x10 -e \"source /nfs/site/disks/home_user/baselibr/PNC_script/Server/min_max_window.csh " + selected_model.get()+"_"+selected_project.get()+"_"+selected_type.get()  + "\""
        os.system(cmd)
    else:
        messagebox.showerror('Python Error', 'Did not found timing path')
        
def estimate_buffer_insertion():
    if ( selected_project.get() != "pnc78clienta0" and selected_project.get() != "pnc78clientb0" and selected_project.get() != "gfcn2clienta0" ):
        messagebox.showerror('Python Error', 'Supports only pnc78clienta0')
        return
    
    eco_model = selected_model.get()+"_"+selected_project.get()+"_bu_prp"        
    root=Tk()
    Label(root, text='Please enter a Pin:').pack()
    a = Entry(root,width =70)
    a.pack()
    Button(root, text='Ok', command=lambda:DoSomethingWithInput(a.get())).pack() 
    def DoSomethingWithInput(pin):
        cmd = "xterm -fn fixed -ls -sb -geometry 5x5 -e \"source /nfs/site/disks/home_user/baselibr/PNC_script/Server/estimate_insert_buffer.csh " + str(pin) + " " + eco_model +"\""
        root.destroy()
        os.system(cmd)

def estimate_cell_eco():
    if ( selected_project.get() != "pnc78clienta0" and selected_project.get() != "pnc78clientb0" and selected_project.get() != "gfcn2clienta0"  ):
        messagebox.showerror('Python Error', 'Supports only pnc78clienta0')
        return
    eco_model = selected_model.get()+"_"+selected_project.get()+"_bu_prp"
    root=Tk()
    Label(root, text='Please enter a Cell:').pack()
    a = Entry(root,width =70)
    a.pack()
    Button(root, text='Ok', command=lambda:DoSomethingWithInput(a.get())).pack() 
    def DoSomethingWithInput(pin):
        cmd = "xterm -fn fixed -ls -sb -geometry 5x5 -e \"source /nfs/site/disks/home_user/baselibr/PNC_script/Server/estimate_cell_eco.csh "+ eco_model + " " + str(pin) + "\"" 
        root.destroy()
        os.system(cmd)



def model_sel():
    global selected_model
    if v.get() == 0 :
        selected_model = "modela"
    if v.get()  == 1 :
        selected_model = "modelb"
    model_path = os.path.realpath("/nfs/site/proj/lnc/c2dgbcptserver_sc8_fct/cth2_ptserver/cth2_ptserver_model_links/lnca0/" + selected_model + "_lnca0_bu_prp/" )
    messagebox.showinfo(title="Selected Model", message= "The Selected Model is : " + model_path)

def switch_min_max():
    global tag
    corner = selected_corner.get()
    if ((corner == "")):
        messagebox.showerror('Python Error', 'Please define the corner')
        return
    if "min_" in corner: 
        corner = re.sub("min", "max", corner) 
    else: 
        corner = re.sub("max", "min", corner) 
    selected_corner.set(corner)
    tag  = selected_model.get() + "_" +selected_project.get() + "_" +selected_type.get() + "_" + selected_corner.get()    


def status_html_open(): 
    os.system("xterm  -fn fixed -ls -sb -geometry 300x50 -e w3m /nfs/site/proj/lnc/c2dgbcptserver_sc8_fct/cth2_ptserver/cth2_ptserver_track_system/report.html &")

def on_select(event):
    global tag
    model_path = os.path.realpath("/nfs/site/proj/lnc/c2dgbcptserver_sc8_fct/cth2_ptserver/cth2_ptserver_model_links/"+ selected_project.get()+"/"+selected_model.get()+"_"+selected_project.get()+"_"+selected_type.get())
    corners_data={}
#    pro=selected_project.get()
#    if pro== "pnc78icorea0":
#        selected_model.config(values="latest daily")
#    else:
#        selected_model.config(values="modela modelb")
#
    tag  = selected_model.get() + "_" +selected_project.get() + "_" +selected_type.get() + "_" + selected_corner.get()
    if "cth2_ptserver_model_links" in model_path:
        model_path = "No Server - choose different model"
        selected_corner.set("")
    else:
        path = glob.glob(model_path+"/runs/*/*/sta_pt/*/outputs/*.pt_session.*/../../../")
        if len(path):
            directories_in_curdir = os.listdir(path[0])
            directories_in_curdir = sorted(directories_in_curdir)
            regex1 = re.compile(r'func.*')  
            regex2 = re.compile(r'spec.*')
            regex3 = re.compile(r'fresh.*')
            corners_data = [i for i in directories_in_curdir if regex1.match(i) or regex2.match(i) or regex3.match(i) ]
    
    selected_corner.config(values=corners_data)
    model_label.config(text ='\n'.join(textwrap.wrap("Model: " +model_path, 64)))

    pattern=selected_project.get()+","+selected_type.get()+","+selected_corner.get()+","+selected_model.get()
    matching_lines = [line for line in open('/nfs/site/proj/lnc/c2dgbcptserver_sc8_fct/cth2_ptserver/cth2_ptserver_root//pt_server_c2dgbcptserver_cron.cfg').readlines() if pattern in line]
    if len(matching_lines):
        machine=matching_lines[0].split(",")[5]
        job=matching_lines[0].split(",")[6]
        cmd = "echo '' |  netcat -w 5 " + machine.strip() + " " + job.strip() + "&& echo 'Online' > /dev/null || exit 1 "
        returned_value = os.system(cmd)
        if not returned_value:
            online_offline.config(text="Online",bg='#0f0',fg='#fff')
        else:
            online_offline.config(text="Offline",bg='#f00',fg='#fff')

    else:
        online_offline.config(text="Offline",bg='#f00',fg='#fff')

import socket

def netcat(host, port, content):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.connect((host, int(port)))
    s.sendall(content.encode())
    s.shutdown(socket.SHUT_WR)
    while True:
        data = s.recv(4096)
        if not data:
            break
        print("basel")
    s.close()

viewer = "/usr/bin/less"    
USER = os.environ['USER']
root = tk.Tk()
root.title('FCT Servert TOOL')
total_col = 4 
i = 0 
v = tk.IntVar()
selected_model = "modela"
f1 = tk.Frame(root)
f1.grid(row=i, column=0, sticky="nsew",columnspan = total_col)


tk.Label(f1, text="FCT Server TOOL", fg = "blue",font = "Estrangelo\ Midyat 20 bold ",padx = 80).grid(row=0, column=1,rowspan=2)
model_label=tk.Label(f1, text="Model: ",font = "Ariel 12",width=60)
model_label.grid(row=2, column=1, rowspan=2)
online_offline=tk.Label(f1, text="Status",font = "Ariel 14")
online_offline.grid(row=4, column=1)
tk.Button(f1, text='PT Servers Status', height = 0 , width=20, command=status_html_open).grid(column = 0, row =4,columnspan = 1)

#tk.Label(f1, text="Authored and produced by Ibrahim, Basel", fg = "blue",font = ("Ariel 8") ).grid(row=1, column=1,columnspan = total_col-2)

#canvas = Canvas(f1, width = 120, height = 50)      
#img = PhotoImage(file="~baselibr/lnc_icon.png") 
#canvas.create_image(0,0, anchor=NW, image=img)
#canvas.grid(column = 0, row = 0,rowspan = 2)

canvas2 = Canvas(f1, width = 80, height = 50)     
img2 = PhotoImage(file="~baselibr/intel_icon.png")
canvas2.create_image(0,5, anchor=NW, image=img2)
canvas2.grid(column = 0, row = 0,rowspan = 4)
log_img = PhotoImage(file="~baselibr/LNC_script/sio_assistance_tool/log.png").subsample(10)

#tk.Label(f1, text="""Choose The Ref WA:""",justify = tk.LEFT,padx = 20).grid(row=1, column=0)
#tk.Radiobutton(f1,text="ModelA (Latest)",padx = 20,variable=v,value=0,command=model_sel).grid(row=1, column=1)
#tk.Radiobutton(f1,text="ModelB (Next)",padx = 20,variable=v,value=1,command=model_sel).grid(row=1, column=2) 

projects = "gfcn2clienta0 pnc78icorea0 pnc78clienta0 pnc78clientb0 pnc78servera0 cgc78clienta0 "
corners_data = "func.max_high.TT_100.tttt func.max_high.T_85.typical func.max_low.TT_100.tttt func.max_low.T_85.typical func.max_med.TT_100.tttt func.max_med.T_85.typical func.max_nom.TT_100.tttt func.max_nom.T_85.typical func.max_slow.S_125.cworst_CCworst_T func.max_slow_cold.S_0.cworst_CCworst_T func.max_turbo.T_85.typical func.min_high.T_85.typical func.min_med.T_85.typical func.min_nom.T_85.typical"
model_type = "bu_prp fcl"


#path = "/nfs/site/proj/lnc/c2dgbcptserver_sc8_fct/cth2_ptserver/cth2_ptserver_model_links/*/*/runs/*/*/sta_pt/" 
#directories_in_curdir = os.listdir(path)
#directories_in_curdir = sorted(directories_in_curdir)
#regex = re.compile(r'func.*')    
#corners_data = [i for i in directories_in_curdir if regex.match(i)]
tk.Label(f1, text = "Project:    ").grid(column = 2, row = 0 )
selected_project=Combobox(f1, values=projects, width = 20)
selected_project.grid(column = 3, row = 0 ,columnspan =1 )
selected_project.bind('<<ComboboxSelected>>', on_select)

tk.Label(f1, text = "Corner:    ").grid(column = 2, row = 3 )
selected_corner=Combobox(f1, values=corners_data , width = 20)
selected_corner.grid(column = 3, row = 3 ,columnspan =1 )
selected_corner.bind('<<ComboboxSelected>>', on_select)

tk.Label(f1, text = "Type:    ").grid(column = 2, row = 2 )
selected_type=Combobox(f1, values=model_type , width = 20)
selected_type.grid(column = 3, row = 2 ,columnspan =1 )
selected_type.bind('<<ComboboxSelected>>', on_select)

tk.Label(f1, text = "Model:    ").grid(column = 2, row = 1 )
selected_model=Combobox(f1, values="modela modelb" , width = 20)
selected_model.grid(column = 3, row = 1 ,columnspan =1 )
selected_model.bind('<<ComboboxSelected>>', on_select)

tk.Button(f1, text='Max <--> Min', height = 0 , width=20, command=switch_min_max).grid(column = 3, row = 4,columnspan = 1)



i = i + 1 
f2 = tk.Frame(root)
f2.grid(row=i, column=0, sticky="ew",columnspan = total_col)

    
tk.Label(f2, text = "-from    ").grid(column = 0, row = 1 )
#from_txt = tk.Text(f2, height = 1,width = 70,bg = 'white')
#from_txt = tk.Entry(f2, width = 70,bg = 'white')
#from_txt.grid(column = 1, row = 1,columnspan = 3)
#tk.Button(f2, text='X', height = 0 , width=1, command=lambda:from_txt.delete(1.0, "end")).grid(column = 4, row = 1,columnspan = 3)
from_history_data = [] 
from_txt=Combobox(f2, values=from_history_data , width = 70)
from_txt.grid(column = 1, row = 1 ,columnspan = 3 )
tk.Button(f2, text='X', height = 0 , width=1, command=lambda:from_txt.delete(0, tk.END)).grid(column = 4, row = 1,columnspan = 3)

tk.Label(f2, text = "-through    ").grid(column = 0, row = 2 )
#through_txt = tk.Text(f2, height = 1,width = 70,bg = 'white')
#through_txt = tk.Entry(f2, width = 70,bg = 'white')
#through_txt.grid(column = 1, row = 2,columnspan = 3)
#tk.Button(f2, text='X', height = 0 , width=1, command=lambda:through_txt.delete(1.0, "end")).grid(column = 4, row = 2,columnspan = 3)
th_history_data = [] 
through_txt=Combobox(f2, values=th_history_data , width = 70)
through_txt.grid(column = 1, row = 2 ,columnspan = 3 )
tk.Button(f2, text='X', height = 0 , width=1, command=lambda:through_txt.delete(0, tk.END)).grid(column = 4, row = 2,columnspan = 3)

tk.Label(f2, text = "-to    ").grid(column = 0, row = 3 )
#to_txt = tk.Text(f2, height = 1,width = 70,bg = 'white')
#to_txt = tk.Entry(f2, width = 70,bg = 'white')
#to_txt.grid(column = 1, row =3,columnspan = 3)
#tk.Button(f2, text='X', height = 0 , width=1, command=lambda:to_txt.delete(1.0, "end")).grid(column = 4, row = 3,columnspan = 3)
to_history_data = [] 
to_txt=Combobox(f2, values=to_history_data , width = 70)
to_txt.grid(column = 1, row = 3 ,columnspan = 3 )
tk.Button(f2, text='X', height = 0 , width=1, command=lambda:to_txt.delete(0, tk.END)).grid(column = 4, row = 3,columnspan = 3)

tk.Label(f2, text = "-exclude    ").grid(column = 0, row = 4 )
#exclude_txt = tk.Text(f2, height = 1,width = 70,bg = 'white')
#exclude_txt = tk.Entry(f2, width = 70,bg = 'white')
#exclude_txt.grid(column = 1, row = 4,columnspan = 3)
#tk.Button(f2, text='X', height = 0 , width=1, command=lambda:exclude_txt.delete(1.0, "end")).grid(column = 4, row = 4,columnspan = 3)
exclude_history_data = [] 
exclude_txt=Combobox(f2, values=exclude_history_data , width = 70)
exclude_txt.grid(column = 1, row = 4 ,columnspan = 3 )
tk.Button(f2, text='X', height = 0 , width=1, command=lambda:exclude_txt.delete(0, tk.END)).grid(column = 4, row = 4,columnspan = 3)



tk.Label(f2, text = "-pba_mode    ").grid(column = 0, row = 5 )
data=("none","path","exhaustive","ml_exhaustive") 
pba_mode_type=Combobox(f2, values=data)
pba_mode_type.set("none")
pba_mode_type.grid(column = 1, row = 5)

input_pins_var = IntVar()
Checkbutton(f2,text= "input_pins" ,variable=input_pins_var).grid(row=6, column=0)
capacitance_var = IntVar()
Checkbutton(f2,text= "capacitance" ,variable=capacitance_var).grid(row=6, column=1)
physical_var = IntVar()
Checkbutton(f2,text= "physical" ,variable=physical_var).grid(row=6, column=2)
nets_var= IntVar()
Checkbutton(f2,text= "nets" ,variable=nets_var).grid(row=6, column=3)
transition_time_var= IntVar()
Checkbutton(f2,text= "transition_time" ,variable=transition_time_var).grid(row=7, column=0)
include_hierarchical_pins_var= IntVar()
Checkbutton(f2,text= "include_hierarchical_pins" ,variable=include_hierarchical_pins_var).grid(row=7, column=1)
nosplit_var= IntVar()
Checkbutton(f2,text= "nosplit" ,variable=nosplit_var).grid(row=7, column=2)
trace_latch_borrow_var = IntVar()
Checkbutton(f2,text= "trace_latch_borrow" ,variable=trace_latch_borrow_var).grid(row=7, column=3)
exception_all_var = IntVar()
Checkbutton(f2,text= "exceptions all" ,variable=exception_all_var).grid(row=8, column=1)
crosstalk_var = IntVar()
Checkbutton(f2,text= "crosstalk" ,variable=crosstalk_var).grid(row=8, column=2)
slack_lesser_than_inf_var = IntVar()
Checkbutton(f2,text= "slack_lesser_than inf" ,variable=slack_lesser_than_inf_var).grid(row=8, column=3)



tk.Label(f2, text = "manual flags:    ").grid(column = 0, row = 9 )
manual_txt = tk.Text(f2, height = 1,width = 70,bg = 'white')
manual_txt.grid(column = 1, row = 9,columnspan = 3)
tk.Button(f2, text='X', height = 0 , width=1, command=lambda:manual_txt.delete(1.0, "end")).grid(column = 4, row = 9,columnspan = 3)
#tk.Button(f2, text='X', height = 0 , width=1, command=lambda:manual_txt.delete(0, tk.END)).grid(column = 4, row = 9,columnspan = 3)

button1 = tk.Button(f2, text='Report_timing', width=15, command=report_timing)
button1.grid(row=10, column=0,columnspan = 1)
button1 = tk.Button(f2, text='Mail Report_timing ', width=15, command=send_timing_report_to_mail)
button1.grid(row=10, column=1,columnspan = 1) 

button2 = tk.Button(f2, text='Draw path', width=15, command=draw_path)
button2.grid(row=10, column=2,columnspan = 1) 
button3 = tk.Button(f2, text='Get Slack', width=15, command=all_corner_slack)
button3.grid(row=10, column=3,columnspan = 1) 

button5 = tk.Button(f2, text='min max analysis', width=15, command=min_max_window)
button5.grid(row=11, column=2,columnspan = 1)
button5 = tk.Button(f2, text='estimate insert buffer', width=15, command=estimate_buffer_insertion)
button5.grid(row=11, column=3,columnspan = 1)
button5 = tk.Button(f2, text='estimate cell eco', width=15, command=estimate_cell_eco)
button5.grid(row=12, column=3,columnspan = 1)




f3 = tk.Frame(root,highlightbackground="blue", highlightthickness=2)
f3.grid(row=3, column=0, sticky="w")
tk.Label(f3, text='Summary Report', width=15).grid(row=0, column=0,columnspan = 3)
tk.Label(f3, text = "nworst ").grid(column = 0, row = 1 )
nworst = tk.Entry(f3, width = 5,bg = 'white')
nworst.grid(column = 1, row = 1)
tk.Button(f3, text='X', height = 0 , width=1, command=lambda:nworst.delete(0, tk.END)).grid(column = 2, row = 1) 
tk.Label(f3, text = "max_path ").grid(column = 0, row = 2 )
max_path = tk.Entry(f3, width = 5,bg = 'white')
max_path.grid(column = 1, row = 2)
tk.Label(f3, text = "slack_lesser ").grid(column = 0, row = 3 )
slack_lesser = tk.Entry(f3, width = 5,bg = 'white')
slack_lesser.grid(column = 1, row = 3)

tk.Button(f3, text='X', height = 0 , width=1, command=lambda:max_path.delete(0, tk.END)).grid(column = 2, row = 2)
tk.Button(f3, text='X', height = 0 , width=1, command=lambda:slack_lesser.delete(0, tk.END)).grid(column = 2, row = 3)
tk.Button(f3, text='X', height = 0 , width=1, command=lambda:nworst.delete(0, tk.END)).grid(column = 2, row = 1) 

tk.Button(f3, text='Create', command=lambda:create_report()).grid(column = 0, row = 4,columnspan=2)
tk.Button(f3, text='Mail', command=lambda:mail_path_report()).grid(column = 2, row = 4,columnspan=1)


f4 = tk.Frame(root,highlightbackground="blue", highlightthickness=2)
f4.grid(row=3, column=1, sticky="w")
tk.Label(f4, text='Run command', width=15).grid(row=0, column=0,columnspan=5)
free_cmd = tk.Text(f4, height = 6,width = 65,bg = 'white')
free_cmd.grid(column = 0, row = 1,columnspan=4,rowspan=2)
button4 = tk.Button(f4, text='Run', width=2, command=run_any_cmd)
button4.grid(row=1, column=4)
tk.Button(f4, text='X', height = 0 , width=1, command=lambda:free_cmd.delete(1.0, "end")).grid(column = 4, row = 2) 
tk.Button(f4, text='?', height = 0 , width=1, command=lambda:messagebox.showinfo("Information", "For variable use:            \'\"\\$\'\" \nBefore new line add:       \\\nBefore * add:              \*")).grid(column = 4, row = 0) 


#fcts_cth2 -m modelb_lnca0_bu_prp_func.max_nom.T_85.typical -c "report_timing -th par_exe_int/rspdstm805h_1_[2] -nosplit "

#### default values at the config file
config_file = os.path.realpath(os.path.expanduser('~/.fct_server_tool.defaults'))

if os.path.exists(config_file):
    for line in open(config_file, 'r'): 
        if re.search("^project", line):
            selected_project.set(line.split()[1])
        if re.search("^type", line):
            selected_type.set(line.split()[1])
        if re.search("^model",line):
            selected_model.set(line.split()[1])
        if re.search("^corner", line):
            default_corner = line.split()[1]
            selected_corner.set(default_corner)
        if re.search("^input_pins", line) and line.split()[1]=="1":
            input_pins_var.set(TRUE)
        if re.search("^capacitance", line) and line.split()[1]=="1":
            capacitance_var.set(TRUE)
        if re.search("^physical", line) and line.split()[1]=="1":
            physical_var.set(TRUE)
        if re.search("^transition_time", line) and line.split()[1]=="1":
            transition_time_var.set(TRUE)
        if re.search("^exception_all", line) and line.split()[1]=="1":
            exception_all_var.set(TRUE)
        if re.search("^trace_latch_borrow", line) and line.split()[1]=="1":
            trace_latch_borrow_var.set(TRUE)
        if re.search("^nosplit", line) and line.split()[1]=="1":
            nosplit_var.set(TRUE)	    
        if re.search("^include_hierarchical_pins", line) and line.split()[1]=="1":
            include_hierarchical_pins_var.set(TRUE)
        if re.search("^nets", line) and line.split()[1]=="1":
            nets_var.set(TRUE)
        if re.search("^viewer", line) and line.split()[1]!="" :
            viewer = line.split()[1]
        if re.search("^crosstalk", line) and line.split()[1]=="1":
            crosstalk_var.set(TRUE)
        if re.search("^slack_lesser_than_inf", line) and line.split()[1]=="1":
            slack_lesser_than_inf_var.set(TRUE)

on_select(0)
root.mainloop()
