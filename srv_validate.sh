#!/bin/bash
PROGNAME=$(basename $0)

## This script will collect key parts of your VIRL server configuration settings and
## place them into a single file (SrvValTest.txt). This file can be collected and
## forwarded to VIRL support community for assistance.
## Validation script created by alejandro gallego (alegalle@cisco.com)
## Last modified on Jan 10, 2017

TEMP_FILE=/tmp/${PROGNAME}.$$.$RANDOM

trap int_exit INT

function int_exit
{
        echo "${PROGNAME}: Aborted by user"
        exit
}

function _result
{
printf "%s\nResults printed to file \"$_out\" in
    \"virl user's home directory\"%s\n"
sleep 2
rm $_out >& /dev/null
touch $_out

}

function _netint
{
ifquery --list | egrep -v lo | sort | while read intf
do
ipadr=$(ifconfig $intf |egrep -o '([0-9]+\.){3}[0-9]+' |head -1)
    printf "%s\n$intf CONNECTED\n"
    printf "%s\n$intf CONNECTED\n" >> $_out 2>&1
    sudo ethtool $intf | grep 'Link detected: yes' > /dev/null
        if [ $? -ne 0 ] ; then
        printf ">>>>%sInterface $intf DOWN%s\n"
        printf ">>>>%sInterface $intf DOWN%s\n" >> $_out 2>&1
        else
        printf "IP: $ipadr\n"
        printf "IP: $ipadr\n" >> $_out 2>&1
        fi
done
printf "%s\nBridge Info: \n $lbrdg%s\n" >> $_out 2>&1
vini=$(egrep '\bsalt_'\|'\bhost'\|'\bdomain'\|'\bpublic_'\|'\bStatic_'\|'\busing_'\|'\bl2_'\|'\bl3_'\|'\bdummy_'\|'\bvirl_'\|'\binternalnet_'\|'_nameserver' /etc/virl.ini)
printf "%s\n>>> VIRL Config Summary <<<\n$vini" >> $_out 2>&1
}

function _saltst
{
printf "%s\nCheckin Salt Configuration...%s\n"
sleep 1
printf "%s\nConfigured Salt masters:\n $mstr%s\n"
printf "%s\nConfigured Salt ID:\n $lic%s\n"
printf "%s\n\nSalt Masters\n $mstr %s\n"  >> $_out 2>&1
printf "%s\nSalt ID\n $lic %s\n"  >> $_out 2>&1
#egrep  -o -w '\bus-[1-4].virl.info'\|'\beu-[1-4].virl.info' /etc/virl.ini | while read srv
#echo $mstr | while read srv
for srv in ${mstr//,/ }
    do
    idig=$(dig $srv | egrep -o '([0-9]+\.){3}[0-9]+' |head -1)
    printf "%s\nTesting Connectivity to: [$srv $idig]%s"
    printf "%s\n>>>> $srv :: $idig\n" >> $_out 2>&1 && nc -zv $srv 4505-4506 >> $_out 2>&1
    echo ""
    printf "%s\nChecking License....%s"
    printf "%s\nAuth test --> Salt Server [$srv]%s\n"
    printf "%s\n>>>> $srv\n" >> $_out 2>&1 && sudo salt-call --master $srv -l debug test.ping >> $_out 2>&1
    done

printf "%s\nChecking hostname and network interfaces: %s\n"
sleep 2
    for h in /etc/hostname /etc/hosts /etc/network/interfaces
    do
        printf "%s\n>>> $h <<<%s\n" >> $_out 2>&1
        cat $h >> $_out
    done
sleep 2
printf "%s\nResults printed to file \"$_out\" located in
\"virl user's home directory\" Path is \"/home/virl\"%s\n"
sleep 5
}

lbrdg=$(brctl show)
mstr=$(sudo salt-call --local grains.get salt_master | egrep -v local: )
lic=$(sudo salt-call --local grains.get id)
_out=~/SrvValTest.txt
_result
_netint
_saltst
