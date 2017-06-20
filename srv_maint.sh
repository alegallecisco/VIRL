#!/bin/bash
PROGNAME=$(basename $0)
## This script is meant for simple information gathering
## of your VIRL server. It also will assist with configuring
## a static IP address. Using UWM for system configuration
## is the recommended method and should always be used when
## making system changes.
## Functions: netcal, mask2cidr, bcastcal adapted from:
##    http://www.linuxquestions.org/questions/programming-9/bash-cidr-calculator-646701/page2.html
##
## Created by: alejandro gallego (alegalle@cisco.com)
## Last Updated: May 17, 2017
##

function int_exit
{
        echo "  ${PROGNAME}:  Aborted by user"
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
#    clear
}

function _svc
{
    for x in mysql keystone glance-api nova-api neutron-server
    do
        printf "\nChecking Service: %s \n" $x
        sudo service $x status
    done
}

function _opnstk-agnt
{
    printf "\nNeutron Agents\n"
    for n in agent-list net-list
    do
        neutron $n
    done
    printf "\nKeystone Agents\n"
    for s in endpoint-list service-list
    do
        keystone $s
    done
    printf "\nNova Agents\n"
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
    sudo salt-call -l debug state.sls openstack.restart
    sudo salt-call -l debug state.sls virl.openrc

    echo -en "\nA reboot is recommended but not required.\nContinuing will reboot your server!"'\n'
    _resp
    sudo reboot now
}

function _opnstk-restrt
{
    sudo salt-call -l debug state.sls openstack.restart
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
    \"virl user's home directory\"\n" "$_out"
    sleep 2
}

function _result
{
    rm $_out >& /dev/null
    touch $_out
    echo "Checking server configuration!
    Please wait...."
}

function _dtype
{
    echo $tstmp
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
## Mitaka Openstack
function _ostack
{
    printf "%6s>>> Openstack Info / Stats <<<<"
    printf "\n%5sVIRL Host \n%s" && openstack host show virl
    printf "\n%5sVIRL Images \n%s" && openstack image list
    printf "%23s\n%s\n%s\n" "OpenStack Networking" "$ntrn" "$ntrnsub"
    printf "%20s\n%s\n" "OpenStack Nova" "$nva"
    printf "%20s\n%s\n" "OpenStack User(s)" && openstack user list
    printf "\n%5sVIRL Hypervisor \n%s" && openstack hypervisor stats show
    printf "\n%5sOpenStack Services \n%s" && openstack service list --long
}

## Kilo Openstack
function _kostack
{
kstn=$(keystone user-list | grep -v "WARNING" 2> /dev/null)
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
            printf "\nAuth test --> Salt Server [%s]\n" "$srv"
            sudo salt-call --master $srv -l debug test.ping
        done
}

## .--------------------------------. ##
## |IP Address config section START | ##
## .--------------------------------. ##

function _askstatic
{
clear
sudo timeout 6s sudo salt-call test.ping > /dev/null 2>&1
if [ $? -ne 0 ]; then
    printf "Your server may not be properly licensed.\nCheck your license via UWM before using this script."
    press_enter
    maint
fi

_adns=0

    cat <<EOF

    ******************** WARNING *********************
     There is no syntax validation here. Use extreme
     caution when entering network information.
    ******************** WARNING *********************

EOF
    read -p "Enter static IP: " ip
    read -p "Enter netmask (ex. 255.255.255.0): " msk
    #read -p "Enter network ID (ex. 172.16.1.0 for a /24 network): " ntid
    read -p "Enter default gateway: " gw
    until [ "$_adns" = "y" ]; do
        read -p "Specify custom DNS servers: (optional) \"y or n\" " _adns
        case $_adns in
            [y] ) _adns=y ; _askdns ;;
            [n] ) break ;;
            [*] ) printf "\nPlease enter a \"y\" or \"n\"\n" ;;
        esac
    done
    _netcalc "$ip" "$msk"
    _mask2cidr "$msk"

    if [ -z $cidr ]; then
    press_enter
    _askstatic
    fi

    echo "Please double check your network information:
    IP:      $ip /$cidr
    Network: $ntid
    Netmask: $msk
    Gateway: $gw
    Pri DNS: $dns1
    Sec DNS: $dns2
    "

    until [ "$crt" = "y || n || x" ]; do
    read -p "Apply these settings? (y)es to apply, (n)o to re-enter or e(x)it:  " crt
        case $crt in
            y ) _setstatic ; break ;;
            n ) _askstatic ; break ;;
            x ) clear ; menu ;;
            * ) printf "\nPlease enter a \"y\" \"n\" or \"x\"\n" ;;
        esac
    done

}

function _netcalc
{
    local IFS='.' nip i
    local -a oct nmsk

    read -ra oct <<<"$1"
    read -ra nmsk <<<"$2"

    for i in ${!oct[@]}; do
        nip+=( "$(( oct[i] & nmsk[i] ))" )
    done
    ntid=${nip[*]}
    #echo "${ip[*]}"
}

function _mask2cidr
{
    local nbits dec
    local -a octets=( [255]=8 [254]=7 [252]=6 [248]=5 [240]=4
                      [224]=3 [192]=2 [128]=1 [0]=0           )

    while read -rd '.' dec; do
        [[ -z ${octets[dec]} ]] && echo "Error: $dec is not a valid entry!" && break
        (( nbits += octets[dec] ))
        (( dec < 255 )) && break
    done <<<"$1."
    cidr=$nbits

}

function _bcastcalc
{
    local IFS='.' ip i
    local -a oct msk

    read -ra oct <<<"$1"
    read -ra msk <<<"$2"

    for i in ${!oct[@]}; do
        ip+=( "$(( oct[i] + ( 255 - ( oct[i] | msk[i] ) ) ))" )
    done

    echo "Braodcast IP: ${ip[*]}"
    ## _bcastcalc "$1" "$2"
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
        if [[ $? -eq 1 ]]; then
        sudo crudini --set /etc/virl.ini DEFAULT Static_IP $ip
        fi
        echo "Static IP set...    $ip"
        else
        echo "No Change... skipping!"
    fi
    if [[ ! -z $ntid ]]; then
        sudo crudini --set --existing /etc/virl.ini DEFAULT public_network $ntid
        if [[ $? -eq 1 ]]; then
        sudo crudini --set /etc/virl.ini DEFAULT public_network $ntid
        fi
        echo "Network ID set...   $ntid"
        else
        echo "No Change... skipping!"
    fi
    if [[ ! -z $msk ]]; then
        sudo crudini --set --existing /etc/virl.ini DEFAULT public_netmask $msk
        if [[ $? -eq 1 ]]; then
        sudo crudini --set /etc/virl.ini DEFAULT public_netmask $msk
        fi
        echo "Netmask set...      $msk"
        else
        echo "No Change... skipping!"
    fi
    if [[ ! -z $gw ]]; then
        sudo crudini --set --existing /etc/virl.ini DEFAULT public_gateway $gw
        if [[ $? -eq 1 ]]; then
        sudo crudini --set /etc/virl.ini DEFAULT public_gateway $gw
        fi
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
echo ""
echo "You must reboot your server to apply settings!"
}

function _commit
{

cat <<EOF

   +---------------------------------+
   |  ********** WARNING **********  |
   | DO  NOT  STOP  THIS  PROCESS!   |
   | Once the reset has started wait |
   | for reboot message.             |
   | If you cancel or close your     |
   | terminal application once the   |
   | process has bagun,you may have  |
   | to re-deploy your VIRL Server.  |
   +---------------------------------+

   You are about to apply new system
   settings. Applying settings can
   take about 15 min. to complete.

   You MUST reboot when prompted!

EOF
press_enter

touch ~/$tstmp.rehost.log
sudo salt-call --local --log-file ~/$tstmp.vinstall.log --log-file-level debug state.sls virl.vinstall
sudo timeout 6s sudo salt-call test.ping > /dev/null 2>&1
if [ $? -ne 0 ] ; then
    printf "Your server may not be properly licensed.\nYou must rehost once a valid license has been applied!"
    press_enter
    maint
fi

sudo vinstall rehost | tee ~/$tstmp.rehost.log
echo "Press enter to continue with system reboot!"
# sudo reboot now
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
   | DO  NOT  STOP  THIS  PROCESS!   |
   | Once the reset has started wait |
   | for reboot message.             |
   | If you cancel or close your     |
   | terminal application once the   |
   | process has bagun,you may have  |
   | to re-deploy your VIRL Server.  |
   +---------------------------------+
EOF
_resp

    if [ $? -ne 1 ] ; then
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
mgmt=$(awk '$2 == 00000000 { print $1 }' /proc/net/route)
maddr=$(ip addr show dev $mgmt | awk '$1 == "inet" { sub("/..", "", $2); print $2}')
selection=

until [ "$selection" = "0" ]; do

ifquery --list | egrep -v lo | sort | while read intf
do
ipadr=$(ip addr show dev $intf |awk '$1 == "inet" { sub("/..", "", $2); print $2}')
   ip link show $intf > /dev/null 2>&1
        if [ $? -ne 0 ] ; then
        printf ">>>>Interface %s:  DOWN\n" $intf
        else
        printf "%s: %s\n" $intf $ipadr
        fi
done

    echo ""
    echo "***** Server Inspector ******"
    echo "1 - VIRL Config Validation"
    echo "2 - Restart Openstack Services"
    echo "3 - RESET Openstack"
    echo "4 - Server Maintenance"
    echo "0 - Exit"
    echo ""
    echo -n "Enter selection: "
    read selection
    echo ""
    case $selection in
        1 ) _result ; _dtype >> $_out 2>&1 ; _verchk >> $_out 2>&1 ; _o ; _netint >> $_out 2>&1 ; _saltst >> $_out 2>&1 ; _messg ; press_enter ;;
        2 ) _opnstk-restrt ; press_enter ;;
        3 ) _opnstk-reset ; press_enter ;;
        4 ) clear ; maint ;;
        0 ) _resp ; clear ; exit 0 ;;
        * ) echo "Please select option from menu!" ; press_enter ;;
    esac
done
}

function maint
{
selection=
until [ "$selection" = "0" ]; do
    echo ""
    echo "***** Server Maintenance ******"
    echo "1 - Verify Image Version Sync"
    echo "2 - Set Static IP Address"
    echo "3 - Return to >> Server Inspector"
    echo "0 - Exit"
    echo ""
    echo -n "Enter selection: "
    read selection
    echo ""
    case $selection in

        1 ) _sltimgchk ; press_enter ;;
        2 ) _askstatic ; press_enter ; _resp ; _commit ; press_enter ; sudo reboot now ;;
        3 ) clear ; menu ;;
        0 ) _resp ; clear ; exit 0 ;;
        * ) echo "Please select from the menu" ; press_enter ; clear ;;
    esac
done
}

### Script start ###

PROGNAME=$(basename $0)
trap term_exit TERM HUP
trap int_exit INT

clear
echo -ne "...starting please wait......."'\r'

if [[ $(id) =~ ^uid=0 ]]; then
    cat <<EOF

    Don't run this as root (e.g. with "sudo"). If the script needs to make
    changes as root, you will be prompted for your password!

EOF
exit 0
fi

## Global vars
tstmp=$(date +%R_%Y%m%d)
_ntp=$(ntpq -p)
ntrn=$(neutron agent-list)
ntrnsub=$(neutron subnet-list)
nva=$(nova service-list)
ver=$(sudo salt-call --local grains.get virl_release | egrep -v 'local:')
lver=$(lsb_release -a 2> /dev/null)
lbrdg=$(brctl show)
mstr=$(sudo salt-call --local grains.get salt_master | egrep -v 'local:' )
lic=$(sudo salt-call --local grains.get id | egrep -v 'local:' )
_out=~/SrvValTest.txt
###
clear

sudo timeout 6s sudo salt-call test.ping > /dev/null 2>&1
if [ $? -ne 0 ]; then
    printf "Your server may not be properly licensed.\nCheck your license via UWM before using this script.\n"
fi

menu
