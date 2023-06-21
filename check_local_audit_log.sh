#!/bin/bash
# 
# CHECK_MK
# tipe: local check
# about: "This service was created to identify when the default user CMKADMIN
#         is applying changes to the server. The script must remain as a 
#         local check within the Master of Check_mk"
#
# author: Alexeiev F Araujo
# alexeievfa@gmail.com


#Debug=1 True
#Debug=0 False
DEBUG=0
#em minutos
THRESHOLD=10
SITENAME="NAMEYOURSITE"
FILE="/omd/sites/$SITENAME/var/check_mk/wato/log/wato_audit.log"

NOW=$(( ( 10#$(date +%H) * 3600 ) + ( 10#$(date +%M) * 60 ) + 10#$(date +%S) ))
[ $DEBUG -eq 1 ] && echo "[DEBUG] - time in sec - $NOW\n[DEBUG] - Tempo - $(date +%H:%M:%S)"

for timestamp in $(strings $FILE | grep cmkadmin | grep 'activate-changes' | awk -F "[,: ]" '{print $3}' | uniq |tail -n100 )
do
    [ $DEBUG -eq 1 ] && echo "[DEBUG] FOR  - $(date --date="@${timestamp}" +%d)"

    if [ $(date --date="@${timestamp}" +%d) -eq $(date +%d) ]
    then
    #Validates if we are within the same day
        VAR=$(date --date="@${timestamp}" +%H:%M:%S)
        OLD=$(( ( 10#$(date --date=$VAR +%H) * 3600 ) + ( 10#$(date --date=$VAR +%M) * 60 ) + 10#$(date --date=$VAR +%S) ))
        [ $DEBUG -eq 1 ] && echo "[DEBUG] - Var time of change -  $VAR\n[DEBUG] - Var OLD in sec - $OLD"
        DIFF=$(( ($NOW - $OLD) / 60 ))
        [ $DEBUG -eq 1 ] && echo "[DEBUG] - Diff in minutes - $DIFF"
        if [ $DIFF -lt $THRESHOLD ]
        then
            status_code=2
            status_txt="cmkadmin activate changes on site $SITENAME - $VAR"
            [ $DEBUG -eq 1 ] && echo "[DEBUG] - Var status_code - $status_code"
        else
            status_code=0
            status_txt="Everything OK"
        fi
    else
        status_code=0
        status_txt="Everything OK"
    fi
done

echo "$status_code \"Check_MK Activate Changes\" Count=$status_code;;; $status_txt"