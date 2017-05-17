#!/bin/bash
## This script will collect key parts of your VIRL server configuration settings and
## place them into a single file (SrvValTest.txt). This file can be collected and
## forwarded to VIRL support community for assistance.
## Validation script created by alejandro gallego (alegalle@cisco.com)
## Last modified on May 15, 2017
##
## Current version supports Openstack Kilo, Mitaka
##
## TEMP_FILE=/tmp/${PROGNAME}.$$.$RANDOM

function int_exit
{
	echo "${PROGNAME}: Aborted by user"
	exit
}

function term_exit
{
	echo "${PROGNAME}: Terminated"
	exit
}

## Results of commands in script are sent to text file. The text file
## will be found under the default username 'virl' home directory.
function _result
{
    rm $_out >& /dev/null
    touch $_out
    echo "Checking server configuration!
    Please wait...."
}

function _messg
{
    printf "\nResults printed to file \"%s\" in
    \"virl user's home directory\"\n" "$_out"
    sleep 2
}

## Deployment type checks for VMware PCI devices
function _dtype
{
	$tstmp >> $_out 2>&1
	lspci |grep ' peripheral: VMware' > /dev/null
	if [[ $? -ne 0 ]] ; then
		printf "\nInstallation Type: \"OTHER\"\n"
		else
			printf "\nInstallation Type: \"OVA\"\n\n"
	fi
}

## Checking installed version of typical packages
function _verchk
{
	format="\n %-25s %10s\n"
	printf "%6s>>> Openstack / System Versions <<<\n"
	printf "%sVIRL Release:$ver\n" && sudo pip list | grep VIRL
	printf "%s\nOS Info:\n$lver\n\n"
	printf "%6s>>> OpenStack Versions <<<\n"
	printf "%15sOpenstack: %s" && openstack --version
	printf "%17sNeutron: %s" && neutron --version
	printf "%20sNova: %s" && nova --version
	printf "%6s>>> Python Modules <<<\n"
	declare iver=($(sudo pip list | egrep '\bautonetkit'\|'\bvirl-'))
	    echo "              AutoNetkit:  ${iver[1]}"
	    echo "        AutoNetkit Cisco:  ${iver[3]}"
	    echo "       Topology Vis Eng.:  ${iver[5]}"
	    echo "Live Net Collection Eng.:  ${iver[7]}"
	    echo ""
	printf "%6s>>>> Salt Version <<<<\n"
	printf "%s$(sudo salt-minion --versions)\n"
	echo ""
}

## Check openstack command version
function _o
{
	grep -i xenial /etc/os-release > /dev/null 2>&1
	if [ $? -ne 0 ]; then
	    _kostack >> $_out 2>&1
	    else
	    _ostack >> $_out 2>&1
	fi
}

## Display Openstack server information
function _ostack
{
	printf "%6s>>> Openstack Info / Stats <<<<"
	printf "\n%5sVIRL Host \n%s" && openstack host show virl
	printf "\n%5sVIRL Images \n%s" && openstack image list
	printf "%23s\n%s\n%s\n" "OpenStack Networking" "$ntrn" "$ntrnsub"
	printf "%20s\n%s\n" "OpenStack Nova" "$nva"
	printf "%20s\n%s\n" "OpenStack User(s)" "$kstn"
	printf "\n%5sVIRL Hypervisor \n%s" && openstack hypervisor stats show
	printf "\n%5sOpenStack Services \n%s" && openstack service list --long
}

function _kostack
{
	printf "%6s>>> Openstack Info / Stats <<<<"
	printf "\n%5sVIRL Host \n%s" && nova host-list
	printf "\n%5sVIRL Images \n%s" && nova image-list
	printf "%23s\n%s\n%s\n" "OpenStack Networking" "$ntrn" "$ntrnsub"
	printf "%20s\n%s\n" "OpenStack Nova" "$nva"
	printf "%20s\n%s\n" "OpenStack User(s)" "$kstn"
	printf "\n%5sVIRL Hypervisor \n%s" && nova hypervisor-stats
}


## Network information checks for configured interfaces, compares assigned MAC addr. to HW Mac addr.
## and looks for "link" detection of reported interfaces.
function _netint
{
	printf "\n%6s>>>  VIRL Server Networking <<<\n\n"
	ifquery --list | egrep -v lo | sort | while read intf
	do
	ipadr=$(ip addr show dev $intf 2> /dev/null | awk '$1 == "inet" { sub("/.*", "", $2); print $2 }' )
	mac=$(ip link show $intf 2> /dev/null | awk '/ether/ {print $2}' )
	hwmac=$(cat /sys/class/net/$intf/address 2> /dev/null )
	    printf "%s CONFIGURED\n" "$intf"
		printf "MAC: %s\n" "$mac"
		printf "HW:  %s\n" "$hwmac"
	    ip link show $intf > /dev/null 2>&1
	        if [ $? -ne 0 ] ; then
	        printf ">>> Interface %s DOWN\n" "$intf"
	        else
	        printf "IP: %s\n" "$ipadr"
	        echo ""
	        fi
	done
## Print summary
	printf "\nBridge Info: \n %s\n" "$lbrdg"
	vini=$(egrep '\bsalt_'\|'\bhost'\|'\bdomain'\|'\bpublic_'\|'\bStatic_'\|'\busing_'\|'\bl2_'\|'\bl3_'\|'\bdummy_'\|'\bvirl_'\|'\binternalnet_'\|'_nameserver' /etc/virl.ini)
	printf "\n>>> VIRL Config Summary <<<\n%s" "$vini"
	printf "\nChecking hostname and network interfaces...\n"
	sleep 2
    for h in /etc/hostname /etc/hosts /etc/network/interfaces
    do
        printf "\n>>> %s <<<\n" "$h"
        cat $h
    done
}

## Salt test will check configured salt servers, connectivity to configured salt servers, and license validation.
## License validation only checks to see if configured license is accepted not expiry or syntax.
function _saltst
{
	printf "\n%s\n" "Checking Salt Configuration..."
	sleep 1
	printf "\nNTP Peers:\n %s\n" "$_ntp"
	printf "\nConfigured Salt masters:\n %s\n" "$mstr"
	printf "\nConfigured Salt ID:\n %s\n" "$lic"
	for srv in ${mstr//,/ }
	    do
			idig=$(dig $srv | egrep -o '([0-9]+\.){3}[0-9]+' |head -1)
		    printf "\nTesting Connectivity to: [%3s %s]\n" "$srv" "$idig"
		    nc -zv $srv 4505-4506
		    echo ""
		    printf "\nChecking License....[ %s ]\n" $lic
		    printf "\nAuth test --> Salt Server [ %s ]\n" "$srv"
		    sudo salt-call --master $srv -l debug test.ping
	    done
}

PROGNAME=$(basename $0)
trap term_exit TERM HUP
trap int_exit INT

## Global vars
tstmp=$(date +%H.%M_%Y.%m.%d)
_ntp=$(ntpq -p)
ntrn=$(neutron agent-list)
ntrnsub=$(neutron subnet-list)
nva=$(nova service-list)
kstn=$(keystone user-list | grep -v "WARNING" 2> /dev/null)
ver=$(sudo salt-call --local grains.get virl_release | egrep -v 'local:')
lver=$(lsb_release -a 2> /dev/null)
lbrdg=$(brctl show)
mstr=$(sudo salt-call --local grains.get salt_master | egrep -v 'local:' )
lic=$(sudo salt-call --local grains.get id | egrep -v 'local:' )
_out=~/SrvValTest.txt
###

rm $_out >& /dev/null
touch $_out
_result
echo "Checking deployment type...."
_dtype >> $_out 2>&1
echo "Checking installed versions...."
_verchk >> $_out 2>&1
_o
echo "Checking networking configuration...."
_netint >> $_out 2>&1
echo "Checking salt connectivity and license...."
_saltst >> $_out 2>&1
echo "
DONE...."
_messg
# sleep 5
