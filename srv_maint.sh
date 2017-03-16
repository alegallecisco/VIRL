#!/bin/bash
PROGNAME=$(basename $0)
## This script is meant for simple information gathering
## of your VIRL server. It also will assist with configuring
## a static IP address. Using UWM for system configuration
## is the recommended method and should always be used when
## making system changes.
##
## Created by: alejandro gallego (alegalle@cisco.com)
## Last Updated: Jan 23, 2016
##

trap int_exit INT

function int_exit
{
        echo "${PROGNAME}: Aborted by user"
        exit
}

function _cont
{
	echo ""
	echo -n "Continue? (y/n) "
	read _resp
	_resp
}

function _resp
{
	until [ "$_resp" = "y" ]; do
    echo -n "Continue? (y/n) "
    read _resp
        case $_resp in
            y ) _resp=y ;;
            n ) clear ; menu ;;
            * ) printf "Please enter a \"y\" or \"n\"%s\n\n" ;;
        esac
    done
}

function press_enter
{
	echo ""
	echo -n "Press enter to continue"
	read
	clear
}

function _svc
{
for x in mysql keystone glance-api nova-api neutron-server
do
        echo ""
        echo Checking Service: $x
        sudo service $x status
        echo ""
done
}

function _opnstk-agnt
{
printf "\nNeutron Agent%s\n"
for n in agent-list net-list
do
	neutron $n
done

printf "\nKeystone Agents%s\n"
for s in endpoint-list service-list
do
	keystone $s
done

printf "\nNova Agents%s\n"
for n in endpoints service-list
do
    nova $n
done
}

function _opnstk-reset
{
	sudo vinstall vinstall
    sudo salt-call saltutil.sync_all
    sudo vinstall salt
    sudo salt-call -l debug state.sls openstack
    sudo salt-call -l debug state.sls openstack.setup
    sudo salt-call -l debug state.sls openstack-restart
	sudo salt-call -l debug state.sls virl.openrc
}

function _opnstk-restrt
{
	sudo salt-call -l debug state.sls openstack-restart
}

function _verchk
{
printf "%6s>>> Openstack / System Versions <<<\n"
printf "VIRL Release:$ver\n" && sudo pip list | grep VIRL
printf "\nOS Info:\n%s\n\n" $lver
printf "%6s>>> OpenStack Versions <<<\n"
printf "%14sOpenstack: %s" && openstack --version 2> /dev/null
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

function _sltimgchk
{
rm ~/sltImgVer.txt >& /dev/null
for srv in ${mstr//,/ }
    do
    printf "\nRequesting image version from SALT Master: [%s]\n" "$srv"
    sudo salt-call -l debug --master $srv state.sls virl.routervms test=TRUE >& /tmp/img_$srv.txt
    done
for srv in ${mstr//,/ }
    do
    printf "\nComparing versions available on SALT Master: [%s]\n" "$srv"
    printf "\nSALT Master: $srv\n" >> ~/sltImgVer.txt 2>&1 && grep -e "m_name: " -e "property-release: " /tmp/img_$srv.txt >> ~/sltImgVer.txt 2>&1
    done
    printf "\nResults have been written text file \"~/sltImgVer.txt\"
    located in virl user home directory\n"
rm /tmp/img_*.txt
}

function _messg
{
printf "\nResults printed to file \"%s\" in
    \"virl user's home directory\"%s\n" "$_out"
sleep 2
}

function _result
{
rm $_out >& /dev/null
touch $_out
echo "Checking server configuration!
Please wait...."
}

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

printf "\nBridge Info: \n %s\n" "$lbrdg"
vini=$(egrep '\bsalt_'\|'\bhost'\|'\bdomain'\|'\bpublic_'\|'\bStatic_'\|'\busing_'\|'\bl2_'\|'\bl3_'\|'\bdummy_'\|'\bvirl_'\|'\binternalnet_'\|'_nameserver' /etc/virl.ini)
printf "\n%6s>>> VIRL Config Summary <<<\n$vini"
}

function _saltst
{
printf "\nCheckin Salt Configuration...\n"
sleep 1
printf "\nConfigured Salt masters:\n %s\n" "$mstr"
printf "\nConfigured Salt ID:\n%s\n" "$lic"
for srv in ${mstr//,/ }
    do
    idig=$(dig $srv | egrep -o '([0-9]+\.){3}[0-9]+' |head -1)
    if [ $? -ne 1 ] ; then
    printf "\nTesting Connectivity to: [%2s : %s]\n" "$srv" "$idig"
    nc -zv $srv 4505-4506
    echo ""
    printf "\nChecking License....%s"
    printf "\nAuth test --> Salt Server [%s]\n" "$srv"
    sudo salt-call --master $srv -l debug test.ping
    else
    printf "\nUnable to resolve %s Please check your connection.\n" "$srv"
    fi
    done

printf "%s\nChecking hostname and network interfaces: %s\n"
sleep 2
    for h in /etc/hostname /etc/hosts /etc/network/interfaces
    do
        printf "\n>>> %s <<<\n" "$h"
        cat $h
    done
sleep 2
}

## .--------------------------------. ##
## |IP Address config section START | ##
## .--------------------------------. ##

function _askstatic
{
clear
_adns=0
while true; do
    cat <<EOF

    ******************* CAUTION *******************
     There is no syntax validation here. Take care
     when entering network information.
    ******************* CAUTION *******************

EOF
    read -p "Enter static IP: " ip
    read -p "Enter network ID: (ex. 172.16.1.0 for a /24 network) " ntid
    read -p "Enter netmask: (dotted format) " msk
    read -p "Enter default gateway: " gw
    until [ $_adns = y ]; do
        read -p "Specify custom DNS servers: (optional) \"y or n\" " _adns
    	case $_adns in
        	[Yy] ) _adns=y ; _askdns ;;
            [xn] ) break ;;
            [*] ) printf "%s\nPlease enter a \"y\" or \"n\"%s\n" ;;
        esac
    done
    echo "Please double check your network information:
    IP: $ip
    Network: $ntid
    Netmask: $msk
    Gateway: $gw
    Pri DNS: $dns1
    Sec DNS: $dns2
    "
    read -p "Apply these settings? (y)es to apply, (n)o to re-enter or e(x)it:  " crt
    case $crt in
        y ) _setstatic ; break ;;
        n ) _askstatic ; break ;;
        x ) clear ; menu ;;
        * ) printf "\nPlease enter a \"y\" \"n\" or \"x\"\n" ;;
    esac
done
}

function _askdns
{
    read -p "Primary DNS server: " dns1
    read -p "Secondary DNS server: " dns2
}

function _setstatic
{
    sudo cp /etc/virl.ini /etc/virl.ini.orig
    printf "\nSetting network information, please wait...!\n"
        sudo crudini --set --existing /etc/virl.ini DEFAULT using_dhcp_on_the_public_port False
    if [[ ! -z  $ip ]]; then
        sudo crudini --set --existing /etc/virl.ini DEFAULT Static_IP $ip
        echo "Static IP set...    $ip"
        else
        echo "No Change... skipping!"
    fi
    if [[ ! -z $ntid ]]; then
        sudo crudini --set --existing /etc/virl.ini DEFAULT public_network $ntid
        echo "Network ID set...   $ntid"
        else
        echo "No Change... skipping!"
    fi
    if [[ ! -z $msk ]]; then
        sudo crudini --set --existing /etc/virl.ini DEFAULT public_netmask $msk
        echo "Netmask set...      $msk"
        else
        echo "No Change... skipping!"
    fi
    if [[ ! -z $gw ]]; then
        sudo crudini --set --existing /etc/virl.ini DEFAULT public_gateway $gw
        echo "Gateway set...      $gw"
        else
        echo "No Change... skipping!"
    fi
    if [[ ! -z $dns1 ]]; then
        sudo crudini --set --existing /etc/virl.ini DEFAULT first_nameserver $dns1
        echo "Name servers set...
        $dns1"
        else
        echo "No Change Pri DNS... skipping!"
    fi
    if [[ ! -z $dns2 ]]; then
        sudo crudini --set --existing /etc/virl.ini DEFAULT second_nameserver $dns2
        echo "
        $dns2"
        else
        echo "No Change Sec DNS2... skipping!"
    fi
        #press_enter
echo ""
echo "You MUST run \"Commit\" (Opt. 9) to finalize settings"
}

function _commit
{
cat <<EOF

   +---------------------------------+
   |  ********** WARNING **********  |
   | YOU CANNOT STOP THIS PROCESS!   |
   | Once the reset has started wait |
   | for reboot message.             |
   | If you cancel or close your     |
   | terminal application once the   |
   | process has started,you may     |
   | have to re-deploy your VIRL     |
   | Server from OVA or ISO file.    |
   +---------------------------------+

   You are about to apply new system
   settings. Applying settings can
   take about 15 min. to complete.

   You MUST reboot when prompted!

EOF
_resp
if [ $? -ne 1 ] ; then
    tstmp=$(date +%R_%m%d%Y)
    sudo touch /var/local/virl/rehost.log
    sudo mv /var/local/virl/rehost.log /var/local/virl/$tstmp-rehost.log
    sudo salt-call -l debug state.sls virl.vinstall
    sudo vinstall rehost
    else
    menu
fi

}

## .--------------------------------. ##
## | IP Address config section END  | ##
## .--------------------------------. ##

function _rstr-vini
{
cat <<EOF
    You are about to reset your VIRL server to default state.
    All settings, including license information will be removed.
    No files or topologies will be deleted, only operational
    settings are restored. If you do not have DHCP server
    available, you will have to use the console to manage your
    VIRL server!

   +---------------------------------+
   |  ********** WARNING **********  |
   | YOU CANNOT STOP THIS PROCESS!   |
   | Once the reset has started wait |
   | for reboot message.             |
   | If you cancel or close your     |
   | terminal application once the   |
   | process has started,you may     |
   | have to re-deploy your VIRL     |
   | Server from OVA or ISO file.    |
   +---------------------------------+
EOF
_resp

if [ $? -ne 1 ] ; then
tstmp=$(date +%R_%m%d%Y)
    sudo cp /etc/virl.ini /etc/$tstmp.virl.ini && cp /etc/orig.virl.ini /etc/virl.ini
fi

_commit

cat <<EOF
    VIRL Settings restored to default!
    You will need to reboot your server now.

        sudo reboot now

    After reboot you will need to re-configure your server
    as a new deployment.
EOF
}


function menu
{
selection=
until [ "$selection" = "0" ]; do
	echo ""
	echo "***** Server Inspector ******"
	echo "1 - VIRL Server Config Validation"
	echo "2 - Openstack Services Check"
	echo "3 - Openstack Agents Check"
	echo "4 - List Package Versions"
	echo "5 - Server Maintenance"
	echo "0 - Exit"
	echo ""
	echo -n "Enter selection: "
	read selection
	echo ""
	case $selection in
		1 ) _result ; _verchk >> $_out 2>&1 ; _netint >> $_out 2>&1 ; _saltst >> $_out 2>&1 ; _messg ; press_enter ;;
		2 ) _svc ; press_enter ;;
		3 ) _opnstk-agnt ; press_enter ;;
		4 ) _verchk ; press_enter ;;
		5 ) clear ; maint ;;
		0 ) _resp ; clear ;; # exit 0 ;;
		* ) echo "Please select from the menu" ; press_enter ;;
	esac
done
}

function maint
{
selection=
until [ "$selection" = "0" ]; do
	echo ""
	echo "***** Server Maintenance ******"
	echo "1 - Restart Openstack Services"
	echo "2 - Verify Image Version Sync"
	echo "3 - Set Static IP Address"
	echo "4 - Commit Network Changes"
	echo "4.1 - Restore Default Settings"
	echo "5 - Server Inspector"
	echo "0 - Exit"
	echo ""
	echo -n "Enter selection: "
	read selection
	echo ""
	case $selection in

		1 ) _opnstk-restrt ; press_enter ;;
		2 ) _sltimgchk ; press_enter ;;
		3 ) _askstatic ; press_enter ;;
		4 ) _commit ; press_enter ;;
		4.1 ) _rstr-vini ; press_enter ;;
		5 ) clear ; menu ;;
		0 ) _resp ; clear ;; # exit 0 ;;
		* ) echo "Please select from the menu" ; press_enter ;;
	esac
done
}

clear

if [[ $(id) =~ ^uid=0 ]]; then
	cat << EOF

	Don't run this as root (e.g. with "sudo"). If the script needs to make
	changes as root, you will be prompted for your password!

EOF
exit 0
fi


_out=~/SrvValTest.txt
mstr=$(sudo salt-call --local grains.get salt_master | egrep -v local: )
lic=$(sudo salt-call --local grains.get id)
lbrdg=$(brctl show)
menu


# awk '{match($0,/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/); ip = substr($0,RSTART,RLENGTH); print ip}'

