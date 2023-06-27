#!/bin/bash
#
# CHECK_MK
# tipe: Active check
# about: "Used to monitor files older than X time on FTP or SFTP server"
#
# author: Alexeiev F Araujo
# alexeievfa@gmail.com      
#
# Example:
# check_active_sftp_ftp-fileTime.sh -u USERXsftp.server.com -d "/data/" -D "files" -f .csv -t sftp -w 60 -H 192.168.1.201 
#

#DEBUG=1 True
#DEBUG=0 False
DEBUG=0

while getopts "d:D:u:t:f:w:H:h" flag
do
    case "$flag" in
        d) Dir=${OPTARG};;
        D) Desc=${OPTARG};;
        u) User=${OPTARG};;
        f) File=${OPTARG};;
        t) Prot=${OPTARG};;
        w) Warn=${OPTARG};;
        H) Host=${OPTARG};;
        h) Help;;
        :) echo "The option ${OPTARG} required arguments\n";Help ;;
        \?) Help;;
    esac
done

function Help() {
    echo "Use: ${0##*/} <ARGs> 
-h This Help
-u <userIP>
-d </directory/>
-D <Service_Description>
-f <file Extension>
-t <ftp (21) | sftp (22)>
-w <900> Time in sec.

-H <site>

Ex.: check_active_sftp_ftp-fileTime.sh -u < userservidor > -d < "/data/" > -D < "files" > -f < .csv > -t < sftp > -w < 60 > -H < 192.168.1.201 >
"
exit 1
}

# Add the following information separated by " | "
#1 - userIpdaconexao
#2 - Username
#3 - Password

# 'userHost|User|Password'
dbPass=(
'USERXsftp.server.com|USERX|##PASSWORD##'

)

ArqTemp=/tmp/TempFile_${Desc// /_}.txt
NumFile=0
Ind=0

function T_DEPENDENCE() {
Cmd=$@
OP=0
for Command in "$@"
do
    if [ ! $(which $Command 2>/dev/null) ]
    then
        OP=$(( $OP +1))
        Problem[$OP]=$Command
        if [ -z $OS ]
        then
            which apt >/dev/null && OS=debian
            which yum >/dev/null && OS=redhat
            [ $DEBUG -eq 1 ] && echo "OS - $OS"
        fi
    fi
done

if [ ${#Problem[@]} -ne 0 ]
then
    echo "Command(s) not found - ${Problem[@]}"
    read -p "Do you want to install lftp?[Yn]" Yn
    if [ -z $Yn ] || [ ${Yn^^} = "Y" ]
    then
        case $OS in
            debian)
                sudo apt install -y lftp >/dev/null 2>&1 && echo "successfully installed package"
                exit 0
            ;;
            redhat)
                sudo yum install -y lftp >/dev/null 2>&1 && echo "successfully installed package"
                exit 0
            ;;
        esac
    else
        echo "This software ( ${Problem[@]} ) is prerequisite"
        exit 1
    fi
fi
}

function Pass(){
    for key in ${dbPass[@]}
    do
        if [ "$1" == "$(echo $key |cut -d'|' -f1)" ]
        then
            User=$(echo $key |cut -d'|' -f2)
            Pass=$(echo $key |cut -d'|' -f3)
            [ $DEBUG -eq 1 ] && echo "[DEBUG] -  IF - User: $User - Pass: $Pass"
        fi
        [ $DEBUG -eq 1 ] && echo "[DEBUG] - For $key"
    done
}

#Testing dependencies
T_DEPENDENCE lftp

#User and Pass
Pass $User

[ $DEBUG -eq 1 ] && echo "[DEBUG] - User: $User - Pass: $Pass"

if [ -z $User ] || [ -z $Dir ] || [ -z $Desc ] || [ -z $Host ]
then
    echo -e "missing arguments\n"
    Help
fi

if [ "$Prot" = "ftp" ]
then
  Prot="ftp://"
else
  Prot="sftp://"
fi

if [ -z $Warn ]
then
    Warn=900
    #Time in seconds
    [ $DEBUG -eq 1 ] && echo "[DEBUG] - WARN: $Warn"
fi

[ $DEBUG -eq 1 ] && echo "[DEBUG] - Starting FTP connection"
if [ -z $File ]
then
    for (( i=1; i <= 3; i++ ))
    do
        timeout 10 lftp -c "set sftp:auto-confirm yes; set sftp:connect-program \"ssh -a -x -o UserKnownHostsFile=/dev/null\"; open -u $User,$Pass $Prot$Host; ls ${Dir} |egrep -v "^d";bye" > $ArqTemp 2>/dev/null
        Out=$?
        if [ $Out -ne 0 -a $i -eq 3 ] 
        then
            [ $DEBUG -eq 1 ] && echo "[DEBUG] - Timeout"
            echo "UNK - Timeout for server $Host"
            exit 3
        elif [ $Out -eq 0 ]
        then
            break
        fi
    done
else
    for (( i=1; i <= 3; i++ ))
    do
        timeout 10 lftp -c "set sftp:auto-confirm yes; set sftp:connect-program \"ssh -a -x -o UserKnownHostsFile=/dev/null\"; open -u $User,$Pass $Prot$Host; ls ${Dir} |egrep -v "^d" | grep $File;bye" > $ArqTemp 2>/dev/null
        Out=$?
        if [ $Out -ne 0 -a $i -eq 3 ] 
        then
            [ $DEBUG -eq 1 ] && echo "[DEBUG] - Timeout"
            echo "UNK - Timeout for server $Host"
            exit 3
        elif [ $Out -eq 0 ]
        then
            break
        fi
    done
fi

[ $DEBUG -eq 1 ] && echo "[DEBUG] - reading file - $(cat $ArqTemp)"

while read line ;
do
    Hora=$(echo $line |awk '{print $8}')
    Dia=$(echo $line |awk '{print $7}')
    H1=$(( 10#${Hora:0:2} *3600))
    if [ $(echo ${Hora} |grep ":" ) ]
    then
        M1=$(( 10#${Hora:3} *60 ))
    else
        M1=$(( 10#$(date +%M) *60 ))
    fi
    Time1=$(( H1 + M1 ))
    Nome=$(echo $line |awk -F" " '{print $9}')
    [ $DEBUG -eq 1 ] && echo "[DEBUG] - while - file: $Nome - start time: $Time1"
    H2=$(( 10#$(date +%H) * 3600 ))
    M2=$(( 10#$(date +%M) * 60 ))
    Time2=$(( H2 + M2 ))
    TimeF=$(( Time2 - Time1 ))
    [ $DEBUG -eq 1 ] && echo "[DEBUG] - while - current time: $Time2 - Diff $TimeF"
    if [ $Dia -eq $(date +"%d")  ]
    then
        if [ $TimeF -gt $Warn ]
        then
            NumFile=$((NumFile + 1))
            Vetor[$Ind]=$Nome
        else
            NumFile=$((NumFile + 0))
        fi
    else
        Vetor[$Ind]=$Nome
        NumFile=$((NumFile + 1))
    fi
    Ind=$((Ind+1))
    export Code
    export NumFile
    export Vetor

done < <(cat $ArqTemp)

if [ $NumFile -eq 0 ]
then
    echo "OK - Files not found|Files=$NumFile"
    Code=0
else
    echo "CRIT - ${#Vetor[@]} Files found : ${Vetor[@]}|Files=$NumFile"
    Code=2
fi

[ $DEBUG -eq 1 ] && echo "[DEBUG] - exit Code: $Code"

rm -f $ArqTemp
exit $Code
