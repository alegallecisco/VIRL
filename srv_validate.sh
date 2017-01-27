#!/bin/bash
PROGNAME=$(basename $0)

## This script will collect key parts of your VIRL server configuration settings and
## place them into a single file (SrvValTest.txt). This file can be collected and
## forwarded to VIRL support community for assistance.
## Validation script created by alejandro gallego (alegalle@cisco.com)
## Last modified on Jan 27, 2017
##
## Current version supports Openstack Kilo, Mitaka
##

## TEMP_FILE=/tmp/${PROGNAME}.$$.$RANDOM


function int_exit
{
        echo "${PROGNAME}: Aborted by user"
        exit
}

## Results of commands in script are sent to text file. The text file
## will be found under the default username 'virl' home directory.
function _result
{
printf "%s\nResults printed to file \"$_out\" in
    \"virl user's home directory\"%s\n"
sleep 1
}

## Deployment type checks for VMware PCI devices
function _dtype
{
lspci |grep ' peripheral: VMware' > /dev/null
if [[ $? -ne 0 ]] ; then
    printf "%s\nInstallation Type: \"OTHER\"\n"
else
printf "%s\nInstallation Type: \"OVA\"\n\n"
fi
}

## Checking installed version of typical packages
function _verchk
{
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
printf "%6s>>> >Salt Version <<<<\n"
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
printf "\n%5sVIRL Host %s\n" && openstack host show virl
printf "\n%5sVIRL Images %s\n" && openstack image list
printf "\n%5sOpenStack Neutron%s\n$ntrn\n"
printf "\n%5sOpenStack Nova %s\n$nva\n"
printf "\n%5sVIRL Hypervisor %s\n" && openstack hypervisor stats show
printf "\n%5sOpenStack Services %s\n" && openstack service list --long
}

function _kostack
{
printf "%6s>>> Openstack Info / Stats <<<<"
printf "\n%5sVIRL Host %s\n" && nova host-list
printf "\n%5sVIRL Images %s\n" && nova image-list
printf "\n%5sOpenStack Neutron%s\n$ntrn\n"
printf "\n%5sOpenStack Nova %s\n$nva\n"
printf "\n%5sVIRL Hypervisor %s\n" && nova hypervisor-stats
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
    printf "%s$intf CONFIGURED"
	printf "%s\nMAC: $mac\n"
	printf "%sHW:  $hwmac\n"
    ip link show $intf > /dev/null 2>&1
        if [ $? -ne 0 ] ; then
        printf ">>> %sInterface $intf DOWN%s\n"
        else
        printf "IP: $ipadr\n"
        echo ""
        fi
done

printf "%s\nBridge Info: \n $lbrdg%s\n"
vini=$(egrep '\bsalt_'\|'\bhost'\|'\bdomain'\|'\bpublic_'\|'\bStatic_'\|'\busing_'\|'\bl2_'\|'\bl3_'\|'\bdummy_'\|'\bvirl_'\|'\binternalnet_'\|'_nameserver' /etc/virl.ini)
printf "\n%6s>>> VIRL Config Summary <<<\n$vini"
}

## Salt test will check configured salt servers, connectivity to configured salt servers, and license validation.
## License validation only checks to see if configured license is accepted not expiry or syntax.
function _saltst
{
printf "%s\nCheckin Salt Configuration...%s\n"
sleep 1
printf "%s\nConfigured Salt masters:\n $mstr%s\n"
printf "%s\nConfigured Salt ID:\n $lic%s\n"
for srv in ${mstr//,/ }
    do
    idig=$(dig $srv | egrep -o '([0-9]+\.){3}[0-9]+' |head -1)
    printf "%s\nTesting Connectivity to: [$srv $idig]%s\n"
    nc -zv $srv 4505-4506
    echo ""
    printf "%s\nChecking License....%s"
    printf "%s\nAuth test --> Salt Server [$srv]%s\n"
    sudo salt-call --master $srv -l debug test.ping
    done

printf "%s\nChecking hostname and network interfaces: %s\n"
sleep 2
    for h in /etc/hostname /etc/hosts /etc/network/interfaces
    do
        printf "%s\n>>> $h <<<%s\n"
        cat $h
    done
}

## Global vars
ntrn=$(neutron agent-list)
nva=$(nova service-list)
ver=$(sudo salt-call --local grains.get virl_release | egrep -v 'local:')
lver=$(lsb_release -a 2> /dev/null)
lbrdg=$(brctl show)
mstr=$(sudo salt-call --local grains.get salt_master | egrep -v 'local:' )
lic=$(sudo salt-call --local grains.get id | egrep -v 'local:' )
_out=~/SrvValTest.txt
###

rm $_out >& /dev/null
touch $_out
trap int_exit INT
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
_result
# sleep 5