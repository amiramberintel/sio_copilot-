#!/usr/intel/bin/python3.7.4

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
from tkinter.colorchooser import askcolor
import tkinter.font as font



def compare_files_of_type(dir1,dir2,type):
    list_of_file = os.listdir(dir1) + os.listdir(dir2)
    list_of_file_uniq = []
    for file in list_of_file:
        if file.endswith(type):
           if not (file in list_of_file_uniq):
                list_of_file_uniq.append(file) 
    
    for file in list_of_file_uniq:
         cmd = "meld " + os.path.realpath(os.path.expanduser(dir1 +"/"+ file )) + " " + os.path.realpath(os.path.expanduser(dir2+"/"+file))+ " &" 
         os.system(cmd)

def compare_file(file1,file2):
    cmd = "meld " + os.path.realpath(os.path.expanduser(file1)) + " " + os.path.realpath(os.path.expanduser(file2))+ " &" 
    os.system(cmd)

def view_file(file): 
    cmd = editor + " " + file + " &"
    os.system(cmd)


def choose_and_view_file(dir):
    filename = filedialog.askopenfilename(initialdir = os.path.realpath(dir) ,title = "Select a File",filetypes = (("Sdc files","*.sdc"),("all files","*.*")))
    selection = str(filename)
    cmd = editor + " " + selection + " &"
    os.system(cmd)


def on_select(event):
    selected = event.widget.get()

global config_file 
global editor
global default_size


editor = "gvim"



root = tk.Tk()
root.title('Collaterlas Diff TOOL')




v = tk.IntVar()
ref_wa = tk.StringVar()

total_col = 6
wa = os.environ['ward']; #.split("/")[-1]  
ref_wa = os.environ['REF_MODEL']
proj_archive = os.environ['PROJ_ARCHIVE']
block = os.environ['block']
tech = os.environ['tech']
flow = os.environ['flow']
user = os.environ['USER']

i = 1 
f1 = tk.Frame(root)
f1.grid(row=i, column=0, sticky="ew",columnspan = total_col)
tk.Label(f1, text="""Edit / Compare Collaterals Tool""", fg = "blue",font = "Verdana 18 bold",padx = 120).grid(row=	0, column=0,columnspan = 9) 

tk.Label(f1, text="""Partition:""",justify = tk.LEFT,padx = 100).grid(row=6, column=0) 
data=("par_exe", "par_exe_int", "par_fe", "par_fma", "par_meu", "par_mlc", "par_msid", "par_ooo_int", "par_ooo_vec", "par_pm", "par_pmhglb", "par_tmul", "par_tmul_stub")
input_par=Combobox(f1, values=data)
input_par.grid(row=6, column=1)
input_par.bind('<<ComboboxSelected>>', on_select)

i = i + 1
# FRAME 4: Edit compare and CI collaterals 
f4 = tk.Frame(root)
f4.grid(row=i, column=0, sticky="ew",columnspan = total_col)
i=i+1

tk.Label(f4, text="""Edit File""", fg = "blue4",font = "Verdana 13"  ).grid(row=2, column=0) 
tk.Label(f4, text="""Compare \n To """, fg = "blue4",font = "Verdana 13"  ).grid(row=3, column=0,rowspan=3)

##### SIO OVERRIde
button8_1 = Button(f4, text='Edit', width=5, command=lambda: view_file("runs/"+ input_par.get() + "/${tech}/release/latest/sio_ovr/"+ input_par.get() + "_sio_ovrs.tcl"))
button8_2 = Button(f4, text='REF BU', width=5, command=lambda: compare_file(ref_wa + "/runs/"+ input_par.get() + "/${tech}/release/latest/sio_ovr/"+ input_par.get() +"_sio_ovrs.tcl","runs/" + input_par.get() + "/${tech}/release/latest/sio_ovr/"+ input_par.get() +"_sio_ovrs.tcl"))
#button8_3 = Button(f4, text='Par Arc', width=5, command=lambda: compare_file(proj_archive + "/arc/${block}/sio_timing_collateral/"+ input_par.get() +"_sio_ovr/"+ input_par.get() +"_sio_ovrs.tcl","runs/" + input_par.get() + "/${tech}/release/latest/sio_ovr/"+ input_par.get() +"_sio_ovrs.tcl" ))
button8_4 = Button(f4, text='BU Arc', width=5, command=lambda: compare_file(proj_archive + "/arc/"+ input_par.get() + "/sio_ovr/GOLDEN/"+ input_par.get() + "_sio_ovrs.tcl","runs/" + input_par.get() + "/${tech}/release/latest/sio_ovr/"+ input_par.get() +"_sio_ovrs.tcl" ))

tk.Label(f4, text="""Sio_ovr""", fg = "blue4",font = "Verdana 13 bold"  ).grid(row=1, column=1) 

button8_1.grid(row=2, column=1) 
button8_2.grid(row=3, column=1)
#button8_3.grid(row=4, column=1) 
button8_4.grid(row=5, column=1) 

##### FDR 
button9_1 = Button(f4, text='Edit', width=5, command=lambda: view_file("runs/"+ input_par.get() + "/${tech}/release/latest/timing_collateral/"+ input_par.get() + ".fdr_exceptions.tcl"))
button9_2 = Button(f4, text='REF BU', width=5, command=lambda: compare_file(ref_wa + "/runs/"+ input_par.get() + "/${tech}/release/latest/timing_collateral/" + input_par.get() + ".fdr_exceptions.tcl","runs/" + input_par.get() + "/${tech}/release/latest/timing_collateral/"+ input_par.get() + ".fdr_exceptions.tcl"))
button9_3 = Button(f4, text='Par Arc', width=5, command=lambda: compare_file(proj_archive + "/arc/" + input_par.get() + "/fe_collateral/$TIMING_TAG/" + input_par.get() + ".fdr_exceptions.tcl","runs/"+ input_par.get() + "/${tech}/release/latest/timing_collateral/" + input_par.get() + ".fdr_exceptions.tcl"))
button9_4 = Button(f4, text='BU Arc', width=5, command=lambda: compare_file(proj_archive + "/arc/"+ input_par.get() + "/sio_ovr/GOLDEN/" + input_par.get() + ".fdr_exceptions.tcl ","runs/"+ input_par.get() + "/${tech}/release/latest/timing_collateral/" + input_par.get() + ".fdr_exceptions.tcl"))
tk.Label(f4, text="""FDR""", fg = "blue4",font = "Verdana 13 bold"  ).grid(row=1, column=2) 
button9_1.grid(row=2, column=2) 
button9_2.grid(row=3, column=2)
button9_3.grid(row=4, column=2) 
button9_4.grid(row=5, column=2) 

##### Internal Exceptions 
button10_1 = Button(f4, text='Edit', width=5, command=lambda: view_file("runs/"+ input_par.get() + "/${tech}/release/latest/sio_timing_collateral/"+ input_par.get() + "_internal_exceptions.tcl"))
button10_2 = Button(f4, text='REF BU', width=5, command=lambda: compare_file(ref_wa + "/runs/"+ input_par.get() + "/${tech}/release/latest/sio_timing_collateral/" + input_par.get() + "_internal_exceptions.tcl","runs/" + input_par.get() + "/${tech}/release/latest/sio_timing_collateral/"+ input_par.get() + "_internal_exceptions.tcl"))
button10_3 = Button(f4, text='Archive', width=5, command=lambda: compare_file(proj_archive + "/arc/" + input_par.get() + "/sio_timing_collateral/GOLDEN/" + input_par.get() + "_internal_exceptions.tcl","runs/"+ input_par.get() + "/${tech}/release/latest/sio_timing_collateral/" + input_par.get() + "_internal_exceptions.tcl" ))
tk.Label(f4, text="""Inter. Exp""", fg = "blue4",font = "Verdana 13 bold"  ).grid(row=1, column=3) 
button10_1.grid(row=2, column=3) 
button10_2.grid(row=3, column=3)
button10_3.grid(row=4, column=3) 

##### Global mbist 
tk.Label(f4, text="""Mbist TCL""", fg = "blue4",font = "Verdana 13 bold"  ).grid(row=1, column=4) 
button11_1 =Button(f4, text='Edit', width=5, command=lambda: view_file("runs/"+ input_par.get() + "/${tech}/release/latest/timing_collateral/"+ input_par.get() + "_mbist_exceptions.tcl"))
button11_2 =Button(f4, text='REF BU', width=5, command=lambda: compare_file(ref_wa + "/runs/"+ input_par.get() + "/${tech}/release/latest/timing_collateral/"+ input_par.get() + "_mbist_exceptions.tcl","runs/"+ input_par.get() + "/${tech}/release/latest/timing_collateral/"+ input_par.get() + "_mbist_exceptions.tcl"))
button11_3 =Button(f4, text='Par Arc', width=5, command=lambda: compare_file(proj_archive + "/arc/" + input_par.get() + "/timing_collateral/$TIMING_TAG/" + input_par.get() + "_mbist_exceptions.tcl", "runs/"+ input_par.get() + "/${tech}/release/latest/timing_collateral/"+ input_par.get() + "_mbist_exceptions.tcl" ))
button11_4 =Button(f4, text='BU Arc', width=5, command=lambda: compare_file(proj_archive + "/arc/"+ input_par.get() + "/sio_ovr/GOLDEN/" + input_par.get() + "_mbist_exceptions.tcl", "runs/"+ input_par.get() + "/${tech}/release/latest/timing_collateral/"+ input_par.get() + "_mbist_exceptions.tcl" ))
button11_1.grid(row=2, column=4) 
button11_2.grid(row=3, column=4)
button11_3.grid(row=4, column=4) 
button11_4.grid(row=5, column=4) 


##### array mcp 
tk.Label(f4, text="""Array MCP""", fg = "blue4",font = "Verdana 13 bold"  ).grid(row=1, column=5) 
button12_1 =Button(f4, text='Edit', width=5, command=lambda: view_file("runs/"+ input_par.get() + "/${tech}/release/latest/timing_collateral/"+ input_par.get() + ".arrays_mcp.tcl"))
button12_2 =Button(f4, text='REF BU', width=5, command=lambda: compare_file(ref_wa + "/runs/"+ input_par.get() + "/${tech}/release/latest/timing_collateral/"+ input_par.get() + ".arrays_mcp.tcl","runs/"+ input_par.get() + "/${tech}/release/latest/timing_collateral/"+ input_par.get() + ".arrays_mcp.tcl"))
button12_3 =Button(f4, text='Par Arc', width=5, command=lambda: compare_file(proj_archive + "/arc/" + input_par.get() + "/timing_collateral/$TIMING_TAG/" + input_par.get() + ".arrays_mcp.tcl","runs/"+ input_par.get() + "/${tech}/release/latest/timing_collateral/"+ input_par.get() + ".arrays_mcp.tcl"))
button12_4 =Button(f4, text='BU Arc', width=5, command=lambda: compare_file(proj_archive + "/arc/"+ input_par.get() + "/sio_ovr/GOLDEN/" + input_par.get() + ".arrays_mcp.tcl","runs/"+ input_par.get() + "/${tech}/release/latest/timing_collateral/"+ input_par.get() + ".arrays_mcp.tcl"))
button12_1.grid(row=2, column=5) 
button12_2.grid(row=3, column=5)
button12_3.grid(row=4, column=5)
button12_4.grid(row=5, column=5) 
    


#### Mbist Sdc 
tk.Label(f4, text="""Mbist SDC""", fg = "blue4",font = "Verdana 13 bold"   ).grid(row=1, column=6) 
button11_1 =Button(f4, text='Edit', width=5, command=lambda: choose_and_view_file("runs/"+ input_par.get() + "/" + tech + "/release/latest/timing_collateral/"))
button11_2 =Button(f4, text='REF BU', width=5, command=lambda: compare_files_of_type(ref_wa + "runs/"+ input_par.get() + "/" + tech + "/release/latest/timing_collateral/","runs/"+ input_par.get() + "/" + tech + "/release/latest/timing_collateral/",".sdc"))
button11_3 =Button(f4, text='Par Arc', width=5, command=lambda: compare_files_of_type(proj_archive + "/arc/" + input_par.get() + "/timing_collateral/" + os.environ['TIMING_TAG'] , "runs/" + input_par.get() + "/" + tech + "/release/latest/timing_collateral/",".sdc")) 
button11_4 =Button(f4, text='BU Arc', width=5, command=lambda: compare_files_of_type(proj_archive + "/arc/"+ input_par.get() + "/sio_ovr/GOLDEN/" , "runs/" + input_par.get() + "/" + tech + "/release/latest/timing_collateral/",".sdc")) 

button11_1.grid(row=2, column=6) 
button11_2.grid(row=3, column=6)
button11_3.grid(row=4, column=6)
button11_4.grid(row=5, column=6)


##### FDR 
tk.Label(f4, text="""HIP OVR""", fg = "blue4",font = "Verdana 13 bold"   ).grid(row=1, column=7)     
button13_1 = Button(f4, text='Edit', width=5, command=lambda: view_file("runs/"+ input_par.get() + "/${tech}/release/latest/hip_ovr/"+ input_par.get() +".hip_ovrs.xml "))
button13_2 = Button(f4, text='REF BU', width=5, command=lambda: compare_file(ref_wa + "/runs/"+ input_par.get() + "/${tech}/release/latest/hip_ovr/"+ input_par.get() +".hip_ovrs.xml ","runs/" + input_par.get() + "/${tech}/release/latest/hip_ovr/"+ input_par.get() +".hip_ovrs.xml "))
#button13_3 = Button(f4, text='Par Arc', width=5, command=lambda: compare_file(proj_archive + "/arc/" + input_par.get() + "/fe_collateral/$TIMING_TAG/" + input_par.get() + ".fdr_exceptions.tcl","runs/"+ input_par.get() + "/${tech}/release/latest/timing_collateral/" + input_par.get() + ".fdr_exceptions.tcl"))
button13_4 =Button(f4, text='BU Arc', width=5, command=lambda: compare_file(proj_archive + "/arc/"+ input_par.get() + "/sio_ovr/GOLDEN/"+ input_par.get() +".hip_ovrs.xml ", "runs/"+ input_par.get() + "/${tech}/release/latest/hip_ovr/"+ input_par.get() +".hip_ovrs.xml " ))
button13_1.grid(row=2, column=7) 
button13_2.grid(row=3, column=7)
#button13_3.grid(row=4, column=7) 
button13_4.grid(row=5, column=7) 




my_button = Button(f4, text='Exit',width=25, command = exit )
my_button.grid(row=6 , column=2 , columnspan = total_col - 1 ) 
my_button.bind('<Destroy>', exit )


root.mainloop()
