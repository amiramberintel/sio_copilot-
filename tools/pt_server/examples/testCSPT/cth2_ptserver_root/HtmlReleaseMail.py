#!/usr/bin/env python

import smtplib
from email.mime.text import MIMEText
import smtplib,ssl
from email.mime.multipart import MIMEMultipart
from email.mime.base import MIMEBase
from email.mime.text import MIMEText
from email.utils import formatdate
from email import encoders
import sys
import re
import subprocess
#####################################################################################################################################
def fix_mail_cfg(mode,string_with_mail_cfg_header):
    
    splited_mail_contacts_list = string_with_mail_cfg_header.split(",")
    updated_mail_contacts_list = []
    mail_contact = ''
    #iterate now over each item anc check if it holds full name. in case yes - push to list, else add @intel.com
    for i in range(len(splited_mail_contacts_list)):
	match = re.search('@intel.com',splited_mail_contacts_list[i])
	if (match):
	    #mail holds @intel.com - so we are ok, take as provided
	    mail_contact = splited_mail_contacts_list[i]
	    updated_mail_contacts_list.append(mail_contact)
	else: 	    
	    #we should add  @intel.com to mail contact header, since we received user name so we just need to run finger command here
	    mail_contact = splited_mail_contacts_list[i]   
	    
	    #import subprocess
            ## call finger command ##
            print "-I- %-s list: Start: Converting user to mail: %-s" % (mode,splited_mail_contacts_list[i])
	    cmd = '/usr/bin/finger '+splited_mail_contacts_list[i]
	    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, shell=True)
 
            ## Talk with finger command i.e. read data central area ##
            ##Interact with process: Send data to stdin. Read data from stdout and stderr, until end-of-file is reached. Wait for process to terminate. The optional input argument should be a string to be sent to the child process, or None, if no data should be sent to the child.
            (output, err) = p.communicate()
 
            ## Wait for finger to terminate. Get return returncode ##
            p_status = p.wait()
            #print "Command output : ", output
            #print "Command exit status/return code : ", p_status
	    
	    ## caputre the user mail in intel: 
	    match = re.search('Name: (.*)\n',output)
	    full_mail_adress = match.group(1)+'@intel.com'
	    print "-I- %-s list: End: Convered user to mail:%-s -> %-s" % (mode,splited_mail_contacts_list[i],full_mail_adress)
	    updated_mail_contacts_list.append(full_mail_adress)
	    
    print "-I- %-s list: Originl Mailing string = %-s" % (mode,string_with_mail_cfg_header)
    updated_mail_contacts_list_string = ",".join(updated_mail_contacts_list)
    print "-I- %-s list: Updated Mailing string = %-s" % (mode,updated_mail_contacts_list_string)
    return updated_mail_contacts_list_string
#####################################################################################################################################    

#reset all vaiables to empty string
to_mail = ""
from_mail = ""
subject_mail = ""
attachment_mail = ""

amount_of_args = 0

# Begining of the mail
print "\n\
######################################################################################\n\
# _   _ _             _  ___        _       ___  ___      _ _                        #\n\
#| | | | |           | |/ _ \      | |      |  \/  |     (_) |                       #\n\
#| |_| | |_ _ __ ___ | / /_\ \_   _| |_ ___ | .  . | __ _ _| | ___ _ __ _ __  _   _  #\n\
#|  _  | __| '_ ` _ \| |  _  | | | | __/ _ \| |\/| |/ _` | | |/ _ \ '__| '_ \| | | | #\n\
#| | | | |_| | | | | | | | | | |_| | || (_) | |  | | (_| | | |  __/ |_ | |_) | |_| | #\n\
#\_| |_/\__|_| |_| |_|_\_| |_/\__,_|\__\___/\_|  |_/\__,_|_|_|\___|_(_)| .__/ \__, | #\n\
#                                                                      | |     __/ | #\n\
#       Auto Mailer, Created by ogivol, 2018 courtesy                  |_|    |___/  #\n\
######################################################################################\n"
       

# inputs checker:
if ((len(sys.argv) - 1) == 5):
    print "-I- Amount of args are:",(len(sys.argv)-1)
    amount_of_args = len(sys.argv)-1
    to_mail = sys.argv[1]
    from_mail = sys.argv[2]
    subject_mail = sys.argv[3]
    html_body = sys.argv[4]
    attachment_mail = sys.argv[5]
elif ((len(sys.argv) - 1) == 4):
    print "-I- Amount of args are:",(len(sys.argv)-1)
    amount_of_args = len(sys.argv)-1
    to_mail = sys.argv[1]
    from_mail = sys.argv[2]
    subject_mail = sys.argv[3]
    html_body = sys.argv[4]
else: 
    print "-E- Please use help bellow here to progress, since you are not using it correctly!"
    print "-I- You requested help, please make sure keep attach syntax, each arg closed by \'<input>\' \n\
           arg1: To List, real email (seperated by comman) for example: 'Ohad.Givol@intel.com,Rafi.Kurtz@intel.com,Ohad1.Givol@intel.com' or ogivol,rkurtz \n\
	   arg2: From List (one real email) \n\
	   arg3: Subject \n\
	   arg4: html_body (must be a regular html file!) \n\
	   arg5: List of files to attach (if empty, dont provide at all) \
	   "
    print "-I- Bye Bye"    
    sys.exit(0)



# help request:
if ((to_mail == "help") or (from_mail == "help") or (subject_mail == "help") or (attachment_mail == "help") or (html_body == "help")):
    print "-I- You requested help, please make sure keep attach syntax \n\
           arg1: To List, real email (seperated by comman) for example: 'Ohad.Givol@intel.com,Rafi.Kurtz@intel.com,Ohad1.Givol@intel.com' \n\
	   arg2: From List (one real email) \n\
	   arg3: Subject \n\
	   arg4: html_body (must be a regular html file!) \n\
	   arg5: List of files to attach (if empty, dont provide at all) \
	   "
    print "-I- Bye Bye"
    sys.exit(0)
 
 
 
# summary
print "-I- Your argements are:" 
print "-I- to_mail:        ",to_mail
print "-I- from_mail:      ",from_mail
print "-I- subject_mail:   ",subject_mail
print "-I- html_body:      ",html_body
print "-I- attachment_mail:",attachment_mail
 
# fix name in case provided user name only
fixed_to_mail = fix_mail_cfg('To:',to_mail)
fixed_from_mail = fix_mail_cfg('From:',from_mail)

# Create message container - the correct MIME type is multipart/alternative.
msg = MIMEMultipart()
msg['Subject'] = subject_mail
msg['From'] = fixed_from_mail
msg['To'] = fixed_to_mail

# post fix notification:
print "-I- Will send mail to:" 
print "-I- From:        ",fixed_from_mail
print "-I- To:          ",fixed_to_mail

# in case of multiple attachments (arg5) we want to attach each one of them so we will split this arg and make for in loop
if (attachment_mail == ""):
    print "-I- no attachment found here, so mail will present only your body content..."
else: 
    muteable_list = attachment_mail.split(",")
    
    # iterate each item and add it to the list:
    for i in range(len(muteable_list)):
        #print "-I- adding now this attachment to your mail",muteable_list[i]
	attachment = muteable_list[i]
        part = MIMEBase('application', "octet-stream")
        part.set_payload(open(attachment, "rb").read())
        encoders.encode_base64(part)
	
	# for file name, check if this is a full path, if yes take only file name
	match = re.search('(.*)\/(.*)',muteable_list[i])
	
	if (match):
	    file_name = match.group(2)
	else :
	    file_name = muteable_list[i]

	attachment_string = "\'attachment; filename=\"%-s\"\'" % (file_name)

	# print attachment_string
        # part.add_header('Content-Disposition', 'attachment; filename="testing.txt"')
	part.add_header('Content-Disposition', attachment_string)
	print "-I- adding now this attachment to your mail: '%-s' named: '%-s'" % (muteable_list[i],file_name)
        msg.attach(part)


# boday attachment (HTML sytle!)
print "-I- Adding your HTML for the Body based on %-s " % (html_body)
file_handler = open(html_body,"r")
file_handler2string = file_handler.read()
file_handler.close()

# Create the body of the message (a plain-text and an HTML version).
#html = """\
#<html>
#  <head>Hello Rafi - This is an <u>automated</u> mail to your mailbox</head>
#  <body>
#    <p>Hi!<br>
#       Rafi, How are <b>you?</b> Do you want to attach a file?<br>
#       Here is the <a href="https://www.walla.co.il">link</a> you wanted.
#       <br><font color="red" face="verdana">What is your opinoin of this mail?</font
#      
#    </p>
#  </body>
#  <hr style=\"color:grey; background-color:#919090; height:2px;\"><br> &#169 Created by ogivol Auto Mailer Tool \n
#</html>
#
#"""

# html_file_handler2string = '"'+file_handler2string+'"'
html_file_handler2string = file_handler2string

# add footer for your mail
add_footer = 1
if (add_footer): 
    html_bar = "<br><hr style=\"color:#BEBEBE; background-color:#919090; height:2px;\"><i><font color=\"#BEBEBE\">&#169 Created by Auto Mailer Python.py Daeomon Tool 2018, CDG BE Integration DA Team</font></i></html>"
    html_file_handler2string_w_html_footer = re.sub('</html>','',html_file_handler2string)
    html_file_handler2string_w_html_footer += html_bar
    print "-I- Added Auto Mail footer"
    html_file_handler2string = html_file_handler2string_w_html_footer
    
    
# Record the MIME types of both parts - text/plain and text/html.
part1 = MIMEText(html_file_handler2string, 'html')

# Attach parts into message container.
# According to RFC 2046, the last part of a multipart message, in this case
# the HTML message, is best and preferred.
msg.attach(part1)

# Send the message via local SMTP server.
s = smtplib.SMTP('localhost')


# sendmail function takes 3 arguments: sender's address, recipient's address
# and message to send - here it is sent as one string.
print "-I- Sending your mail now...."

# since we need the mail to/from with list and not with string we shall convert it now..
# see documentation here
# https://stackoverflow.com/questions/1546367/python-how-to-send-mail-with-to-cc-and-bcc
# https://zhbluatoicr.wordpress.com/2012/09/18/send-email-to-multiple-recipients-in-python/
fixed_from_mail_list = fixed_from_mail.split(",")
fixed_to_mail_list = fixed_to_mail.split(",")
s.sendmail(fixed_from_mail_list, fixed_to_mail_list, msg.as_string())
s.quit()
print "-I- Done. Good Day. Greetings. Bye Bye!"
