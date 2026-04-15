#!/usr/bin/env python3.7.4

import csv
import os
import re
import argparse
import sys
from os import environ

def check_parentheses(expression):    
    open_tup = tuple('({[')
    close_tup = tuple(')}]')
    map = dict(zip(open_tup, close_tup))
    queue = []
 
    for i in re.sub('[^\(\{\[\}\]\)]', '', expression):
        if i in open_tup:
            queue.append(map[i])
        elif i in close_tup:
            if not queue or i != queue.pop():
                return 0
    if not queue:
        return 1
    else:
        return 0

def print_to_file(active,pin,spec,par,clk,edge,comment):
    global fp
    global spec_array
    global cor 
    global default_corner
    if int(active) == 1:
       if edge == "r":
            xml_edge = "Rise"
       else:
            xml_edge = "Fall"
       full_name = par +'/'+pin
       if cor == default_corner:
            spec_array[full_name] = str(spec) +',' + str(clk)  + ',' + str(edge)
       fp.write(f'<net dir="" disableInBU="0" applySpecOnBU="1" lockDelay="0" lbForward="0" par="{par}" pin="{pin}" related_clk_latency="" related_clk_port="" rollup_mode="" spec="{spec}" spec_clock="{clk}" spec_edge="{xml_edge}" user_add="{user}" />\n')

def print_to_ft_file(active,par,in_pin,out_pin,ft_spec,comment):
    global fp
    if int(active) == 1:
       fp.write(f'<net applySpecOnBU="1" partition="{par}" input_pin="{in_pin}" output_pin="{out_pin}" user_add="{user}" max_delay="{ft_spec}" />\n')

def handel_ft_range_pin(pin_collection,pin):
    if "{" in str(pin):
        start = pin.find('{') + 1
        end =   pin.find('}',start)
        pin_range = pin[start:end]
        for subrange in pin_range.split(","):
            if ":" in str(subrange):
                start_ind = int(subrange.split(':')[0])
                end_ind = int(subrange.split(':')[1])
                if start_ind > end_ind :
                    print("range should be LSB:MSB , please replave it from "+ pin_range + " to "+str(end_ind)+":"+str(start_ind)+" at pin "+str(pin))
                    exit(1)

                for n in range(start_ind ,end_ind+1 ):
                    pin_new = pin[0:start-1]+str(n)+pin[end+1:]
                    if "{" in pin_new:
                        handel_ft_range_pin(pin_collection,pin_new)
                    else:
                        pin_collection.append(pin_new)
            else:
                pin_new = pin[0:start-1]+subrange+pin[end+1:]
                if "{" in pin_new:
                    handel_ft_range_pin(pin_collection,pin_new)
                else:
                    pin_collection.append(pin_new)
    else:
        pin_collection.append(pin)
    return pin_collection

def handel_ft_range(line):
    global fp
    active,par,in_pin,out_pin,ft_spec,comment = line[0:6]
    in_pins=handel_ft_range_pin([],in_pin)
    out_pins=handel_ft_range_pin([],out_pin)
    if len(in_pins) == len(out_pins):
        for n in range(0,len(in_pins)):
#print(in_pins[n] , out_pins[n])
            print_to_ft_file(active,par,in_pins[n],out_pins[n],ft_spec,comment)
    else:
        if len(in_pins) == 1:
            for pin in out_pins:
#print(in_pins[0] , pin)
                print_to_ft_file(active,par,in_pins[0],pin,ft_spec,comment)
        if len(out_pins) == 1:
            for pin in in_pins:
#  print(pin, out_pins[0])
                print_to_ft_file(active,par,pin,out_pins[0],ft_spec,comment)
        if len(in_pins) != 1 and len(out_pins) != 1:
            print("the input "+in_pin+"and the output"+out_pin+" is not of the same size")
            exit(1)



def handel_range(line):
    global fp
    active,pin,spec,par,clk,edge,comment = line[0:7]
    start = pin.find('{') + 1
    end = pin.find('}',start)
    pin_range = pin[start:end]
    for subrange in pin_range.split(","):
         if ":" in str(subrange):
             start_ind = int(subrange.split(':')[0])
             end_ind = int(subrange.split(':')[1])
             if start_ind > end_ind :
                print("range should be LSB:MSB , please replave it from "+ pin_range + " to "+str(end_ind)+":"+str(start_ind)+" at pin "+pin)
                exit(1)
             for n in range(start_ind ,end_ind+1 ):
                 pin_new = pin[0:start-1]+str(n)+pin[end+1:]
                 if "{" in pin_new:
#spec_on_pin[pin_new]=spec
                    handel_range([active,pin_new,spec,par,clk,edge,comment])
                 else:
                    if int(active) == 1:
                        spec_on_pin[pin_new]=spec
                        if pin_new  in second_def.keys():
                            second_def[pin_new]= second_def[pin_new] + 1  
                        else:
                            second_def[pin_new]= 1		    
                    print_to_file(active,pin_new,spec,par,clk,edge,comment+" Splited by handel_range")
         else:
             pin_new = pin[0:start-1]+subrange+pin[end+1:]
             if "{" in pin_new:
                 handel_range([active,pin_new,spec,par,clk,edge,comment])
             else:
                 if int(active) == 1:
                    spec_on_pin[pin_new]=spec
                    if pin_new  in second_def.keys():
                        second_def[pin_new]= second_def[pin_new] + 1  
                    else:
                        second_def[pin_new]= 1
                 print_to_file(active,pin_new,spec,par,clk,edge,comment+" Splited by handel_range")

def handle_star(line):
    global fp
    global partiton_pins
    active,pin,spec,par,clk,edge,comment = line[0:7]
    new_pin_name = re.sub('\]','\\]',re.sub('\[','\\[',re.sub('\*','.*', pin )))
    if not( re.search(str(new_pin_name), partiton_pins)):
        print("pattern " + new_pin_name + " does not exist")
    for pin_new in re.findall(new_pin_name , partiton_pins):
        fp.write(f'spec_xml -par {par} -user {user} -val {spec} -edge {edge} -clock {clk} -pin {pin_new} -app_bu; #{comment} Splited by handel_star\n')

def get_all_pins(partition):
    cmd = "cat ~baselibr/gfc_links/latest_gfc0a_n2p_htall_conf4_core_client_fcl/runs/" + partition + "/n2p_htall_conf4/release/latest/td_collateral/standard/" + partition + "_td.v | awk '/module " + partition + "/,/endmodule/'  | grep -e "+'"'+"^[[:space:]]*input[[:space:]]"+'"'+" -e  "+'"'+"^[[:space:]]*output[[:space:]]"+'"'+" |  sed 's/\;/ ;/g' |  sed 's/\\\//g' | awk '{if ( NF == 3) {print $2} ; if ( NF == 4) { sub(/\[/,X,$2) ;  sub(/\]/,X,$2)  ; split($2,a,"+'"'+":"+'"'+") ; for (i = a[2]; i <= a[1]; i++) {print $3"+'"'+"["+'"'+"i"+'"'+"]"+'"'+"}   }}' > all_pins "   
    os.system(cmd)
    with open("all_pins", 'r') as file:
        data = file.read()
        file.close()
    os.remove("all_pins")
    return data

def get_icore_pins():
    cmd = "cat "+ ward + "runs/icore/$tech/release/latest/self_collateral/standard/icore_td.v | awk '/module icore /,/endmodule/'  | grep -e "+'"'+"^[[:space:]]*input[[:space:]]"+'"'+" -e  "+'"'+"^[[:space:]]*output[[:space:]]"+'"'+" |  sed 's/\;/ ;/g' |  sed 's/\\\//g' | awk '{if ( NF == 3) {print $2} ; if ( NF == 4) { sub(/\[/,X,$2) ;  sub(/\]/,X,$2)  ; split($2,a,"+'"'+":"+'"'+") ; for (i = a[2]; i <= a[1]; i++) {print $3"+'"'+"["+'"'+"i"+'"'+"]"+'"'+"}   }}' > all_pins "   
    os.system(cmd)
    with open("all_pins", 'r') as file:
        data = file.read()
        file.close()
    os.remove("all_pins")
    return data

def get_abutted_pin():
    icore_abutted_pin = {}
    cmd = "cat ~baselibr/gfc_links/latest_gfc0a_n2p_htall_conf4_core_client_fcl/runs/core_client/n2p_htall_conf4_/sta_pt/func.max_high.T_85.typical/reports/core_client.func.max_high.T_85.typical_abutted_pins.rpt | grep -v 'Dangling pin' | awk -F ',' '($1 ~ /icore0\/par_/ && $2 !~ /icore0\/par_/ ) || ($1 !~ /icore0\/par_/ && $2 ~ /icore0\/par_/ ){print $0}' | sort -u | tr '/' ' ' | tr ',' ' ' | grep -v '_FEEDTHRU' > icore_abutted"
    os.system(cmd)
    with open("icore_abutted", 'r') as file:
        data_abbutted = file.read().split('\n')
        file.close()
    os.remove("icore_abutted")
    for line in data_abbutted:
        splitted_line = line.split(' ')
        if len(splitted_line) == 5:
            icore_pin = splitted_line[4]
            if splitted_line[1] not in icore_abutted_pin:
                icore_abutted_pin[splitted_line[1]] = {}
            icore_abutted_pin[splitted_line[1]][splitted_line[2]] = icore_pin
    return icore_abutted_pin

def create_icore_fct_spec(output_dir):
    global fp
    global corners
    model_type = os.environ.get('MODEL_TYPE')
    icore_abutted_pin = {}   

    if model_type == "fcl" or model_type == "fe2be":
        icore_abutted_pin = get_abutted_pin()

    for cor in corners.split(','):
        if "max_" in cor:
            output_file = output_dir + block + "." + cor +'_timing_specs.xml'
            fp =open(output_file,'a')


            for par in icore_abutted_pin:
                for pin in icore_abutted_pin[par]:
                    full_name = par +'/'+pin
                    if full_name in spec_array:
                        spec,clk,edge = spec_array[full_name].split(',')
                        if clk in clock_dict[cor]['ratio']:
                            spec=round(float(spec)*clock_dict[cor]['ratio'][clk],3)
                            print_to_file(1,icore_abutted_pin[par][pin],spec,'icore',clk,edge,'icore_spec was added based on the abuuted pin spec')
    fp.close()


def open_output_files(output_dir,partition):
    corners ["high","turbo","nom"]
    for cor in corners: 
        output_file = output_dir +'/'+ partition + cor + '.tcl'
        fp[cor,"tcl"] = open(output_file,'w')
        output_file = output_dir +'/'+ partition + cor + '.xml'
        fp[cor,"xml"] = open(output_file,'w')
    return fp

def close_output_file(fp):
    for file in fp:
        file.close()       

def get_mclk_ct(cor):
    archive = os.environ['PROJ_ARCHIVE']
    clk_tag = os.environ['CLOCK_COLLATERAL_TAG']
    block = os.environ['block']
    searchfile = open("runs/" + block + "/" + tech + "/release/latest/clock_collateral/" + cor + "/" + block + "_clock_params.tcl", "r")
    for line in searchfile:
        x = re.search("periodCache.*\(mclk_[^0-9]* [0-9]*", line)
        if x : 
                searchfile.close()
                return (re.findall("[0-9]+", line)[0])
    searchfile.close()

def scale_ft_xml(cor,ratio):
#    os.system('echo "<xml>"  > ' +output_dir +'/'+ block + "." + cor +  '_timing_specs.xml')
#    cmd = 'cat ' + output_dir +'/'+ block + '_timing_specs.xml | awk -v ratio=' + str(ratio) + " -F '" + '"' + "' '{OFS=FS}{$22=$22*ratio; print $0}' >> " +output_dir +'/'+ block + "." + cor +  '_timing_specs.xml' 
#    os.system(cmd)
#    os.system('echo "</xml>"  >> ' +output_dir +'/'+ block + "." + cor +  '_timing_specs.xml')
    os.system('echo "<xml>"  > ' +output_dir +'/'+ block + "." + cor +  '_ft_timing_specs.xml')
    cmd = 'cat ' + output_dir +'/'+ block + '_ft_timing_specs.xml | awk -v ratio=' + str(ratio) + " -F '" + '"' + "' '{OFS=FS}{$12=$12*ratio; print $0}' >> " +output_dir +'/'+ block  + "." + cor +  '_ft_timing_specs.xml' 
    os.system(cmd)       
    cmd = 'cat ' + output_dir +'/dfx_ft_timing_specs.xml | awk -v ratio=' + str(ratio) + " -F '" + '"' + "' '{OFS=FS}{$12=$12*ratio; print $0}' >> " +output_dir +'/'+ block  + "." + cor +  '_ft_timing_specs.xml' 
    os.system(cmd)       
    os.system('echo "</xml>"  >> ' +output_dir +'/'+ block + "." + cor +  '_ft_timing_specs.xml')
def combine_all_xml():
    for cor in corners.split(','):
        if "max_" in cor:
             os.system('cat '+output_dir +'/dfx_' + cor +  '_timing_specs.xml >> ' +output_dir +'/'+ block + "." + cor +  '_timing_specs.xml')
             os.system('echo "</xml>"  >> ' +output_dir +'/'+ block + "." + cor +  '_timing_specs.xml')

def create_fct_xml():
    global fp   
    global output_dir  
    global corners
    global cor
    r = re.compile("par_.*")
    output_dir = ward + "/runs/" + block + "/" +  tech + "/" + flow + "/inputs/"
    output_file =  output_dir + block + "_timing_specs.xml" 

    print('Get Clock Factors')  
    if os.environ.get('FCT_SCENARIOS') is None:
       corners=default_corner
    else:
       corners=os.environ.get('FCT_SCENARIOS')

    get_clock_dict(default_corner)
    print('Handle Partiton Spec')     
    for cor in corners.split(','):
        if "max_" in cor:
            output_file = output_dir + block + "." + cor +'_timing_specs.xml'
            
            fields = []
            fp =open(output_file,'w')
            fp.write(f'<xml>\n')
            for partition in list(filter(r.match,os.listdir(ward+'/runs/' ))):
                input_file = ward + "/runs/" + partition + "/"+ tech + "/release/latest/timing_specs/"+ partition + "_spec.csv"
                with open(input_file, 'r') as csvfile:
                    csvreader = csv.reader(csvfile)
                    fields = next(csvreader)
                    for row in csvreader:
                        if row[0]=="1":
                            if row[4] in clock_dict[cor]['ratio']:
                                row[2]=round(float(row[2])*clock_dict[cor]['ratio'][row[4]],3)
                                active,pin,spec,par,clk,edge,comment = row[0:7]
                                if check_parentheses(pin):
                                    if " " not in str(pin):
                                        par = par.strip()
                                        if "{" in str(pin):
                                            handel_range(row) 
                                        else:                    
                                            if int(active) == 1: 
                                                print_to_file(active,pin,spec,par,clk,edge,comment)
            fp.close()
    
    print('Handle Partiton FT Spec')  
    output_file =  output_dir + block + "_ft_timing_specs.xml"    
    fp =open(output_file,'w')
    for partition in list(filter(r.match,os.listdir(ward+'/runs/' ))):
        input_file = ward + "/runs/" + partition + "/"+ tech + "/release/latest/timing_specs/"+ partition + "_spec_ft.csv"
        if os.stat(input_file).st_size == 0:
             continue
        with open(input_file, 'r') as csvfile:
             csvreader = csv.reader(csvfile)
             fields = next(csvreader)
             for row in csvreader:
                active,par,in_pin,out_pin,ft_spec,comment = row[0:6]
                par = par.strip()                 
                if par==partition:
                        handel_ft_range(row)
#print_to_ft_file(active,par,in_pin,out_pin,ft_spec,comment)
    
    fp.close()

    #handle dfx specs
    print('Handling Dfx Specs')       
    create_fct_dfx_xml(ward + "/runs/" + block + "/"+ tech + "/release/latest/timing_specs/",output_dir)
    print('Handling icore Specs')
    create_icore_fct_spec(output_dir)

    print('Scaling FT XMLs')
    
    if os.environ.get('FCT_SCENARIOS') is None:
       corners=default_corner
       scale_ft_xml(corners,1)
    else:
       default_ct = float(get_mclk_ct(default_corner))
       corners=os.environ.get('FCT_SCENARIOS')
       for cor in corners.split(','):
           if "max_" in cor:
               ct_ration = int(get_mclk_ct(cor)) / default_ct 
               scale_ft_xml(cor,ct_ration)
    
#    output_file =  output_dir + block + "_timing_specs.xml"
#    os.remove(output_file)
    output_file =  output_dir + block + "_ft_timing_specs.xml" 
    os.remove(output_file)

    print('Combine all XMLS')
    combine_all_xml()

def get_clock_dict(default_cor):
    global clock_dict
    global corners
    clock_dict = {}
    cor = default_cor
    searchfile = open("runs/" + block + "/" + tech + "/release/latest/clock_collateral/" + cor + "/" + block + "_clock_params.tcl", "r")
    clock_dict['default'] = {}
    clock_dict['default']['ct'] = {}
    clock_dict['default']['ratio'] = {}
    
    for line in searchfile:
        x = re.search("periodCache\([^$,]*,[^0-9]* [0-9]*", line)
        if x : 
            y=re.findall("periodCache\(([^$,]*),[^0-9]* ([0-9]*)", line)
            clock_dict['default']['ct'][y[0][0]]=y[0][1]
        
    searchfile.close()
    
    for cor in corners.split(','):
        searchfile = open("runs/" + block + "/" + tech + "/release/latest/clock_collateral/" + cor + "/" + block + "_clock_params.tcl", "r")
        clock_dict[cor] = {}
        clock_dict[cor]['ct'] = {}
        clock_dict[cor]['ratio'] = {}
        for line in searchfile :
            x = re.search("periodCache\([^$,]*,[^0-9]* [0-9]*", line)
            if x : 
                y=re.findall("periodCache\(([^$,]*),[^0-9]* ([0-9]*)", line)
                clock_dict[cor]['ct'][y[0][0]]=y[0][1]
                clock_dict[cor]['ratio'][y[0][0]]=float(y[0][1])/float(clock_dict['default']['ct'][y[0][0]])
        searchfile.close()
    
def create_fct_dfx_xml(input_dir,output_dir):
    global fp  
    global spec_on_pin
    global corners
    global cor 
    csv_file = input_dir + "dfx_spec.csv"
    for cor in corners.split(','):
        if "max_" in cor:
            output_file = output_dir +'/dfx_'+cor+'_timing_specs.xml'
            fields = []
            fp =open(output_file,'w')
            with open(csv_file, 'r') as csvfile:
                 csvreader = csv.reader(csvfile)
                 fields = next(csvreader)
                 for row in csvreader:
                     if row[0]=="1":
                        if row[4] in clock_dict[cor]['ratio']:
                            row[2]=round(float(row[2])*clock_dict[cor]['ratio'][row[4]],3)
                            active,pin,spec,par,clk,edge,comment = row[0:7]
                            if check_parentheses(pin):
                                if " " not in str(pin):
                                    par = par.strip()
                                    if "{" in str(pin):
                                        handel_range(row) 
                                    else:                    
                                        if int(active) == 1:
                                            print_to_file(active,pin,spec,par,clk,edge,comment)
            fp.close()
    csv_file = input_dir + "dfx_spec_ft.csv"
    for cor in corners.split(','):
        if "max_" in cor:
            output_file = output_dir +'/dfx_ft_timing_specs.xml'
            fields = []
            fp =open(output_file,'w')
            with open(csv_file, 'r') as csvfile:
                 csvreader = csv.reader(csvfile)
                 fields = next(csvreader)
                 for row in csvreader:
                    active,par,in_pin,out_pin,ft_spec,comment = row[0:6]
                    in_pins=handel_ft_range_pin([],in_pin)
                    out_pins=handel_ft_range_pin([],out_pin)
                    if len(in_pins) == len(out_pins):
                        for n in range(0,len(in_pins)):
                        #print(in_pins[n] , out_pins[n])
                            print_to_ft_file(active,par,in_pins[n],out_pins[n],ft_spec,comment)
                    else:
                        if len(in_pins) == 1:
                            for pin in out_pins:
                            #print(in_pins[0] , pin)
                                print_to_ft_file(active,par,in_pins[0],pin,ft_spec,comment)
                        if len(out_pins) == 1:
                            for pin in in_pins:
                            #  print(pin, out_pins[0])
                                print_to_ft_file(active,par,pin,out_pins[0],ft_spec,comment)
                        if len(in_pins) != 1 and len(out_pins) != 1:
                            print("the input "+in_pin+"and the output"+out_pin+" is not of the same size")
                            exit(1)
            fp.close()


def create_dfx_xml(input_dir,output_dir):
    global fp  
    global spec_on_pin 
    csv_file = input_dir + "dfx_spec.csv"
    output_file = output_dir +'/dfx_timing_specs.xml'
    fields = []

    fp =open(output_file,'w')
    fp.write(f'<xml>\n')
    with open(csv_file, 'r') as csvfile:
         csvreader = csv.reader(csvfile)
         fields = next(csvreader)
         for row in csvreader:
             active,pin,spec,par,clk,edge,comment = row[0:7]
             if not check_parentheses(pin):
                 print("unbalanced parentheses at "+pin)		 
                 exit(1)
             if " " in str(pin):
                 print("\nYou have Space at \""+ pin +"\"")
                 exit(1)
             try:
                 float(spec)
             except:
                 print(f'\nProblem with spec on pin: "{pin}", spec: "{spec}"')
                 exit(1)
             par = par.strip()
             if "{" in str(pin):
                 handel_range(row) 
             else:                    
                 if int(active) == 1:
                     print_to_file(active,pin,spec,par,clk,edge,comment)
    fp.write(f'</xml>')
    fp.close()

    csv_file = input_dir + "dfx_spec_ft.csv"
    output_file = output_dir +'/dfx_ft_timing_specs.xml'
    fields = []
    fp =open(output_file,'w')
    with open(csv_file, 'r') as csvfile:
         csvreader = csv.reader(csvfile)
         fields = next(csvreader)
         for row in csvreader:
            active,par,in_pin,out_pin,ft_spec,comment = row[0:6]
            in_pins=handel_ft_range_pin([],in_pin)
            out_pins=handel_ft_range_pin([],out_pin)
            if (" " in str(in_pin)) or (" " in str(out_pin)):
                print("\nYou have Space at \""+ in_pin +"\" or \"" + out_pin + "\"")
                exit(1)
            try:
               float(ft_spec)
            except:
               print(f'\nProblem with spec on pin: "{in_pin}", spec: "{ft_spec}"')
               exit(1)
            if len(in_pins) == len(out_pins):
                for n in range(0,len(in_pins)):
                #print(in_pins[n] , out_pins[n])
                    print_to_ft_file(active,par,in_pins[n],out_pins[n],ft_spec,comment)
            else:
                if len(in_pins) == 1:
                    for pin in out_pins:
                    #print(in_pins[0] , pin)
                        print_to_ft_file(active,par,in_pins[0],pin,ft_spec,comment)
                if len(out_pins) == 1:
                    for pin in in_pins:
                    #  print(pin, out_pins[0])
                        print_to_ft_file(active,par,pin,out_pins[0],ft_spec,comment)
                if len(in_pins) != 1 and len(out_pins) != 1:
                    print("the input "+in_pin+"and the output"+out_pin+" is not of the same size")
                    exit(1)
    fp.close()


def create_par_xml(input_dir,output_dir,partition):
    global fp  
    global spec_on_pin 
    csv_file = input_dir + partition +"_spec.csv"
    output_file = output_dir +'/'+ partition + '_timing_specs.xml'
    fields = []

    fp =open(output_file,'w')
    fp.write(f'<xml>\n')
    with open(csv_file, 'r') as csvfile:
         csvreader = csv.reader(csvfile)
         fields = next(csvreader)
         for row in csvreader:
             active,pin,spec,par,clk,edge,comment = row[0:7]
             if not check_parentheses(pin):
                 print("unbalanced parentheses at "+pin)		 
                 exit(1)
             if " " in str(pin):
                 print("\nYou have Space at \""+ pin +"\"")
                 exit(1)
             try:
                 float(spec)
             except:
                 print(f'\nProblem with spec on pin: "{pin}", spec: "{spec}"')
                 exit(1)   
             par = par.strip()
             if par==partition:
                 if "{" in str(pin):
                     handel_range(row) 
                 else:                    
                     if int(active) == 1:
                        spec_on_pin[pin]=spec
                        if pin  in second_def.keys():
                            second_def[pin]= second_def[pin] + 1  
                        else:
                            second_def[pin]= 1
                     print_to_file(active,pin,spec,par,clk,edge,comment)
    fp.write(f'</xml>')
    fp.close()
    
    csv_file = input_dir + partition +"_spec_ft.csv"
    output_file = output_dir +'/'+ partition + '_ft_timing_specs.xml'

    fp =open(output_file,'w')
    fp.write(f'<xml>')
    with open(csv_file, 'r') as csvfile:
         csvreader = csv.reader(csvfile)
         fields = next(csvreader)
         for row in csvreader:
             active,par,in_pin,out_pin,ft_spec,comment = row[0:6]
             par = par.strip()
             if (" " in str(in_pin)) or (" " in str(out_pin)):
                 print("\nYou have Space at \""+ in_pin +"\" or \"" + out_pin + "\"")
                 exit(1)
             try:
                 float(ft_spec)
             except:
                 print(f'\nProblem with spec on pin: "{in_pin}", spec: "{ft_spec}"')
                 exit(1)
             if par==partition:
                 handel_ft_range(row)
#                 print_to_ft_file(active,par,in_pin,out_pin,ft_spec,comment)
    fp.write(f'</xml>')
    fp.close()

def check_missing_spec(partiton_pins):
    total = 0 
    missing = 0
    report_file= output_dir  +  "/" + partition + "_missing_spec.report"
    fp =open(report_file,'w')
    for pin in partiton_pins.splitlines():
        if pin  in spec_on_pin.keys():
            total = total + 1 
        else:
            missing = missing + 1 
            total = total + 1 
            fp.write(f'-I- missing spec on pin: ' + pin + "\n")
    
    print("\nMissing Spec Report: \n\t" + str(round(100*missing/total,2)) + "% of "+ partition + " ports are without spec\n\t" +report_file)
    fp.close()
   
def check_double_def():
    report_file= output_dir  +  "/" + partition + "_multipule_spec_definition.report"
    fp =open(report_file,'w')
    for pin in second_def.keys():
        if second_def[pin] > 1:
           fp.write(f'-I- The spec on pin: ' + pin + " is defined " + str(second_def[pin]) + " times \n")
    fp.close()
    print("\nMultiplule Spec Definition on the same port :\n\t" + report_file )

def pin_not_found(partiton_pins):
    report_file= output_dir  +  "/" + partition + "_pin_not_found.report"
    fp =open(report_file,'w')
    for pin in spec_on_pin.keys():
        if pin not in partiton_pins.splitlines():
             fp.write(f'-I- pin ' + pin + " does not exist at netlist\n")
    fp.close()
    print("\nSpeced pin is not on Netlist report:\n\t" + report_file )

def check_unbalance_status(partiton_pins):
#    print("\nUnbalance Spec Status\n\tnot ready yet")
    return 0	

def populate_specs_from_archive():
    r = re.compile("par_.*")
    for partition in list(filter(r.match,os.listdir(ward+'/runs/' ))):
        dist_dir = ward + "/runs/" + partition + "/"+ tech + "/release/latest/timing_specs/"
        input_dir = archive + "/arc/" + partition + "/timing_specs/GOLDEN/"
        os.system('cp ' + input_dir + '*.csv ' + dist_dir)
    #populate dfx spec from top die timing_spec
    dist_dir = ward + "/runs/" + block + "/"+ tech + "/release/latest/timing_specs/"
    input_dir = archive + "/arc/" + block + "/timing_specs/GOLDEN/"
    os.system('mkdir -p ' + dist_dir)
    os.system('cp ' + input_dir + '*.csv ' + dist_dir)

def main():
    global partiton_pins
    global spec_array
    global output_dir
    global partition
    global spec_on_pin
    global second_def
    spec_array = {}
    spec_on_pin = {}
    second_def = {} 
    if sys.argv[1] == "--fct_run" :
        argParser = argparse.ArgumentParser()
        argParser.add_argument('--populate', action='store_true', default = False ,help='Bring latese data from archive')
        argParser.add_argument('--fct_run', action='store_true', default = False ,help='Bring latese data from archive')
        args = argParser.parse_args()
        if args.populate:
            print('Populating Spec files from Archive')
            populate_specs_from_archive()
        print('Creating FCT XML from CSV')
        create_fct_xml()
    else:
        argParser = argparse.ArgumentParser()
        argParser.add_argument("-i", "--input_directory", help="Should include 2 input csv Files : ${par}_spec.csv and ${par}_spec_ft.csv",required=True)
        argParser.add_argument("-o", "--output_directory", help="the output directory to save the file",required=True)
        argParser.add_argument("-p", "--partition", help="partition name to work on",required=True)
        args = argParser.parse_args()
        input_dir = args.input_directory
        output_dir = args.output_directory
        partition = args.partition
        os.system('mkdir -p ' + output_dir)

        if partition == "dfx" :
            create_dfx_xml(input_dir,output_dir)
        else:
            create_par_xml(input_dir,output_dir,partition)   
            partiton_pins = get_all_pins(partition)
            check_missing_spec(partiton_pins)
            pin_not_found(partiton_pins)
            check_double_def()
            check_unbalance_status(partiton_pins)
            cmd = 'mkdir -p runs/' + partition + "/" + tech + "/release/golden/timing_specs"
            os.system(cmd)
            cmd = "cp -f " + input_dir  + "/" + partition + "_spec*.csv runs/" + partition + "/" + tech + "/release/golden/timing_specs/"
            os.system(cmd)
#        print("\nTo CI the File please run :\n\t  eouMGR --block " + partition + " --bundle timing_specs --tag GOLDEN --ward_tag golden --archive")
	
	   

#    os.system(f'~baselibr/LNC_script/sio_spec_ci.csh -file {pmhglb_spec} -par par_pmhglb -type spec')
#    os.system(f'~baselibr/LNC_script/sio_spec_ci.csh -file {exe_int_spec} -par par_exe_int -type spec')
user  = environ.get('USER')   
ward  = environ.get('ward')
block = environ.get('block')
tech  = environ.get('tech')
flow  = environ.get('flow')
archive = environ.get('PROJ_ARCHIVE')

if block is None:
    block = "core_client" 
if tech  is None:
    tech = "n2p_htall_conf4"
if flow  is None:
    flow  = "sta_pt"

default_corner = "func.max_high.T_85.typical"
cor = default_corner
if __name__ == '__main__': 
    main() 
