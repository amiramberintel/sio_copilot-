#!/usr/intel/bin/python3.11.1
from tkinter import *
from tkinter import filedialog
from tkinter.ttk import Combobox
import os
import tkinter as tk
import re
from pathlib import Path
def browseFiles(type):
    par  = str(cb.get())
    initial_dir = "~/"
    if type == "internal_excep":
       	initial_dir = os.path.realpath("runs/" + par + "/n2p_htall_conf4/release/latest/sio_timing_collateral")
    if type == "spec":
        initial_dir = os.path.realpath(spec_dir)
    if type == "ft_spec":
        initial_dir = os.path.realpath(ft_spec_dir)
    if type == "sio_ovr" or type == "remove_sio_ovr" :
        filename = "not_relevant"
    if type == "internal_excep":   
        if v.get() == 1 :
            filename = filedialog.askdirectory(initialdir =initial_dir ,title = "Select a directory")
        else :
            filename = filedialog.askopenfilename(initialdir =initial_dir ,title = "Select a File",filetypes = (("Tcl files","*.tcl"),("all files","*.*")))
    if type == "spec" or type == "ft_spec" :
        filename = filedialog.askopenfilename(initialdir =initial_dir ,title = "Select a File",filetypes = (("Csv files","*.csv"),("all files","*.*")))
    if type == "update_partition_tag":
        filename = "not_relevant"

    if filename != "" and str(filename) != "()":
        if par != "" :
            cmd = 'xterm -e ~baselibr/GFC_script/sio_spec_ci.csh -type ' + str(type) + ' -par ' + str(par) + ' -file ' +  str(filename)  
            os.system(cmd)

def get_ref_file(type):
    par  = str(cb.get())
    ref_filename = "$PROJ_ARCHIVE/arc/${par}/sio_timing_collateral/GOLDEN/${par}_internal_exceptions.tcl"
	
def view_log():
    cmd = 'xterm -e less -R /tmp/$USER.p4.log &'
    os.system(cmd)

def view_xmls():
        par  = str(cb.get())
        cmd = 'xterm -geometry +100+350 -e less -R ${ward}/runs/' + par + '/$tech/release/golden/timing_specs/reports/' + par +'_timing_specs.xml  &'
        os.system(cmd)
        cmd = 'xterm -e less -R ${ward}/runs/' + par + '/$tech/release/golden/timing_specs/reports/' + par +'_ft_timing_specs.xml &'
        os.system(cmd)
def open_compare_tool():
    os.system('/nfs/site/disks/pnc_fct_bu/work_area/fct_scripts/PNC/collaterals_diff_gui.py &')
    
# Create the root window
window = Tk()
  
# Set window title
window.title('SIO Spec CI')
  
# Set window size
#window.geometry("500x500")
config_file = os.path.realpath(os.path.expanduser('~/.spec_ci_p4.defaults'))
spec_dir = "~/"
ft_spec_dir = "~/"
par = ""

if os.path.exists(config_file):
    for line in open(config_file, 'r'): 
        if re.search("^spec_dir", line):
            spec_dir = (os.path.expanduser(line.split()[1]))
        if re.search("^ft_spec_dir", line):
            ft_spec_dir = (os.path.expanduser(line.split()[1]))
        if re.search("^partition", line):
            par = line.split()[1]
	    

label_partiton = Label(window,text = "Choose Partiton:",width = 20, height = 2,fg = "black")
data=("par_exe", "par_fe", "par_fmav0" , "par_fmav1" , "par_meu", "par_mlc", "par_msid", "par_ooo_int", "par_ooo_vec", "par_pm", "par_pmh", "par_tmul", "par_tmul_stub", "par_vpmm")
cb=Combobox(window, values=data)
cb.set(par)
    
label_file_explorer = Label(window,text = "Choose Type:",width = 20, height = 2,fg = "black")
button_Spec = Button(window,text = "Spec",command =lambda: browseFiles("spec") )
button_FT_Spec = Button(window,text = "FT Spec",command =lambda: browseFiles("ft_spec") )
button_view_log = Button(window,text = "View Spec Log",command=view_log,width = 10,)
button_view_xml = Button(window,text = "View Spec XML",command=view_xmls,width = 10,)


button_intenal = Button(window,text = "Intenal Exp",command =lambda: browseFiles("internal_excep",) )

v = tk.IntVar()
button_intenal_dir = Radiobutton(window,text="Directory",padx = 20,variable=v,value=1).grid(column = 4, row = 3)
button_intenal_file = Radiobutton(window,text="File",padx = 20,variable=v,value=2).grid(column = 4, row = 4)
button_sio_ovr = Button(window,text = "CI SIO OVR To BU",command =lambda: browseFiles("sio_ovr",) )
button_remove_sio_ovr = Button(window,text = "Remove SIO OVR",command =lambda: browseFiles("remove_sio_ovr",) )
button_compare_ovr = Button(window,text = "View/Compare Ovr Tool", command = lambda: open_compare_tool())
button_update_partition_tag = Button(window,text = "Update Par Tag",command =lambda: browseFiles("update_partition_tag",) )



button_exit = Button(window,text = "Exit",command = exit)
  
# locations 
label_partiton.grid(column = 1, row = 1)
cb.grid(column = 2, row = 1,columnspan = 3)

label_file_explorer.grid(column = 1, row = 2)
button_Spec.grid(column = 2, row = 2)
button_FT_Spec.grid(column = 3, row = 2)
button_view_log.grid(column = 2, row = 3 , columnspan=2)
button_view_xml.grid(column = 2, row = 4 , columnspan=2)

button_intenal.grid(column = 4, row = 2)
button_sio_ovr.grid(column = 5, row = 2)
button_remove_sio_ovr.grid(column = 5, row = 3)
button_compare_ovr.grid(column=5,row=1)


button_update_partition_tag.grid(column = 3, row = 5)
button_exit.grid(column = 3,row = 6)
 
canvas = Canvas(window, width = 150, height = 100)      
img = PhotoImage(file="~baselibr/GFC_logo.png") 
canvas.create_image(20,20, anchor=NW, image=img)
canvas.grid(column = 1, row = 5,columnspan = 2,rowspan=2)

canvas2 = Canvas(window, width = 150, height = 100)      
img2 = PhotoImage(file="~baselibr/intel_icon.png") 
canvas2.create_image(35,25, anchor=NW, image=img2)
canvas2.grid(column = 4, row = 5,columnspan = 2,rowspan=2)


# Let the window wait for any events
window.mainloop()
