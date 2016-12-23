#!/bin/bash

echo "virl-salt-master-1.cisco.com
virl-salt-master-2.cisco.com
virl-salt-master-3.cisco.com
virl-salt-master-4.cisco.com" | while read srv
  do
    idig=$(dig $srv | egrep -o '([0-9]+\.){3}[0-9]+' |head -1)
    if [ $? -ne 1 ] ; then
    printf "%s\nTesting Connectivity to: [$srv :: $idig]%s"
    nc -zv $srv 4505-4506
    echo ""
    else
    printf "%s\nUnable to resolve $srv Please check your connection.%s\n"
    fi
  done