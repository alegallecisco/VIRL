#!/bin/bash
## Place this file in following location '/etc/'
## and set permissions to 755 (u+x).
## Append /etc/rc.local with the following line:
## /etc/banner.sh > /etc/issue
##
## Last modified: Jan 13, 2017
## Created by: alejandro gallego (alegalle@cisco.com)
# echo ""
################################################################

mgmt=$(awk '$2 == 00000000 { print $1 }' /proc/net/route)
maddr=$(ip addr show dev $mgmt | awk '$1 == "inet" { sub("/..", "", $2); print $2}')
cat <<EOF

+*******************  Cisco VIRL Server  *******************+
|    To manage VIRL please use UWM web interface.           |
|    Point your browser to the URL shown below using        |
|    the following default credentials:                     |
|                                                           |
|    User Name: uwmadmin                                    |
|    Password: password                                     |
|                                                           |
|    UWM URL:                                               |
|    http://$maddr
|                                                           |
+*******************  Cisco VIRL Server  *******************+
EOF

printf "\n"
printf " * Documentation:  https://learningnetwork.cisco.com/docs/DOC-30160\n"
printf " * Guides:         https://learningnetwork.cisco.com/docs/DOC-30518\n"
printf " * Support:        https://learningnetwork.cisco.com/groups/virl\n"
printf "\nVIRL Server Interfaces: \n"

ifquery --list | egrep -v lo | sort | while read intf
do
ipadr=$(ip addr show dev $intf |awk '$1 == "inet" { sub("/..", "", $2); print $2}')
   ip link show $intf > /dev/null 2>&1
        if [ $? -ne 0 ] ; then
        printf ">>>>%sInterface $intf DOWN%s\n"
        else
        printf "%s    $intf: $ipadr\n"
        fi
done
echo ""
