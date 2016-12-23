#!/bin/bash

## This script is meant for simple information gathering
## of your VIRL server. It also will assist with configuring
## a static IP address. Using UWM for system configuration
## is the recommended method and should always be used when
## making system changes.
##
## Created by: alejandro gallego (alegalle@cisco.com)
## Last Updated: Dec 22, 2016
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
}

function _resp
{
	#echo ""
	#echo -n "Continue? (y/n) "
	#read _resp
	_resp=r
	until [ $_resp == "y" ]; do
    		case $_resp in
        	y ) _resp=y ;;
            n ) clear ; menu ;;
            * ) printf "%s\nPlease enter a \"y\" or \"n\"%s\n" ; _cont ;;
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
printf "%s\nNeutron Agent%s\n"
for n in agent-list net-list
do
	neutron $n
done

printf "%s\nKeystone Agents%s\n"
for s in endpoint-list service-list
do
	keystone $s
done

printf "%s\nNova Agents%s\n"
for n in endpoints service-list
do
    nova $n
done
}

function _opnstk-restrt
{
	sudo salt-call -l debug state.sls openstack-restart
}

function _verchk
{
echo ">>>Openstack Installed Versions<<<"
printf "%s\nNova Common: $(dpkg-query -s nova-common | grep Version)\n%sNeutron Common: $(dpkg-query -s neutron-common | grep Version)\n\n"
printf "%s\nNova Version: %s\n"
nova --version
printf "%s\nKeystone Version: %s\n"
keystone-all --version
echo ""
echo ">>>>VIRL Versions<<<<"
printf "%s\nMinion Ver: %s\n"
sudo salt-minion --versions
printf "%s\nUWM Client Ver: %s\n"
sudo virl_uwm_client version
printf "%s\nVIRL Release: %s\n"
sudo salt-call --local grains.get virl_release
echo ""
}

function _sltimgchk
{
rm ~/sltImgVer.txt >& /dev/null
egrep  -o -w '\bus-[1-4].virl.info'\|'\beu-[1-4].virl.info' /etc/virl.ini | while read srv
    do
    printf "%s\nRequesting image version from SALT Master: [$srv]%s\n"
    sudo salt-call -l debug --master $srv state.sls virl.routervms test=TRUE >& /tmp/img_$srv.txt
    done
egrep  -o -w '\bus-[1-4].virl.info'\|'\beu-[1-4].virl.info' /etc/virl.ini | while read srv
    do
    printf "%s\nComparing versions available on SALT Master: [$srv]%s\n"
    printf "%s\nSALT Master: $srv\n" >> ~/sltImgVer.txt 2>&1 && grep -e "m_name: " -e "property-release: " /tmp/img_$srv.txt >> ~/sltImgVer.txt 2>&1
    done
    printf "%s\nResults have been written text file \"~/sltImgVer.txt\"
    located in virl user home directory%s\n"
rm /tmp/img_*.txt
}

function _result
{
# _out=~/SrvValTest.txt
clear
printf "%s\nResults printed to file \"$_out\" in
    \"virl user's home directory\"%s\n"
sleep 2
rm $_out >& /dev/null
touch $_out
_netint
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
_saltst
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
    if [ $? -ne 1 ] ; then
    printf "%s\nTesting Connectivity to: [$srv $idig]%s"
    printf "%s\n>>>> $srv :: $idig\n" >> $_out 2>&1 && nc -zv $srv 4505-4506 >> $_out 2>&1
    echo ""
    printf "%s\nChecking License....%s"
    printf "%s\nAuth test --> Salt Server [$srv]%s\n"
    printf "%s\n>>>> $srv\n" >> $_out 2>&1 && sudo salt-call --master $srv -l debug test.ping >> $_out 2>&1
    else
    printf "%s\nUnable to resolve $srv Please check your connection.%s\n"
    fi
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
        * ) printf "%s\nPlease enter a \"y\" \"n\" or \"x\"%s\n" ;;
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
    printf "%s\nSetting network information, please wait...!%s\n"
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
##    sudo vinstall salt
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
	echo "4 - Restart Openstack Services"
	echo "5 - List Package Versions"
	echo "6 - Verify Image Version Sync"
##	echo "7 - "
	echo "8 - Set Static IP Address"
	echo "9 - Commit Network Changes"
	echo "9.1 - Restore Default Settings"
	echo "0 - Exit"
	echo ""
	echo -n "Enter selection: "
	read selection
	echo ""
	case $selection in
		1 ) _result ; press_enter ;;
		2 ) _svc ; press_enter ;;
		3 ) _opnstk-agnt ; press_enter ;;
		4 ) _opnstk-restrt ; press_enter ;;
		5 ) _verchk ; press_enter ;;
		6 ) _sltimgchk ; press_enter ;;
		8 ) _askstatic ; press_enter ;;
		9 ) _commit ; press_enter ;;
		9.1 ) _rstr-vini ; press_enter ;;
		0 ) clear ; exit 0 ;;
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
menu


# awk '{match($0,/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/); ip = substr($0,RSTART,RLENGTH); print ip}'

