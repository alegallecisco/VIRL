#!/bin/bash
trap int_exit INT

function int_exit
{
        echo "${PROGNAME}: Aborted by user"
        exit
}

function _cont
{
	echo ""
	echo -n "Continue? (y/n)"
	read _resp
}

function _resp
{
	#echo ""
	#echo -n "Continue? (y/n) "
	#read _resp
	#_resp= $_resp
	until [ $_resp == "y" ]; do
    		case $_resp in
        	y ) _resp=y ;;
            n ) exit 0 ;;
            * ) printf "%s\nPlease enter a \"y\" or \"n\"%s\n" ; _cont ;;
        	esac
	done
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
printf "%s\nNetwork Agent%s\n"
for n in agent-list net-list
do
	neutron $n
done
#
printf "%s\nServer Agents%s\n"
for s in endpoint-list service-list
do
	keystone $s
done
}

function _netinfo
{
	printf "%s\nIP Address (mgmt): %s\n"
	ifconfig eth0
	printf "%s\nRoute Table: %s\n"
	route -n
	printf "%s\nSystem Interfaces: %s\n"
	cat /sys/class/net
}

function _saltst
{
_out=SaltSrvrTest.txt
printf "%s\nResults printed to file \"$_out\" in
    \"virl user's home directory\"%s\n"
sleep 2
rm ~/$_out >& /dev/null
touch $_out
mstr=$(sudo salt-call --local grains.get salt_master)
printf "%s\nConfigured Salt masters:\n $mstr%s\n"
printf "%s\nSalt Masters\n $mstr %s\n"  >> ~/$_out 2>&1
egrep  -o -w '\bus-[1-4].virl.info'\|'\beu-[1-4].virl.info' /etc/virl.ini | while read srv
    do
    printf "%s\nTesting Connectivity to: [$srv]%s"
    printf "%s\n>>>> $srv\n" >> ~/$_out 2>&1 && nc -zv $srv 4505-4506 >> ~/$_out 2>&1
    echo ""
    printf "%s\nChecking License....%s"
    printf "%s\nAuth test --> Salt Server [$srv]%s\n"
    printf "%s\n>>>> $srv\n" >> ~/$_out 2>&1 && sudo salt-call --master $srv -l debug test.ping >> ~/$_out 2>&1
    done

printf "%s\nChecking hostname and network interfaces: %s\n"
sleep 5
    for h in /etc/hostname /etc/hosts /etc/network/interfaces
    do
        printf "%s\n>>> $h <<<%s\n" >> ~/$_out 2>&1
        cat $h >> ~/$_out
    done
sleep 5
printf "%s\nResults printed to file \"$_out\" located in
\"virl user's home directory\" Path is \"/home/virl\"%s\n"
sleep 5
}

function press_enter
{
	echo ""
	echo -n "Press enter to continue"
	read
	clear
}

function _ntrnagnt
{
	neutron agent-list
	neutron net-list
}

function _opnstk-restrt
{
	sudo salt-call state.sls openstack-restart
}

function _verchk
{
	echo ">>>Openstack Installed Versions<<<"
	dpkg -l nova-common neutron-common
	nova --version
	keystone-all --version
	echo ""
	echo ">>>>VIRL Versions<<<<"
	sudo salt-minion --versions
	sudo virl_uwm_client version
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

function _confchk
{
	printf "%s\nChecking hostname and network interfaces: %s\n"

    for h in /etc/hostname /etc/hosts /etc/network/interfaces
    do
        printf "%s\n>>> $h <<<%s\n"
        cat $h
    done
_netinfo
}

function _askstatic
{
clear
_adns=x
while true; do
    read -p "Enter static IP: " ip
    read -p "Enter network ID: (ex. 172.16.1.0 for a /24 network) " ntid
    read -p "Enter netmask: " msk
    read -p "Enter default gateway: " gw
    until [ $_adns == "y" ]; do
        read -p "Specify custom DNS servers: (optional) \"y or n\" " _adns
    	case $_adns in
        	[Yy] ) _adns=y ; _askdns ;;
            [xn] ) break ;;
            * ) printf "%s\nPlease enter a \"y\" or \"n\"%s\n" ;;
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
    read -p "Primary DNS server:" dns1
    read -p "Secondary DNS server:" dns2
}

function _setstatic
{
    sudo cp /etc/virl.ini /etc/virl.ini.orig
    printf "%s\nSetting network information, please wait...!%s\n"
        sudo crudini --set /etc/virl.ini DEFAULT using_dhcp_on_the_public_port False
    if [[ ! -z  $ip ]]; then
        sudo crudini --set /etc/virl.ini DEFAULT Static_IP $ip
        echo "Static IP set...    $ip"
        else
        echo "No Change... skipping!"
    fi
    if [[ ! -z $ntid ]]; then
        sudo crudini --set /etc/virl.ini DEFAULT public_network $ntid
        echo "Network ID set...   $ntid"
        else
        echo "No Change... skipping!"
    fi
    if [[ ! -z $msk ]]; then
        sudo crudini --set /etc/virl.ini DEFAULT public_netmask $msk
        echo "Netmask set...      $msk"
        else
        echo "No Change... skipping!"
    fi  
    if [[ ! -z $gw ]]; then
        sudo crudini --set /etc/virl.ini DEFAULT public_gateway $gw
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
}

function _healtchk
{
    sudo virl_health_status >> ~/my-server-status.log
}

clear
if [[ $(id) =~ ^uid=0 ]]; then
	cat <<-EOF
	
	Don't run this as root (e.g. with "sudo"). If the script needs to make
	changes as root, you will be prompted for your password!
	
EOF
exit 0
fi

function menu
{
selection=
until [ "$selection" = "0" ]; do
	echo ""
	echo "***** Server Inspector ******"
	echo "1 - Salt server connectivity"
	echo "2 - Openstack Services check"
	echo "3 - Restart Openstack Services"
	echo "4 - Test Image Availability"
	echo "5 - Config Check"
	echo "6 - Version Check"
	echo "7 - Openstack Agents"
	echo "8 - VIRL Server Health check"
	echo "9 - Set Static IP address"
	echo ""
	echo "0 - exit program"
	echo ""
	echo -n "Enter selection: "
	read selection
	echo ""
	case $selection in
		1 ) _saltst ; press_enter ;;
		2 ) _svc ; press_enter ;;
		3 ) _ntrnagnt ; press_enter ;;
		4 ) _sltimgchk ; press_enter ;;
		5 ) _confchk ; press_enter ;;
		6 ) _verchk ; press_enter ;;
		7 ) _opnstk-agnt ; press_enter ;;
		8 ) _healtchk ; press_enter ;;
		9 ) _askstatic ; press_enter ;;
		0 ) clear ; exit ;;
		* ) echo "Please select from the menu" ; press_enter ;;
	esac
done
}

menu



