for y in us-1 us-2 us-3 us-4
do
printf "%s\nTesting Server [$y]%s\n"
nc -zv $y.virl.info 4505-4506
printf "%s\nChecking License....%s"
printf "%s\nAuth test --> Salt Server [$y]%s\n"
sudo salt-call --master $y.virl.info -l debug test.ping
done
