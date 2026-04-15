from tkinter import *
#!/usr/intel/bin/python3.7.4

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

def change_color():
    colors = askcolor(title="Tkinter Color Chooser")
    f1.configure(bg=colors[1])
    f2.configure(bg=colors[1])
    f3.configure(bg=colors[1])
# f4.configure(bg=colors[1])
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
def cthPrep ():
    os.system("echo cthPrep > gui_run_command.csh_temp" );
    os.system("echo \#step cthPrep.log >> gui_run_command.csh_temp")
    os.system('mv gui_run_command.csh_temp gui_run_command.csh')
    button1.configure(bg="yellow")
    while os.path.exists("./gui_run_command.csh"):
    	time.sleep(1)
    	root.update()
    button1.configure(bg="green")
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
    cmd = "/nfs/site/disks/home_user/baselibr/GFC_script/spec_csv2xml.py --fct_run --populate" 
    os.system("echo " + cmd + '>>  gui_run_command.csh_temp')
    os.system("echo \#step update_spec.log >> gui_run_command.csh_temp" )
    os.system('mv gui_run_command.csh_temp gui_run_command.csh')
    button5.configure(bg="yellow")
    while os.path.exists("./gui_run_command.csh"):
        time.sleep(1)
        root.update()
    button5.configure(bg="green")    
def view_file(file): 
    cmd = editor + " " + file + " &"
    os.system(cmd)
def compare_ref():
    cmd ="source $PNC_FCT_SCRIPTS/ovr_diff_fct_cht \$REF_MODEL/"
    os.system("echo " + cmd + '>  gui_run_command.csh')
    while os.path.exists("./gui_run_command.csh"):
    	time.sleep(1)
    cmd = "sed -i 's/ref_wa/REF_MODEL/g ; s/tst_wa/ward/g ' ovr_diff/cp_commands "
    os.system(cmd)
def launch_cthBuild():
    cmd = "source  $ward/runs/$block/$tech/$flow/outputs/run.all.csh \&"
    os.system("echo " + cmd + '>  gui_run_command.csh')

def status_cthBuild():
    cmd = "$ward/design_class/$BU_SCOPE/snps/sta_pt/sta_track_job_status.tcl -wait \&"
    os.system("echo " + cmd + ' >  gui_run_command.csh_temp')
    cmd = "source ~baselibr/PNC_script/FCT_status  "
    os.system("echo " + cmd + '>>  gui_run_command.csh_temp')
#    cmd = "source ~baselibr/PNC_script/debit_status "
#    os.system("echo " + cmd + '>>  gui_run_command.csh_temp')
    os.system("chmod 755 gui_run_command.csh_temp")
    cmd = "xterm -fn fixed -ls -sb -geometry 100x10 -e csh gui_run_command.csh_temp "
    os.system(cmd + '&')
    cmd = "rm -f gui_run_command.csh_temp"
    time.sleep(5)
    os.system(cmd)
def status_debit():
    cmd = "source ~baselibr/PNC_script/debit_status "
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
             cmd = 'nb_cmd_high_mem /p/hdk/pu_tu/prd/fct_alias/latest/utils/load_session_cth.csh ${ward}/runs/${block}/${tech}/sta_pt/' + corner + '/outputs/${block}.pt_session.' + corner + '/ -title `/usr/intel/bin/workweek -f FCT%IyWW%02IW_%w_' + corner + '`'
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
def open_xlsx_file():
    corner = corner_box.get()
    if (corner != "") :
        if os.path.exists("runs/" + block +"/"  + tech + "/" + flow + "/" + corner + '/reports/csv/fct_status.xlsx'):
            cmd = 'soffice runs/${block}/${tech}/sta_pt/' + corner + '/reports/csv/fct_status.xlsx '
            os.system("echo " + cmd + '\& >  gui_run_command.csh_temp')
            os.system("chmod 755 gui_run_command.csh_temp")
            cmd = "xterm -geometry 100x20 -e csh gui_run_command.csh_temp "
            os.system(cmd + '&')
            cmd = "rm -f gui_run_command.csh_temp"
            time.sleep(5)
            os.system(cmd)
        else:
            messagebox.showerror('Python Error', 'XLSX File Does not exist') 
    else:
    	messagebox.showerror('Python Error', 'Please Choose Corner')
def draw_pie():
    corner = corner_box.get()
    if (corner != "") :
        if os.path.exists("runs/" + block +"/"  + tech + "/" + flow + "/" + corner + '/reports/csv/fct_status.xlsx'):
            cmd = 'cat runs/${block}/${tech}/sta_pt/'+corner + '/reports/csv/missing_spec.csv | awk -F "," '"'"'{print $1,$8}'"'"' > pie.data'
            os.system(cmd)
            cmd = "gnuplot -p -e 'load "+'"'+"< ~baselibr/PNC_script/draw_pie_graph.sh pie.data"+'"'+"'"
            os.system(cmd)  
            cmd = 'cat runs/${block}/${tech}/sta_pt/'+corner + '/reports/csv/unbalanced_spec.csv | awk -F "," '"'"'{if(NR==1) {print "par unbalance-20"} else {print $1,$5}}'"'"' > pie.data'
            os.system(cmd)
            cmd = "gnuplot -p -e 'load "+'"'+"< ~baselibr/PNC_script/draw_pie_graph.sh pie.data"+'"'+"'"
            os.system(cmd)

        else:
            messagebox.showerror('Python Error', 'XLSX File Does not exist') 
    else:
    	messagebox.showerror('Python Error', 'Please Choose Corner')
def remove_model_indicators():
    cmd = 'source ~baselibr/STOD/pnc_td_indicator_archive/scripts/remove_model.csh'
    os.system("echo " + cmd + '>>  gui_run_command.csh_temp')
    os.system("chmod 755 gui_run_command.csh_temp")
    cmd = "xterm -fn fixed -ls -sb -geometry 100x10 -e csh gui_run_command.csh_temp "
    os.system(cmd + '&')
    cmd = "rm -f gui_run_command.csh_temp"
    time.sleep(5)
    os.system(cmd)

def released_model_indicators():
    cmd = 'source ~baselibr/STOD/pnc_td_indicator_archive/scripts/save_indicators.csh $ward'
    os.system("echo " + cmd + '>>  gui_run_command.csh_temp')
    os.system("chmod 755 gui_run_command.csh_temp")
    cmd = "xterm -fn fixed -ls -sb -geometry 100x10 -e csh gui_run_command.csh_temp "
    os.system(cmd + '&')
    cmd = "rm -f gui_run_command.csh_temp"
    time.sleep(5)
    os.system(cmd)
def update_latest_link():
    cmd = 'source /nfs/site/disks/pnc_fct_bu/work_area/fct_scripts/PNC/pnc_links.csh $ward'
    os.system("echo " + cmd + '>>  gui_run_command.csh_temp')
    os.system("chmod 755 gui_run_command.csh_temp")
    cmd = "xterm -fn fixed -ls -sb -geometry 100x10 -e csh gui_run_command.csh_temp "
    os.system(cmd + '&')
    cmd = "rm -f gui_run_command.csh_temp"
    time.sleep(5)
    os.system(cmd)
def send_status_html():
    cmd = 'source /nfs/site/disks/baselibr_wa/pnc_td_indicator_archive/scripts/draw_indicators.csh save'
    os.system("echo " + cmd + '>>  gui_run_command.csh_temp')
    os.system("chmod 755 gui_run_command.csh_temp")
    cmd = "xterm -fn fixed -ls -sb -geometry 100x10 -e csh gui_run_command.csh_temp "
    os.system(cmd + '&')
    cmd = "rm -f gui_run_command.csh_temp"
    time.sleep(5)
    os.system(cmd)
    
def run_marked():
    button5_1.configure(bg="yellow")
    root.update()
#    disable_buttons()
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
# enable_buttons()
        launch_cthBuild()
    root.update()

    button5_1.configure(bg="green")
    cmd = "Subject: Done Running all marked steps at FCL WA - ${ward} by $USER"
    os.system("echo " + cmd + '>  $ward/mail_to_send')	
    cmd = 'cat $ward/mail_to_send \| sendmail $USER'
    os.system("echo " + cmd + '>  gui_run_command.csh_temp')
    cmd = "rm $ward/mail_to_send"
    os.system("echo " + cmd + '>>  gui_run_command.csh_temp')
    os.system('mv gui_run_command.csh_temp gui_run_command.csh')

    while os.path.exists("./gui_run_command.csh"):
    	time.sleep(1)	
    root.update()   
#    enable_buttons()
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

default_size=9

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
root.title('FCT TD')


v = tk.IntVar()
ref_wa = tk.StringVar()

total_col = 10
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
f1.grid(row=i, column=0, sticky="nsew",columnspan = total_col  )

tk.Label(f1, text="FCT TD", fg = "blue",font = "Estrangelo\ Midyat 20 bold ",padx = 140).grid(row=0, column=1,columnspan = total_col-2)
tk.Label(f1, text="Authored and produced by Ibrahim, Basel", fg = "blue",font = ("Ariel 8") ).grid(row=1, column=1,columnspan = total_col-2)

canvas = Canvas(f1, width = 120, height = 50)      
img = PhotoImage(file="~baselibr/GFC_logo.png") 
canvas.create_image(0,-10, anchor=NW, image=img)
canvas.grid(column = 0, row = 0,rowspan = 1)

canvas2 = Canvas(f1, width = 80, height = 50)     
img2 = PhotoImage(file="~baselibr/intel_icon.png")
canvas2.create_image(0,5, anchor=NW, image=img2)
canvas2.grid(column = total_col, row = 0,rowspan = 1)
log_img = PhotoImage(file="~baselibr/PNC_script/sio_assistance_tool/log.png").subsample(10)
i = i + 1 

Button(f1,text='BG Color',command=change_color, font=font.Font(family='Helvetica',size=10)).grid(column = total_col, row = 1 )
#Button(f1,text='+',command=change_size(1), font=font.Font(family='Helvetica',size=10)).grid(column = 0, row = 1 )
#Button(f1,text='-',command=change_size(-1), font=font.Font(family='Helvetica',size=10)).grid(column = 0, row = 1 )


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

tk.Label(f2, text="""BU FCT FLOW STAGES""", fg = "blue",font = "Verdana 14 bold").grid(row=1, column=0,columnspan = total_col-5)

#button = tk.Button(f2, text='Set REF MODEL',width=25, command=source_define)
#button.grid(row=2, column=0,columnspan = 3) 

button1 = tk.Button(f2, text='cthPrep', width=20, command=cthPrep)
button1.grid(row=3, column=1) 
if os.path.exists("td_fct_flow_gui/cthPrep.log"):
     button1.configure(bg="green")

# Label Creation
lbl = tk.Label(f2, text = "")

button3 = tk.Button(f2, text='prepare_hip', width=20, command=prepare_hip)
button3.grid(row=9, column=1) 
if os.path.exists("td_fct_flow_gui/prepare_hip.log"):
     button3.configure(bg="green")

button3_1 = tk.Button(f2, text='Edit hip_tags', width=10, command=lambda: view_file("runs/${block}/${tech}/release/latest/fe_collateral/${block}.hip_tags.xml"))
button3_1.grid(row=9, column=2) 

button4 = tk.Button(f2, text='sta_setup', width=20, command=sta_setup)
button4.grid(row=10, column=1) 
if os.path.exists("td_fct_flow_gui/sta_setup.log"):
     button4.configure(bg="green")


button4_1 = tk.Button(f2, text='Compare Hip', width=10, command=lambda: compare_file(proj_archive +"/arc/${block}/fe_collateral/${FE_COLLATERAL_TAG}/${block}.hip_tags_fullT.xml","runs/${block}/${tech}/release/latest/fe_collateral/${block}.hip_tags.xml"))
button4_1.grid(row=10, column=2) 

button5 = tk.Button(f2, text='Update Spec', width=20, command=update_spec)
button5.grid(row=11, column=1) 
if os.path.exists("td_fct_flow_gui/update_spec.log"):
     button5.configure(bg="green")

ttk.Separator(f2, orient=VERTICAL).grid(column=4, row=2, rowspan=9, sticky='ns')
button5_1 = tk.Button(f2, text='Run Marked', command=run_marked)
button5_1.grid(row=1, column=6)
run_1= IntVar()
run_2 = IntVar()
run_3 = IntVar()
run_4 = IntVar()
run_5 = IntVar()
run_6 = IntVar()
run_7 = IntVar()
on = PhotoImage(file = "~baselibr/PNC_script/sio_assistance_tool/on.png")
off = PhotoImage(file = "~baselibr/PNC_script/sio_assistance_tool/off.png")   
cb_1 = Checkbutton(f2,image = off , variable=run_1 , command = lambda: cb_1.config(image = on) if run_1.get() else cb_1.config(image = off))
#cb_1.grid(row=2, column=5)
cb_2 = Checkbutton(f2,image = off , variable=run_2 , command = lambda: cb_2.config(image = on) if run_2.get() else cb_2.config(image = off))
cb_2.grid(row=3, column=6)
tk.Button(f2,image = log_img, width=20,command=lambda: os.system('xterm -fn fixed -ls -sb -e less -S +F td_fct_flow_gui/cthPrep.log &')).grid(row=3, column=5)
 
cb_3 = Checkbutton(f2,image = off , variable=run_3 , command = lambda: cb_3.config(image = on) if run_3.get() else cb_3.config(image = off))
#cb_3.grid(row=6, column=6)
#tk.Button(f2,image = log_img, width=20,command=lambda: os.system('xterm -fn fixed -ls -sb -e less -S +F td_fct_flow_gui/cp_bu.log &')).grid(row=6, column=5)

cb_4 = Checkbutton(f2,image = off , variable=run_4 , command = lambda: cb_4.config(image = on) if run_4.get() else cb_4.config(image = off))
cb_4.grid(row=9, column=6)
tk.Button(f2,image = log_img, width=20,command=lambda: os.system('xterm -fn fixed -ls -sb -e less -S +F td_fct_flow_gui/prepare_hip.log &')).grid(row=9, column=5)

cb_5 = Checkbutton(f2,image = off , variable=run_5 , command = lambda: cb_5.config(image = on) if run_5.get() else cb_5.config(image = off))
cb_5.grid(row=10, column=6)
tk.Button(f2,image = log_img, width=20,command=lambda: os.system('xterm -fn fixed -ls -sb -e less -S +F td_fct_flow_gui/sta_setup.log &')).grid(row=10, column=5)

cb_6 = Checkbutton(f2,image = off , variable=run_6 , command = lambda: cb_6.config(image = on) if run_6.get() else cb_6.config(image = off))
cb_6.grid(row=11, column=6)
tk.Button(f2,image = log_img, width=20,command=lambda: os.system('xterm -fn fixed -ls -sb -e less -S +F td_fct_flow_gui/update_spec.log &')).grid(row=11, column=5)

ttk.Separator(f2, orient=VERTICAL).grid(column=7, row=2, rowspan=9, sticky='ns')


tk.Label(f2, text="Post FCT", fg = "blue",font = "Verdana 14 bold").grid(row=1, column= 8 ) 
NB_CB = IntVar()
Checkbutton(f2,variable=NB_CB,text="Netbatch").grid(row=1, column=9)

tk.Label(f2, text="corner:").grid(row=3, column= 8) 
corner_box = Combobox(f2,text="Corner", width = 15, postcommand = updtcornerlist)
corner_box.grid(row=3, column=9)



button7_5 = tk.Button(f2, text='Load FC Session',width=12, command=load_session )
button7_5.grid(row=9, column=8)
button7_6 = tk.Button(f2, text='Open xlsx',width=12, command=open_xlsx_file )
button7_6.grid(row=9, column=9)
tk.Button(f2,text='View log', width=12,command=lambda: os.system('xterm -fn fixed -ls -sb -e less $ward/runs/$block/$tech/sta_pt/'+ corner_box.get() + '/logs/$block.' + corner_box.get() +'.pt.log &')).grid(row=10, column=8)
button7_7 = tk.Button(f2, text='Draw pie graph',width=12, command=draw_pie )
#button7_7.grid(row=10, column=9)

button7_8 = tk.Button(f2, text='remove indicators',width=12, command=remove_model_indicators )
#button7_8.grid(row=11, column=8)
button7_9 = tk.Button(f2, text='released indicators',width=12, command=released_model_indicators)
#button7_9.grid(row=11, column=9)
button7_10 = tk.Button(f2, text='update links',width=12, command=update_latest_link)
#button7_10.grid(row=12, column=8)
button7_10 = tk.Button(f2, text='status mail',width=12, command=send_status_html)
#button7_10.grid(row=12, column=9)




space()

f3 = tk.Frame(root)
f3.grid(row=i, column=0, sticky="ew",columnspan = total_col)
i=i+1

tk.Label(f3, text="""Compare Before Starting the Run""", fg = "blue",font = "Verdana 14 bold").grid(row=1, column=1,columnspan = 3) 
button7 = tk.Button(f3, text='Compare VS REF', width=20, command=compare_ref)
button7.grid(row=2, column=1,columnspan=3) 

tk.Label(f3, text="""Launch The Run""", fg = "blue",font = "Verdana 14 bold").grid(row=4, column= 1,columnspan = 3) 
button7_1 = tk.Button(f3, text='Launch the run',width=20, command=launch_cthBuild )
button7_1.grid(row=5, column=1,columnspan=3, padx=0)    
button7_2 = tk.Button(f3, text='Status of run',width=10, command=status_cthBuild )
button7_2.grid(row=6, column=1) 

button7_3 = tk.Button(f3, text='Status Debit',width=10, command=status_debit )
button7_3.grid(row=6, column=2)    
button7_4 = tk.Button(f3, text='Kill The run',width=10, command=cthKill )
button7_4.grid(row=6, column=3)    


ttk.Separator(f3, orient=VERTICAL).grid(column=5, row=2, rowspan=6, sticky='ns',padx=35)

cb_7 = Checkbutton(f3,image = off , variable=run_7 , command = lambda: cb_7.config(image = on) if run_7.get() else cb_7.config(image = off))
cb_7.grid(row=5, column=4)


my_button = Button(root, text='Exit',width=25, command = lambda:[os.system('touch gui_done.log'),exit] )
my_button.bind('<Destroy>', good_bye )


root.mainloop() 
