#!/bin/bash
## Takes one or two arguments
## Accepted arguments are:
## new | old | v
## new ) Tests new salt servers
## old ) Tests current salt servers
## v ) Tests salt servers using debug flag
##
## Usage:
## ./slt-test.sh new v
##
## Last modified: May 15, 2017

if [[ $# -eq 0 ]]; then
    cat <<EOF

    Usage: Specify 'new' to test new Salt servers, or
    'v' to provide verbouse output.
    EX: $0 new v

EOF
exit 1;
fi
lic=$(sudo salt-call --local grains.get id | egrep -v 'local:' )
oslt=.virl.info
nslt=-g1.virl.info

if [[ $1 = "new" || $1 = "v" ]]; then
    slt=$nslt
    if [[ $1 = "v" ]]; then
        v="-l debug"
    fi
    else
        slt=$oslt
    fi
    if [[ $2 = "v" ]]; then
        v="-l debug"
    fi

for srv in eu-1 eu-2 eu-3 eu-4 us-1 us-2 us-3 us-4
do
    idig=$(dig $srv$slt | egrep -o '([0-9]+\.){3}[0-9]+' |head -1)
    printf "\nTesting Connectivity to: [ %3s ==> %s ]\n" "$srv$slt" "$idig"
    nc -zv $srv$slt 4505-4506
    sleep 1
    printf "\nChecking License....[ %s ]\n" $lic
    printf "Auth test --> Salt Server [ %s ]\n" "$srv$slt"
    sudo salt-call --master $srv$slt $v test.ping
 done
