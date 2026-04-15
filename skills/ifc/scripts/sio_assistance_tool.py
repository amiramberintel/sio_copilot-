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
from tkinter.messagebox import askyesno
import re

def change_color():
    colors = askcolor(title="Tkinter Color Chooser")
    f1.configure(bg=colors[1])
    f2.configure(bg=colors[1])
    f3.configure(bg=colors[1])
    f4.configure(bg=colors[1])
    root.configure(bg=colors[1])
    for widget in root.winfo_children():
        if isinstance(widget, Label):
            widget.config(bg=colors[1])
    
    for user_frame in root.winfo_children():
        if isinstance(user_frame, Frame):
              for widget in user_frame.winfo_children():
                  if isinstance(widget, Checkbutton) or isinstance(widget, Label) or isinstance(widget,PhotoImage) :
                       widget.config(bg=colors[1])
def change_size(new_size):
    global default_size
    default_size = default_size + new_size
    print (default_size)
    for widget in root.winfo_children():
        if isinstance(widget, Checkbutton) or isinstance(widget, Label) or isinstance(widget,Button) :
            widget.config(font=font.Font(size=default_size))	    
    for user_frame in root.winfo_children():
        if isinstance(user_frame, Frame):
              for widget in user_frame.winfo_children():
                  if isinstance(widget, Checkbutton) or isinstance(widget, Label) or isinstance(widget,Button) :
                       widget.config(font=font.Font(size=default_size))      
def ref_sel():
    real_path = ""
    if v.get() == 1 :
        real_path = os.path.realpath("/nfs/iil/disks/home01/gilkeren/lnc_links/latest_lnc0a_n3_bu_post/")		
    if v.get()  == 2 :
        real_path = os.path.realpath("/nfs/iil/disks/home01/gilkeren/lnc_links/next_lnc0a_n3_bu_post/")
    selection = str(real_path)
    ref_wa.set(selection)
    label.xview_moveto(1)
def browseDir():
    real_path = filedialog.askdirectory()
    selection = str(real_path)
    ref_wa.set(selection)
    label.xview_moveto(1)
def space(space_fg=0):
    global i
    if space_fg:
        tk.Label(root, text="").grid(row=i, column=0)
        i=i+1
    ttk.Separator(root,orient='horizontal').grid(row=i, sticky="ew" ,columnspan = total_col) 
    i=i+1
def good_bye(*args):
    os.system('touch gui_done.log')
def disable_buttons():
    button1["state"] = DISABLED
    button2["state"] = DISABLED
    button3["state"] = DISABLED
    button4["state"] = DISABLED
    button5["state"] = DISABLED
    button6["state"] = DISABLED
    button7["state"] = DISABLED
    button7_1["state"] = DISABLED
    button7_2["state"] = DISABLED
    button7_3["state"] = DISABLED
    button7_4["state"] = DISABLED
    button7_5["state"] = DISABLED
    button7_6["state"] = DISABLED
    button7_7["state"] = DISABLED
    button7_8["state"] = DISABLED
    button7_9["state"] = DISABLED
    cb_1["state"] = DISABLED
    cb_2["state"] = DISABLED
    cb_3["state"] = DISABLED
    cb_fishtail["state"] = DISABLED
    cb_4["state"] = DISABLED
    cb_5["state"] = DISABLED
    cb_6["state"] = DISABLED
    cb_7["state"] = DISABLED
def enable_buttons():
    button1["state"] = NORMAL
    button2["state"] = NORMAL
    button3["state"] = NORMAL
    button4["state"] = NORMAL
    button5["state"] = NORMAL
    button6["state"] = NORMAL
    button7["state"] = NORMAL
    button7_1["state"] = NORMAL
    button7_2["state"] = NORMAL
    button7_3["state"] = NORMAL
    button7_4["state"] = NORMAL
    button7_5["state"] = NORMAL
    button7_6["state"] = NORMAL
    button7_7["state"] = NORMAL
    button7_8["state"] = NORMAL
    button7_9["state"] = NORMAL
    cb_1["state"] = NORMAL
    cb_2["state"] = NORMAL
    cb_3["state"] = NORMAL
    cb_fishtail["state"] = NORMAL
    cb_4["state"] = NORMAL
    cb_5["state"] = NORMAL
    cb_6["state"] = NORMAL
    cb_7["state"] = NORMAL
def source_define ():
#    cmd = "source /p/hdk/pu_tu/prd/fct_alias/rshahav_sbox/utils/fct_run_aliases "
#    os.system("echo " + cmd + '>  gui_run_command.csh_temp')
    cmd = "unsetenv REF_MODEL"
    os.system("echo " + cmd + '>  gui_run_command.csh_temp')
    cmd = "rm -f ref"
    os.system("echo " + cmd + '>>  gui_run_command.csh_temp')   
#    cmd = "source ~gilkeren/.aliases "
#    os.system("echo " + cmd + '>>  gui_run_command.csh_temp')		
    cmd = "setenv REF_MODEL " + label.get() 
    os.system("echo " + cmd + '>>  gui_run_command.csh_temp')	
#    cmd = "ln -s "+ label.cget("text") + " ref"
#    os.system("echo " + cmd + '>>  gui_run_command.csh_temp')
    cmd = "\#step source_define.log"
    os.system("echo " + cmd + '>> gui_run_command.csh_temp')
    os.system('mv gui_run_command.csh_temp gui_run_command.csh')
    button.configure(bg="yellow")   
    while os.path.exists("./gui_run_command.csh"):
    	root.update()
    	time.sleep(1)
    button.configure(bg="green")
def cthPrep ():
    os.system("echo source $GFC_FCT_SCRIPTS/cthPrep.csh > gui_run_command.csh_temp" );
    os.system("echo \#step cthPrep.log >> gui_run_command.csh_temp")
    os.system('mv gui_run_command.csh_temp gui_run_command.csh')
    button1.configure(bg="yellow")
    while os.path.exists("./gui_run_command.csh"):
    	time.sleep(1)
    	root.update()
    button1.configure(bg="green")
def cp_bu():
    inp_par = input_par.get()
    inp_tag = input_tag.get()
    if ((inp_par != "") and (inp_tag != "")) :
        cmd = "source $GFC_FCT_SCRIPTS/cp_bu.csh "+ inp_par + ' ' + inp_tag
        os.system("echo " + cmd + '>  gui_run_command.csh_temp')
        os.system("echo \#step cp_bu.log >> gui_run_command.csh_temp")
        os.system('mv gui_run_command.csh_temp gui_run_command.csh')
        button2.configure(bg="yellow")
        while os.path.exists("./gui_run_command.csh"):
    	    time.sleep(1)
    	    root.update()
        button2.configure(bg="green")
    else:
        messagebox.showerror('Python Error', 'Please Choose Partition/Tag')

def run_fishtail():
#    if (fish_par != input_par.get()) :
#        answer = askyesno(title='confirmation', message='You ran Cp BU more that once , Are you sure that you want to run Fishtail on all partitions?')
#        if not answer:
#            return 
#    if (fish_par != "") :
#        cmd = "$PNC_FCT_SCRIPTS/fishtail.tcl -partitions \""+fish_par+ "\"" 
        cmd = "$GFC_FCT_SCRIPTS/fishtail.tcl"
        os.system("echo " + cmd + '>  gui_run_command.csh_temp')
        os.system("echo \#step fishtail.log >> gui_run_command.csh_temp")
        os.system('mv gui_run_command.csh_temp gui_run_command.csh')
        button_fishtail.configure(bg="yellow")
        while os.path.exists("./gui_run_command.csh"):
    	    time.sleep(1)
    	    root.update()
        button_fishtail.configure(bg="green")
#    else:
#        messagebox.showerror('Python Error', 'Please Write partitions to run on with , between .')
    
def prepare_hip():
#    cmd = "source $LNC_FCT_SCRIPTS/prepare_hip.csh "
    cmd = "sta_prepare_hip"
    os.system("echo " + cmd + '>  gui_run_command.csh_temp')
    os.system("echo \#step prepare_hip.log >> gui_run_command.csh_temp")
    os.system('mv gui_run_command.csh_temp gui_run_command.csh')
    button3.configure(bg="yellow")
    while os.path.exists("./gui_run_command.csh"):
        time.sleep(1)
        root.update()
    button3.configure(bg="green")
def sta_setup():
#    cmd = "eouMGR --block $block --prepare_hip"
#    os.system("echo " + cmd + '>  gui_run_command.csh_temp')	
#    cmd = "sta_prepare_hip"
#    os.system("echo " + cmd + '>>  gui_run_command.csh_temp')
    cmd = "$ward/global/snps/$flow/sta_setup.tcl -B $block -D $block -S $SRC_TASK --scenario $FCT_SCENARIOS"
    os.system("echo " + cmd + '>>  gui_run_command.csh_temp')
    os.system("echo \#step sta_setup.log >> gui_run_command.csh_temp")
    os.system('mv gui_run_command.csh_temp gui_run_command.csh')
    button4.configure(bg="yellow")
    while os.path.exists("./gui_run_command.csh"):
        time.sleep(1)
        root.update()
    button4.configure(bg="green")
def update_spec():
#    cmd ="cd runs/$block/$tech/$flow/scripts/spec/inputs/"
#    os.system("echo " + cmd + '>  gui_run_command.csh_temp')	    
#    cmd ="p4 sync"
#    os.system("echo " + cmd + '>>  gui_run_command.csh_temp')
#    cmd ="cd $ward"
#    os.system("echo " + cmd + '>>  gui_run_command.csh_temp')
#    cmd ="source $LNC_FCT_SCRIPTS/get_specs.csh"
    cmd = "$GFC_FCT_SCRIPTS/spec_csv2xml.py --fct_run --populate" 
    os.system("echo " + cmd + '>>  gui_run_command.csh_temp')
    os.system("echo \#step update_spec.log >> gui_run_command.csh_temp" )
    os.system('mv gui_run_command.csh_temp gui_run_command.csh')
    button5.configure(bg="yellow")
    while os.path.exists("./gui_run_command.csh"):
        time.sleep(1)
        root.update()
    button5.configure(bg="green")    
def compare_arc():
    cmd ="source $GFC_FCT_SCRIPTS/check_archive.csh"
    os.system("echo " + cmd + '>  gui_run_command.csh')
    while os.path.exists("./gui_run_command.csh"):
    	time.sleep(1)
def compare_ref():
    cmd ="source $GFC_FCT_SCRIPTS/ovr_diff_fct_cht \$REF_MODEL/"
    os.system("echo " + cmd + '>  gui_run_command.csh')
    while os.path.exists("./gui_run_command.csh"):
    	time.sleep(1)
    cmd = "sed -i 's/ref_wa/REF_MODEL/g ; s/tst_wa/ward/g ' ovr_diff/cp_commands "
    os.system(cmd)


def on_select(event):
    path = os.environ['PROJ_ARCHIVE'] + "/arc/"+ event.widget.get() + "/sta_primetime/"
    directories_in_curdir = os.listdir(path)
    directories_in_curdir = sorted(directories_in_curdir)
    selected = event.widget.get()
    input_tag['values'] = directories_in_curdir 
def view_file(file): 
    cmd = editor + " " + file + " &"
    os.system(cmd)
def choose_and_view_file(dir):
    filename = filedialog.askopenfilename(initialdir = os.path.realpath(dir) ,title = "Select a File",filetypes = (("Sdc files","*.sdc"),("all files","*.*")))
    selection = str(filename)
    cmd = editor + " " + selection + " &"
    os.system(cmd)
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
def update_frame(ind):
    frame = frames[ind]
    ind += 3
    if ind > frameCnt:
        rocket.destroy()
        return
    rocket.configure(image=frame)
    root.after(100, update_frame, ind)  
def launch_cthBuild():
    cmd = "source  $ward/runs/$block/$tech/$flow/outputs/run.all.csh \&"
    os.system("echo " + cmd + '>  gui_run_command.csh')

    global frame ,frames, ind, frameCnt, rocket
    frameCnt = 58
    frames = [PhotoImage(file='~baselibr/GFC_script/sio_assistance_tool/rocket.gif',format = 'gif -index %i' %(i)) for i in range(frameCnt)]

    rocket = Label(f2)
    rocket.grid(row=2,column = 6, rowspan = 13 , sticky="e")
    root.after(0, update_frame, 0)
    root.mainloop()
def status_cthBuild():
    cmd = "$ward/design_class/$BU_SCOPE/snps/sta_pt/sta_track_job_status.tcl -wait \&"
    os.system("echo " + cmd + ' >  gui_run_command.csh_temp')
    cmd = "source ~baselibr/GFC_script/FCT_status "
    os.system("echo " + cmd + '>>  gui_run_command.csh_temp')
    os.system("chmod 755 gui_run_command.csh_temp")
    cmd = "xterm -fn fixed -ls -sb -geometry 100x10 -e csh gui_run_command.csh_temp "
    os.system(cmd + '&')
    cmd = "rm -f gui_run_command.csh_temp"
    time.sleep(5)
    os.system(cmd)
def cthKill():
    cmd = "$ward/design_class/$BU_SCOPE/snps/sta_pt/sta_track_job_status.tcl -kill"
    os.system("echo " + cmd + ' >  gui_run_command.csh_temp')
    os.system("chmod 755 gui_run_command.csh_temp")
    cmd = "xterm -geometry 100x20 -e csh gui_run_command.csh_temp "
    os.system(cmd + '&')
    cmd = "rm -f gui_run_command.csh_temp"
    time.sleep(5)
    os.system(cmd)
def load_session():
    corner = corner_box.get()
    if (corner != "") : 
        if ( NB_CB.get() ):
             os.system('echo source ~baselibr/.aliases >  gui_run_command.csh_temp')
             cmd = 'nb_cmd_gfc_high_mem /p/hdk/pu_tu/prd/fct_alias/latest/utils/load_session_cth.csh ${ward}/runs/${block}/${tech}/sta_pt/' + corner + '/outputs/${block}.pt_session.' + corner + '/ -title `/usr/intel/bin/workweek -f FCT%IyWW%02IW_%w_' + corner + '`'
             os.system("echo " + cmd + ' >>  gui_run_command.csh_temp')
        else : 
             cmd = '/p/hdk/pu_tu/prd/fct_alias/latest/utils/load_session_cth.csh ${ward}/runs/${block}/${tech}/sta_pt/' + corner + '/outputs/${block}.pt_session.' + corner + '/ -title `/usr/intel/bin/workweek -f FCT%IyWW%02IW_%w_' + corner + '`'
             os.system("echo " + cmd + ' >  gui_run_command.csh_temp')
    
        os.system("chmod 755 gui_run_command.csh_temp")
        cmd = "xterm -geometry 100x20 -e csh gui_run_command.csh_temp "
        os.system(cmd + '&')
        cmd = "rm -f gui_run_command.csh_temp"
        time.sleep(5)
        os.system(cmd)
    else : 
        messagebox.showerror('Python Error', 'Please Choose corner')

def load_partition_session():
    inp_par = input_par.get()
    inp_tag = input_tag.get()
    corner = corner_box.get()
    if (inp_par != "") and (inp_tag != "" ) and (corner != "") :
        if ( NB_CB.get() ):
            os.system('echo source ~baselibr/.aliases >  gui_run_command.csh_temp')
            cmd = 'nb_cmd_gfc_high_mem /p/hdk/pu_tu/prd/fct_alias/latest/utils/load_session_cth.csh ' + proj_archive + '/arc/' + inp_par + '/sta_primetime/' + inp_tag + '/'  + inp_par + '.pt_session.' + corner + '/ -title ' + inp_par +'_Model_' + corner
            os.system("echo " + cmd + ' >>  gui_run_command.csh_temp')
        else: 
            cmd = '/p/hdk/pu_tu/prd/fct_alias/latest/utils/load_session_cth.csh ' + proj_archive + '/arc/' + inp_par + '/sta_primetime/' + inp_tag + '/'  + inp_par + '.pt_session.' + corner + '/ -title ' + inp_par +'_Model_' + corner  
            os.system("echo " + cmd + ' >  gui_run_command.csh_temp')
        os.system("chmod 755 gui_run_command.csh_temp")
        cmd = "xterm -geometry 100x20 -e csh gui_run_command.csh_temp "
        os.system(cmd + '&')
        cmd = "rm -f gui_run_command.csh_temp"
        time.sleep(10)
        os.system(cmd)
    else : 
        messagebox.showerror('Python Error', 'Please Choose corner/Partition/Tag')

def load_carpet ():
    inp_par = input_par.get()
    corner = corner_box.get()
   
    if (inp_par != "") and (corner != "") :
        if ( NB_CB.get() ):
            os.system('echo source ~baselibr/.aliases >  gui_run_command.csh_temp')
            os.system('echo source /nfs/site/disks/home_user/baselibr/PNC_script/sio_assistance_tool/sio_mow.tcl \; load_carpet ' + inp_par + ' > carpet_run_me_'+corner+inp_par+'.tcl ')
            cmd = 'nb_cmd_gfc_high_mem /p/hdk/pu_tu/prd/fct_alias/latest/utils/load_session_cth.csh ${ward}/runs/${block}/${tech}/sta_pt/' + corner + '/outputs/${block}.pt_session.' + corner + '/ -title `/usr/intel/bin/workweek -f FCT%IyWW%02IW_%w_' + corner + '` -file  carpet_run_me_'+corner+inp_par+'.tcl ' 
            os.system("echo " + cmd + ' >>  gui_run_command.csh_temp')
        else:
            cmd = '/p/hdk/pu_tu/prd/fct_alias/latest/utils/load_session_cth.csh ${ward}/runs/${block}/${tech}/sta_pt/' + corner + '/outputs/${block}.pt_session.' + corner + '/ -title `/usr/intel/bin/workweek -f FCT%IyWW%02IW_%w_' + corner + '` -file carpet_run_me_'+corner+inp_par+'.tcl '
            os.system("echo " + cmd + ' >  gui_run_command.csh_temp')
        
        os.system("chmod 755 gui_run_command.csh_temp")
        cmd = "xterm -geometry 100x20 -e csh gui_run_command.csh_temp "
        os.system(cmd + '&')
        cmd = "rm -f gui_run_command.csh_temp"
        time.sleep(10)
        os.system(cmd)
    else : 
        messagebox.showerror('Python Error', 'Please Choose corner/Partition')


def open_xlsx_file():
    corner = corner_box.get()
    if (corner != "") :
        found_file = 0
        for filename in os.listdir("runs/" + block +"/"  + tech + "/" + flow + "/" + corner + "/reports/csv/"):
            if re.search("indicator_table_.*.xlsx", filename):
#if os.path.exists("runs/" + block +"/"  + tech + "/" + flow + "/" + corner + '/reports/csv/indicator_table_' + corner.replace(".","_") + "_" + user + ".xlsx"):
                cmd = 'soffice runs/${block}/${tech}/sta_pt/' + corner + '/reports/csv/indicator_table_' + corner.replace(".","_") + '*.xlsx '
                os.system("echo " + cmd + '\& >  gui_run_command.csh_temp')
                os.system("chmod 755 gui_run_command.csh_temp")
                cmd = "xterm -geometry 100x20 -e csh gui_run_command.csh_temp "
                os.system(cmd + '&')
                cmd = "rm -f gui_run_command.csh_temp"
                time.sleep(5)
                os.system(cmd)
                found_file = 1
        if found_file == 0 : 
            messagebox.showerror('Python Error', 'XLSX File Does not exist') 
    else:
    	messagebox.showerror('Python Error', 'Please Choose Corner')


def external_degradation():
    inp_par = input_par.get()
    corner = corner_box.get()
    if (corner != "") :
        if not (os.path.exists("vrf_split/" + corner )):
            messagebox.showerror('Python Error', 'VRF Report does not Exist')
            return  
        if inp_par != "":
            cmd = 'source ~baselibr/LNC_script/Split_Vrf_Report.tcsh degradation_compress ' + inp_par + ' \$REF_MODEL/ \$ward ' + corner  
            os.system("echo " + cmd + ' >  gui_run_command.csh_temp')
            os.system("chmod 755 gui_run_command.csh_temp")
            cmd = "csh gui_run_command.csh_temp "
            os.system(cmd)
            cmd = "xterm -fn fixed -ls -sb -geometry 200x40 -e less Compare_models.txt &"
            os.system(cmd)
            cmd = "rm -f gui_run_command.csh_temp"
            time.sleep(5)
            os.system(cmd)
        else : 
            messagebox.showerror('Python Error', 'Please Choose Partition')
    else:
    	messagebox.showerror('Python Error', 'Please Choose Corner')


def partition_status():
    inp_par = input_par.get()
    corner = corner_box.get()
    if (corner != "") :
       if inp_par != "":
          os.system('echo source ~baselibr/.aliases >  gui_run_command.csh_temp')
          cmd = 'source  ~baselibr/PNC_script/partition_status.csh ' + inp_par + ' ${ward}/ ${ward}/ref/ ' + corner 
          os.system("echo " + cmd + ' >>  gui_run_command.csh_temp')
          os.system("chmod 755 gui_run_command.csh_temp")
          cmd = "xterm -geometry 100x20 -e csh gui_run_command.csh_temp "
          os.system(cmd)
          cmd = "rm -f gui_run_command.csh_temp"
          time.sleep(5)
          os.system(cmd)
       else : 
          messagebox.showerror('Python Error', 'Please Choose Partition')
    else:
    	messagebox.showerror('Python Error', 'Please Choose Corner')

def partition_release_mail():
    inp_par = input_par.get()
    if inp_par != "":
          os.system('echo source ~baselibr/.aliases >  gui_run_command.csh_temp')
          cmd = 'source  ~baselibr/GFC_script/partition_release_mail.csh ' + inp_par + ' ~baselibr/gfc_links/daily_gfc0a_n2_core_client_bu_postcts/ ~baselibr/gfc_links/latest_gfc0a_n2_core_client_bu_postcts/ '  
          os.system("echo " + cmd + ' >>  gui_run_command.csh_temp')
          os.system("chmod 755 gui_run_command.csh_temp")
          cmd = "xterm -geometry 100x20 -e csh gui_run_command.csh_temp "
          os.system(cmd)
          cmd = "rm -f gui_run_command.csh_temp"
          time.sleep(5)
          os.system(cmd)
    else : 
          messagebox.showerror('Python Error', 'Please Choose Partition')



def port_tns():
    inp_par = input_par.get()
    corner = corner_box.get()
    if (corner != "") :
       if inp_par != "":
          os.system('cp ~baselibr/LNC_script/port_tns_on_all_partition_parallel.tcl ./')
          cmd = "sed -i \'s/foreach par {.*/foreach par { " +inp_par+ " } { /g\'  $ward/port_tns_on_all_partition_parallel.tcl"
          os.system(cmd)
          if ( NB_CB.get() ):
              os.system('echo source ~baselibr/.aliases >  gui_run_command.csh_temp')
              cmd = 'nb_cmd_gfc_high_mem /p/hdk/pu_tu/prd/fct_alias/latest/utils/load_session_cth.csh ${ward}/runs/${block}/${tech}/sta_pt/' + corner + '/outputs/${block}.pt_session.'+ corner + '/ -title `/usr/intel/bin/workweek -f FCT%IyWW%02IW_%w_' + corner + '` -file $ward/port_tns_on_all_partition_parallel.tcl -no_exit 0'        
              os.system("echo " + cmd + ' >>  gui_run_command.csh_temp')
          else:
              cmd = '/p/hdk/pu_tu/prd/fct_alias/latest/utils/load_session_cth.csh ${ward}/runs/${block}/${tech}/sta_pt/' + corner + '/outputs/${block}.pt_session.'+ corner + '/ -title `/usr/intel/bin/workweek -f FCT%IyWW%02IW_%w_' + corner + '` -file $ward/port_tns_on_all_partition_parallel.tcl -no_exit 0'
              os.system("echo " + cmd + ' >>  gui_run_command.csh_temp')
          os.system("chmod 755 gui_run_command.csh_temp")
          cmd = "xterm -geometry 100x20 -e csh gui_run_command.csh_temp "
          os.system(cmd + '&')
          cmd = "rm -f gui_run_command.csh_temp"
          time.sleep(5)
          os.system(cmd)
       else : 
          messagebox.showerror('Python Error', 'Please Choose Partition')
    else:
    	messagebox.showerror('Python Error', 'Please Choose Corner')


def sd_08_review():
    inp_par = input_par.get()
    if inp_par != "":    
       cmd = 'source ~baselibr/LNC_script/sd_08_review.csh ' +  inp_par + ' $ward $ward'
       os.system("echo " + cmd + ' >  gui_run_command.csh_temp')
       os.system("chmod 755 gui_run_command.csh_temp")
       cmd = "xterm -geometry 100x20 -e csh gui_run_command.csh_temp "
       os.system(cmd + '&')
       cmd = "rm -f gui_run_command.csh_temp"
       time.sleep(5)
       os.system(cmd)
    else : 
       messagebox.showerror('Python Error', 'Please Choose Partition')
def spec_ci_fcl():
    os.system('$GFC_FCT_SCRIPTS/sio_spec_ci.py &')

def run_marked():
    button5_1.configure(bg="yellow")
    root.update()
    disable_buttons()
    print("run all")
    root.update()
    if run_1.get():
        source_define() 
    root.update()
    if run_2.get():
        cthPrep()
    root.update()
    if run_3.get():
        cp_bu() 
    root.update()
    if run_fishtail_var.get():
        run_fishtail() 
    root.update()
    if run_4.get():
        prepare_hip() 
    root.update()
    if run_5.get():
        sta_setup()
    root.update()
    if run_6.get():
        update_spec()
    root.update()
    if run_7.get():
        enable_buttons()
        launch_cthBuild()
    root.update()

    button5_1.configure(bg="green")
    cmd = "Subject: Done Running all marked steps at BU WA - ${ward} by $USER"
    os.system("echo " + cmd + '>  $ward/mail_to_send')	
    cmd = 'cat $ward/mail_to_send \| sendmail $USER'
    os.system("echo " + cmd + '>  gui_run_command.csh_temp')
    cmd = "rm $ward/mail_to_send"
    os.system("echo " + cmd + '>>  gui_run_command.csh_temp')
    os.system('mv gui_run_command.csh_temp gui_run_command.csh')

    while os.path.exists("./gui_run_command.csh"):
    	time.sleep(1)	
    root.update()   
    enable_buttons()

def updtcornerlist():
    global block ; global  tech ; global flow
    list_of_file = os.listdir("runs/"+ block + "/" + tech + "/" + flow + "/")
    corners = []
    for file in list_of_file:
        if "fun" in file or "spec" in file:
           corners.append(file) 
    corner_box['values'] = corners

### defining Default 
global config_file 
global editor
global default_size

default_size=10

config_file = os.path.realpath(os.path.expanduser('~/.sio_assistance_tool.defaults'))
spec_dir = "~/"
editor = "gvim"

if os.path.exists(config_file):
    for line in open(config_file, 'r'):
        if re.search("^editor", line):
            editor = line.split()[1]     
        if re.search("^spec_dir", line):
            spec_dir = (os.path.expanduser(line.split()[1]))

root = tk.Tk()
root.title('SIO assistance TOOL')


v = tk.IntVar()
ref_wa = tk.StringVar()

total_col = 4
wa = os.environ['ward']; #.split("/")[-1]  
ref_wa = os.environ['REF_MODEL']
proj_archive = os.environ['PROJ_ARCHIVE']
block = os.environ['block']
tech = os.environ['tech']
flow = os.environ['flow']
user = os.environ['USER']

i = 0
#TITLE
f1 = tk.Frame(root)
f1.grid(row=i, column=0, sticky="nsew",columnspan = total_col -2 )

tk.Label(f1, text="SIO assistance TOOL", fg = "blue",font = "Estrangelo\ Midyat 20 bold ",padx = 140).grid(row=0, column=1,columnspan = total_col-2)
tk.Label(f1, text="Authored and produced by Ibrahim, Basel", fg = "blue",font = ("Ariel 8") ).grid(row=1, column=1,columnspan = total_col-2)

canvas = Canvas(f1, width = 120, height = 50)      
img = PhotoImage(file="~baselibr/GFC_logo.png") 
canvas.create_image(0,-10, anchor=NW, image=img)
canvas.grid(column = 0, row = 0,rowspan = 2)

canvas2 = Canvas(f1, width = 80, height = 50)     
img2 = PhotoImage(file="~baselibr/intel_icon.png")
canvas2.create_image(0,5, anchor=NW, image=img2)
canvas2.grid(column = 4, row = 0,rowspan = 1)
log_img = PhotoImage(file="~baselibr/GFC_script/sio_assistance_tool/log.png").subsample(10)
i = i + 1 

Button(f1,text='BG Color',command=change_color, font=font.Font(family='Helvetica',size=10)).grid(column = 4, row = 1 )
#Button(f1,text='+',command=change_size(1), font=font.Font(family='Helvetica',size=10)).grid(column = 5, row = 1 )
#Button(f1,text='-',command=change_size(-1), font=font.Font(family='Helvetica',size=10)).grid(column = 6, row = 1 )

tk.Label(root, text="WARD:  "+wa ,font = "Ariel 10",padx = 20).grid(row=i+3, column=0,columnspan = total_col)
tk.Label(root, text="REF_MODEL:  "+ ref_wa ,font = "Ariel 10",padx = 20).grid(row=i+4, column=0,columnspan = total_col)
i=i+4
space(1)

# FRAME 1 REF MODEL 
#f1 = tk.Frame(root)
#f1.grid(row=i, column=0, sticky="nsew",columnspan = total_col)
#i=i+1

#tk.Label(f1, text="""Choose The Ref WA:""",justify = tk.LEFT,padx = 20).grid(row=0, column=0,columnspan = total_col , sticky=W)

#tk.Radiobutton(f1,text="Latest",padx = 20,variable=v,value=1,command=ref_sel).grid(row=1, column=0)
#tk.Radiobutton(f1,text="Next",padx = 20,variable=v,value=2,command=ref_sel).grid(row=1, column=1) 
#tk.Button(f1,text="Browse",padx = 20,command=browseDir).grid(row=1, column=2) 

#label = tk.Entry(f1,width=70,textvariable = ref_wa,bg = 'white', justify="right" )
#label.grid(row=3, column=0,columnspan = total_col) 

#space()

#FRAME 2 FCT STEPS
f2 = tk.Frame(root)
f2.grid(row=i, column=0, sticky="nsew",columnspan = total_col)
i=i+1

tk.Label(f2, text="""BU FCT FLOW STAGES""", fg = "blue",font = "Verdana 14 bold").grid(row=1, column=0,columnspan = total_col)

#button = tk.Button(f2, text='Set REF MODEL',width=25, command=source_define)
#button.grid(row=2, column=0,columnspan = 3) 

button1 = tk.Button(f2, text='cthPrep', width=25, command=cthPrep)
button1.grid(row=3, column=0,columnspan = 3) 
if os.path.exists("sio_assistance_tool_gui/cthPrep.log"):
     button1.configure(bg="green")

#spacer1 = tk.Label(f2, text="")
#spacer1.grid(row=4, column=0)

tk.Label(f2, text="""Override partition Data using sta_primetime tag:""",padx = 20).grid(row=5, column=0,columnspan = total_col)

tk.Label(f2, text="""Partition:""",justify = tk.LEFT,padx = 20).grid(row=6, column=0) 
data=("par_exe", "par_fmav0", "par_fmav1" , "par_fe", "par_meu", "par_mlc", "par_msid", "par_ooo_int", "par_ooo_vec", "par_pm", "par_pmh", "par_vpmm","par_tmul", "par_tmul_stub")
input_par=Combobox(f2, values=data)
input_par.grid(row=6, column=1)
input_par.bind('<<ComboboxSelected>>', on_select)
button2 = tk.Button(f2,text = "Run cp_bu ",width = 15,command = cp_bu)
button2.grid(row=6, column=2)
if os.path.exists("sio_assistance_tool_gui/cp_bu.log"):
     button2.configure(bg="green")

tk.Label(f2, text="""Tag:""",justify = tk.LEFT,padx = 20).grid(row=7, column=0)
data2=("")
input_tag=Combobox(f2, values=data2,width = 40)
input_tag.grid(row=7, column=1, columnspan = total_col-1)

# Label Creation
lbl = tk.Label(f2, text = "")

button_fishtail = tk.Button(f2, text='Fishtail', width=25, command=run_fishtail)
button_fishtail.grid(row=8, column=0,columnspan = 3) 
if os.path.exists("sio_assistance_tool_gui/fishtail.log"):
     button_fishtail.configure(bg="green")

#spacer2 = tk.Label(f2, text="")
#spacer2.grid(row=8, column=0)

button3 = tk.Button(f2, text='prepare_hip', width=25, command=prepare_hip)
button3.grid(row=9, column=1) 
if os.path.exists("sio_assistance_tool_gui/prepare_hip.log"):
     button3.configure(bg="green")



button3_1 = tk.Button(f2, text='Edit hip_tags', width=10, command=lambda: view_file("runs/${block}/${tech}/release/latest/fe_collateral/${block}.hip_tags.xml"))
button3_1.grid(row=9, column=2) 

button4 = tk.Button(f2, text='sta_setup', width=25, command=sta_setup)
button4.grid(row=10, column=1) 
if os.path.exists("sio_assistance_tool_gui/sta_setup.log"):
     button4.configure(bg="green")


button4_1 = tk.Button(f2, text='Compare Hip \nto Arc', width=10, command=lambda: compare_file(proj_archive +"/arc/${block}/fe_collateral/${FE_COLLATERAL_TAG}/${block}.hip_tags_fullT.xml","runs/${block}/${tech}/release/latest/fe_collateral/${block}.hip_tags.xml"))
button4_1.grid(row=10, column=2) 

button5 = tk.Button(f2, text='Update Spec', width=25, command=update_spec)
button5.grid(row=11, column=1) 
if os.path.exists("sio_assistance_tool_gui/update_spec.log"):
     button5.configure(bg="green")

ttk.Separator(f2, orient=VERTICAL).grid(column=4, row=2, rowspan=9, sticky='ns')
button5_1 = tk.Button(f2, text='Run Marked', command=run_marked)
button5_1.grid(row=1, column=6)
run_1= IntVar()
run_2 = IntVar()
run_3 = IntVar()
run_fishtail_var = IntVar()
run_4 = IntVar()
run_5 = IntVar()
run_6 = IntVar()
run_7 = IntVar()
on = PhotoImage(file = "~baselibr/GFC_script/sio_assistance_tool/on.png")
off = PhotoImage(file = "~baselibr/GFC_script/sio_assistance_tool/off.png")   
cb_1 = Checkbutton(f2,image = off , variable=run_1 , command = lambda: cb_1.config(image = on) if run_1.get() else cb_1.config(image = off))
#cb_1.grid(row=2, column=5)
cb_2 = Checkbutton(f2,image = off , variable=run_2 , command = lambda: cb_2.config(image = on) if run_2.get() else cb_2.config(image = off))
cb_2.grid(row=3, column=6)
tk.Button(f2,image = log_img, width=20,command=lambda: os.system('xterm -fn fixed -ls -sb -e less -S +F sio_assistance_tool_gui/cthPrep.log &')).grid(row=3, column=5)
 
cb_3 = Checkbutton(f2,image = off , variable=run_3 , command = lambda: cb_3.config(image = on) if run_3.get() else cb_3.config(image = off))
cb_3.grid(row=6, column=6)
tk.Button(f2,image = log_img, width=20,command=lambda: os.system('xterm -fn fixed -ls -sb -e less -S +F sio_assistance_tool_gui/cp_bu.log &')).grid(row=6, column=5)

cb_fishtail = Checkbutton(f2,image = off , variable=run_fishtail_var , command = lambda: cb_fishtail.config(image = on) if run_fishtail_var.get() else cb_fishtail.config(image = off))
cb_fishtail.grid(row=8, column=6)
tk.Button(f2,image = log_img, width=20,command=lambda: os.system('xterm -fn fixed -ls -sb -e less -S +F sio_assistance_tool_gui/fishtail.log &')).grid(row=8, column=5)


cb_4 = Checkbutton(f2,image = off , variable=run_4 , command = lambda: cb_4.config(image = on) if run_4.get() else cb_4.config(image = off))
cb_4.grid(row=9, column=6)
tk.Button(f2,image = log_img, width=20,command=lambda: os.system('xterm -fn fixed -ls -sb -e less -S +F sio_assistance_tool_gui/prepare_hip.log &')).grid(row=9, column=5)

cb_5 = Checkbutton(f2,image = off , variable=run_5 , command = lambda: cb_5.config(image = on) if run_5.get() else cb_5.config(image = off))
cb_5.grid(row=10, column=6)
tk.Button(f2,image = log_img, width=20,command=lambda: os.system('xterm -fn fixed -ls -sb -e less -S +F sio_assistance_tool_gui/sta_setup.log &')).grid(row=10, column=5)

cb_6 = Checkbutton(f2,image = off , variable=run_6 , command = lambda: cb_6.config(image = on) if run_6.get() else cb_6.config(image = off))
cb_6.grid(row=11, column=6)
tk.Button(f2,image = log_img, width=20,command=lambda: os.system('xterm -fn fixed -ls -sb -e less -S +F sio_assistance_tool_gui/update_spec.log &')).grid(row=11, column=5)

space()

#Frame 3 : Comapre The Run  
f3 = tk.Frame(root)
f3.grid(row=i, column=0, sticky="ew",columnspan = total_col)
i=i+1

tk.Label(f3, text="""Compare Before Starting the Run""", fg = "blue",font = "Verdana 14 bold").grid(row=1, column=0,columnspan = total_col) 

button6 = tk.Button(f3, text='Compare \n Collteral VS Archive',width=23, command=compare_arc)
button6.grid(row=2, column=0,rowspan=2,padx=15) 
button7 = tk.Button(f3, text='Compare \n WA VS REF_MODEL WA', width=22, command=compare_ref)
button7.grid(row=2, column=1,rowspan=2,padx=15) 

#Frame 3 : Launch The Run  


#f4 = tk.Frame(root)
#f4.grid(row=i, column=0, sticky="ew",columnspan = total_col)
#i=i+1

tk.Label(f3, text="""Launch The Run""", fg = "blue",font = "Verdana 14 bold").grid(row=4, column= 0,columnspan = total_col ) 
button7_1 = tk.Button(f3, text='Launch the run',width=40, command=launch_cthBuild )
button7_1.grid(row=5, column=0,columnspan=4, padx=60)    
button7_2 = tk.Button(f3, text='Status of run',width=10, command=status_cthBuild )
button7_2.grid(row=6, column=0) 
button7_3 = tk.Button(f3, text='Kill The run',width=10, command=cthKill )
button7_3.grid(row=6, column=1)    
 

ttk.Separator(f3, orient=VERTICAL).grid(column=4, row=2, rowspan=6, sticky='ns')

cb_7 = Checkbutton(f3,image = off , variable=run_7 , command = lambda: cb_7.config(image = on) if run_7.get() else cb_7.config(image = off))
cb_7.grid(row=5, column=6)
tk.Button(f3,image = log_img, width=20,command=lambda: os.system('xterm -fn fixed -ls -sb -e /nfs/site/home/baselibr/bin/most -R $ward/runs/$block/$tech/sta_pt/func.max_turbo.T_85.typical/logs/$block.func.max_turbo.T_85.typical.pt.log &')).grid(row=5, column=5)


#ttk.Separator(f3, orient=VERTICAL).grid(column=7, row=2, rowspan=6, sticky='ns')

space()

# FRAME 4: Edit compare and CI collaterals 
f4 = tk.Frame(root)
f4.grid(row=i, column=0, sticky="ew",columnspan = total_col)
tk.Label(f4, text="""Edit /Compare / CI Collaterals""", fg = "blue",font = "Verdana 14 bold").grid(row=	0, column=0,columnspan = 7) 
i=i+1
CI_1 = IntVar()
CI_2 = IntVar()
CI_3 = IntVar()
CI_4 = IntVar()
CI_5 = IntVar()

tk.Label(f4, text="""Edit File""", fg = "green",font = "Verdana 12"  ).grid(row=2, column=0) 
tk.Label(f4, text="""Compare \n To """, fg = "green",font = "Verdana 10"  ).grid(row=3, column=0,rowspan=3)
tk.Label(f4, text="""CI Tool""", fg = "green",font = "Verdana 12"  ).grid(row=6, column=0) 


##### SIO OVERRIde
button8_1 = Button(f4, text='Edit', width=5, command=lambda: view_file("runs/"+ input_par.get() + "/${tech}/release/latest/sio_ovr/"+ input_par.get() + "_sio_ovrs.tcl"))
button8_2 = Button(f4, text='REF BU', width=5, command=lambda: compare_file(ref_wa + "/runs/"+ input_par.get() + "/${tech}/release/latest/sio_ovr/"+ input_par.get() +"_sio_ovrs.tcl","runs/" + input_par.get() + "/${tech}/release/latest/sio_ovr/"+ input_par.get() +"_sio_ovrs.tcl"))
#button8_3 = Button(f4, text='Par Arc', width=5, command=lambda: compare_file(proj_archive + "/arc/${block}/sio_timing_collateral/"+ input_par.get() +"_sio_ovr/"+ input_par.get() +"_sio_ovrs.tcl","runs/" + input_par.get() + "/${tech}/release/latest/sio_ovr/"+ input_par.get() +"_sio_ovrs.tcl" ))
button8_4 = Button(f4, text='BU Arc', width=5, command=lambda: compare_file(proj_archive + "/arc/"+ input_par.get() + "/sio_ovr/GOLDEN/"+ input_par.get() + "_sio_ovrs.tcl","runs/" + input_par.get() + "/${tech}/release/latest/sio_ovr/"+ input_par.get() +"_sio_ovrs.tcl" ))

tk.Label(f4, text="""Sio_ovr""", fg = "green",font = "Verdana 11 bold"  ).grid(row=1, column=1) 

button8_1.grid(row=2, column=1) 
button8_2.grid(row=3, column=1)
#button8_3.grid(row=4, column=1) 
button8_4.grid(row=5, column=1) 
#Checkbutton(f4,variable=CI_1).grid(row=6, column=1)

##### FDR 
button9_1 = Button(f4, text='Edit', width=5, command=lambda: view_file("runs/"+ input_par.get() + "/${tech}/release/latest/timing_collateral/"+ input_par.get() + ".fdr_exceptions.tcl"))
button9_2 = Button(f4, text='REF BU', width=5, command=lambda: compare_file(ref_wa + "/runs/"+ input_par.get() + "/${tech}/release/latest/timing_collateral/" + input_par.get() + ".fdr_exceptions.tcl","runs/" + input_par.get() + "/${tech}/release/latest/timing_collateral/"+ input_par.get() + ".fdr_exceptions.tcl"))
button9_3 = Button(f4, text='Par Arc', width=5, command=lambda: compare_file(proj_archive + "/arc/" + input_par.get() + "/fe_collateral/$TIMING_TAG/" + input_par.get() + ".fdr_exceptions.tcl","runs/"+ input_par.get() + "/${tech}/release/latest/timing_collateral/" + input_par.get() + ".fdr_exceptions.tcl"))
button9_4 = Button(f4, text='BU Arc', width=5, command=lambda: compare_file(proj_archive + "/arc/"+ input_par.get() + "/sio_ovr/GOLDEN/" + input_par.get() + ".fdr_exceptions.tcl ","runs/"+ input_par.get() + "/${tech}/release/latest/timing_collateral/" + input_par.get() + ".fdr_exceptions.tcl"))
tk.Label(f4, text="""FDR""", fg = "green",font = "Verdana 11 bold"  ).grid(row=1, column=2) 
button9_1.grid(row=2, column=2) 
button9_2.grid(row=3, column=2)
button9_3.grid(row=4, column=2) 
button9_4.grid(row=5, column=2) 
#Checkbutton(f4,variable=CI_2).grid(row=6, column=2)

##### Internal Exceptions 
button10_1 = Button(f4, text='Edit', width=5, command=lambda: view_file("runs/"+ input_par.get() + "/${tech}/release/latest/sio_timing_collateral/"+ input_par.get() + "_internal_exceptions.tcl"))
button10_2 = Button(f4, text='REF BU', width=5, command=lambda: compare_file(ref_wa + "/runs/"+ input_par.get() + "/${tech}/release/latest/sio_timing_collateral/" + input_par.get() + "_internal_exceptions.tcl","runs/" + input_par.get() + "/${tech}/release/latest/sio_timing_collateral/"+ input_par.get() + "_internal_exceptions.tcl"))
button10_3 = Button(f4, text='Archive', width=5, command=lambda: compare_file(proj_archive + "/arc/" + input_par.get() + "/sio_timing_collateral/GOLDEN/" + input_par.get() + "_internal_exceptions.tcl","runs/"+ input_par.get() + "/${tech}/release/latest/sio_timing_collateral/" + input_par.get() + "_internal_exceptions.tcl" ))
tk.Label(f4, text="""Inter. Exp""", fg = "green",font = "Verdana 11 bold"  ).grid(row=1, column=3) 
button10_1.grid(row=2, column=3) 
button10_2.grid(row=3, column=3)
button10_3.grid(row=4, column=3) 
#Checkbutton(f4,variable=CI_3).grid(row=6, column=3)

##### Global mbist 
tk.Label(f4, text="""Mbist TCL""", fg = "green",font = "Verdana 11 bold"  ).grid(row=1, column=4) 
button11_1 =Button(f4, text='Edit', width=5, command=lambda: view_file("runs/"+ input_par.get() + "/${tech}/release/latest/timing_collateral/"+ input_par.get() + "_mbist_exceptions.tcl"))
button11_2 =Button(f4, text='REF BU', width=5, command=lambda: compare_file(ref_wa + "/runs/"+ input_par.get() + "/${tech}/release/latest/timing_collateral/"+ input_par.get() + "_mbist_exceptions.tcl","runs/"+ input_par.get() + "/${tech}/release/latest/timing_collateral/"+ input_par.get() + "_mbist_exceptions.tcl"))
button11_3 =Button(f4, text='Par Arc', width=5, command=lambda: compare_file(proj_archive + "/arc/" + input_par.get() + "/timing_collateral/$TIMING_TAG/" + input_par.get() + "_mbist_exceptions.tcl", "runs/"+ input_par.get() + "/${tech}/release/latest/timing_collateral/"+ input_par.get() + "_mbist_exceptions.tcl" ))
button11_4 =Button(f4, text='BU Arc', width=5, command=lambda: compare_file(proj_archive + "/arc/"+ input_par.get() + "/sio_ovr/GOLDEN/" + input_par.get() + "_mbist_exceptions.tcl", "runs/"+ input_par.get() + "/${tech}/release/latest/timing_collateral/"+ input_par.get() + "_mbist_exceptions.tcl" ))
button11_1.grid(row=2, column=4) 
button11_2.grid(row=3, column=4)
button11_3.grid(row=4, column=4) 
button11_4.grid(row=5, column=4) 
#Checkbutton(f4,variable=CI_4).grid(row=6, column=4)


##### array mcp 
tk.Label(f4, text="""Array MCP""", fg = "green",font = "Verdana 11 bold"  ).grid(row=1, column=5) 
button12_1 =Button(f4, text='Edit', width=5, command=lambda: view_file("runs/"+ input_par.get() + "/${tech}/release/latest/timing_collateral/"+ input_par.get() + ".arrays_mcp.tcl"))
button12_2 =Button(f4, text='REF BU', width=5, command=lambda: compare_file(ref_wa + "/runs/"+ input_par.get() + "/${tech}/release/latest/timing_collateral/"+ input_par.get() + ".arrays_mcp.tcl","runs/"+ input_par.get() + "/${tech}/release/latest/timing_collateral/"+ input_par.get() + ".arrays_mcp.tcl"))
button12_3 =Button(f4, text='Par Arc', width=5, command=lambda: compare_file(proj_archive + "/arc/" + input_par.get() + "/timing_collateral/$TIMING_TAG/" + input_par.get() + ".arrays_mcp.tcl","runs/"+ input_par.get() + "/${tech}/release/latest/timing_collateral/"+ input_par.get() + ".arrays_mcp.tcl"))
button12_4 =Button(f4, text='BU Arc', width=5, command=lambda: compare_file(proj_archive + "/arc/"+ input_par.get() + "/sio_ovr/GOLDEN/" + input_par.get() + ".arrays_mcp.tcl","runs/"+ input_par.get() + "/${tech}/release/latest/timing_collateral/"+ input_par.get() + ".arrays_mcp.tcl"))
button12_1.grid(row=2, column=5) 
button12_2.grid(row=3, column=5)
button12_3.grid(row=4, column=5)
button12_4.grid(row=5, column=5) 
    
#Checkbutton(f4,variable=CI_5).grid(row=6, column=5)


#### Mbist Sdc 
tk.Label(f4, text="""Mbist SDC""", fg = "green",font = "Verdana 11 bold"  ).grid(row=1, column=6) 
button11_1 =Button(f4, text='Edit', width=5, command=lambda: choose_and_view_file("runs/"+ input_par.get() + "/" + tech + "/release/latest/timing_collateral/"))
button11_2 =Button(f4, text='REF BU', width=5, command=lambda: compare_files_of_type(ref_wa + "runs/"+ input_par.get() + "/" + tech + "/release/latest/timing_collateral/","runs/"+ input_par.get() + "/" + tech + "/release/latest/timing_collateral/",".sdc"))
button11_3 =Button(f4, text='Par Arc', width=5, command=lambda: compare_files_of_type(proj_archive + "/arc/" + input_par.get() + "/timing_collateral/" + os.environ['TIMING_TAG'] , "runs/" + input_par.get() + "/" + tech + "/release/latest/timing_collateral/",".sdc")) 
button11_4 =Button(f4, text='BU Arc', width=5, command=lambda: compare_files_of_type(proj_archive + "/arc/"+ input_par.get() + "/sio_ovr/GOLDEN/" , "runs/" + input_par.get() + "/" + tech + "/release/latest/timing_collateral/",".sdc")) 

button11_1.grid(row=2, column=6) 
button11_2.grid(row=3, column=6)
button11_3.grid(row=4, column=6)
button11_4.grid(row=5, column=6)
#Checkbutton(f4,variable=CI_4).grid(row=6, column=6)





button7_9 = tk.Button(f4, text='spec ci tool',width=40, command=spec_ci_fcl )
button7_9.grid(row=6, column=1,columnspan = 6)

ttk.Separator(f4, orient=VERTICAL).grid(column=7, row=1, rowspan=5, sticky='ns')




tk.Label(f4, text="corner:").grid(row=0, column= 7) 
corner_box = Combobox(f4,text="Corner", width = 25, postcommand = updtcornerlist)
corner_box.grid(row=0, column=8,columnspan = 2)

tk.Label(f4, text="Post FCT", fg = "blue",font = "Verdana 14 bold").grid(row=1, column= 8,columnspan =2 ) 
NB_CB = IntVar()
Checkbutton(f4,variable=NB_CB,text="Netbatch").grid(row=2, column=8,columnspan = 2 )

button7_4 = tk.Button(f4, text='Load FC Session',width=12, command=load_session )
button7_4.grid(row=3, column=8)
button7_5 = tk.Button(f4, text='Load Par Session',width=12, command=load_partition_session )
button7_5.grid(row=3, column=9)
button7_6 = tk.Button(f4, text='Open xlsx',width=12, command=open_xlsx_file )
button7_6.grid(row=4, column=8)
button7_7 = tk.Button(f4, text='vrf degradation',width=12, command=external_degradation )
button7_7.grid(row=4, column=9)
button7_9 = tk.Button(f4, text='partition status',width=12, command=partition_status )
button7_9.grid(row=5, column=8)
button7_11 = tk.Button(f4, text='load carpet' , width = 24 , command=load_carpet )
#button7_11.grid(row=6,column=8,columnspan = 2 )
button7_12 = tk.Button(f4, text='par release mail' , width = 12 , command=partition_release_mail )
button7_12.grid(row=5,column=9)

button7_8 = tk.Button(f4, text='Port tns',width=12, command=port_tns )
#button7_8.grid(row=5, column=8)
button7_8 = tk.Button(f4, text='sd_08_review',width=12, command=sd_08_review )
#button7_8.grid(row=5, column=9)
button7_10 = tk.Button(f4, text='FCT Server Tool',width=24, command=lambda:[os.system("$PNC_FCT_SCRIPTS/fct_server_tool.py &")] )
button7_10.grid(row=7, column=8,columnspan = 2)


my_button = Button(root, text='Exit',width=25, command = lambda:[os.system('touch gui_done.log'),exit] )
my_button.bind('<Destroy>', good_bye )

root.resizable(0, 0)    
root.mainloop()
