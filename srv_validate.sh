#!/bin/bash
## This script will collect key parts of your VIRL server configuration settings and
## place them into a single file (SrvValTest.txt). This file can be collected and
## forwarded to VIRL support community for assistance.
## Validation script created by alejandro gallego (alegalle@cisco.com)
## Last modified on Dec 12, 2016

trap int_exit INT

function int_exit
{
        echo "${PROGNAME}: Aborted by user"
        exit
}

function _result
{
# _out=~/SrvValTest.txt
printf "%s\nResults printed to file \"$_out\" in
    \"virl user's home directory\"%s\n"
sleep 2
rm $_out >& /dev/null
touch $_out

}

function _netint
{
# _out=~/SrvValTest.txt
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
vini=$(egrep '\bsalt_'\|'\bhost'\|'\bdomain'\|'\bpublic_'\|'\bStatic_'\|'\busing_'\|'\bl2_'\|'\bl3_'\|'\binternalnet_' /etc/virl.ini)
printf "%s\n>>> VIRL Config Summary <<<\n$vini" >> $_out 2>&1
}

function _saltst
{
# _out=SrvValTest.txt
printf "%s\nCheckin Salt Configuration...%s\n"
sleep 1
# rm ~/$_out >& /dev/null
# touch ~/$_out
mstr=$(sudo salt-call --local grains.get salt_master)
lic=$(sudo salt-call --local grains.get id)
printf "%s\nConfigured Salt masters:\n $mstr%s\n"
printf "%s\nConfigured Salt ID:\n $lic%s\n"
printf "%s\n\nSalt Masters\n $mstr %s\n"  >> $_out 2>&1
printf "%s\nSalt ID\n $lic %s\n"  >> $_out 2>&1
egrep  -o -w '\bus-[1-4].virl.info'\|'\beu-[1-4].virl.info' /etc/virl.ini | while read srv
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


_out=~/SrvValTest.txt
_result
_netint
_saltst
