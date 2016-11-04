#/bin/bash
# With changes from Ed Kern

alias vnc='vncserver -geometry 1600x1200 -depth 24'

#if folks want to kick off vnc i would suggest copying the /home/virl/.vnc directory for easier starting


#vagrant file only needs

#config.vm.box = "virl/medium"

#for a link pointer

echo Running vagrant halt...
vagrant halt

echo Running vagrant destroy -f
vagrant destroy -f

set the proxy
export http_proxy=http://proxy.esl.cisco.com:80/
export https_proxy=http://proxy.esl.cisco.com:80/
export no_proxy="controller,virl,localhost,127.0.1.1,127.0.0.1,localaddress,.localdomain.com,.cisco.com"


#check for upgrade
vagrant box update

#show box list to remind folks to delete 
vagrant box list 
echo ''
echo Dont forget to remove dead boxes with 'vagrant box remove virl/example --box-version 0.9.10'

echo Running vagrant up
vagrant up