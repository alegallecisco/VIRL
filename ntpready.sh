#!/bin/bash

# setup an ntp-ready task

patch -d / -p1 <<'END'
--- A/etc/init.d/ntp	2016-08-02 17:11:39.484915047 +0000
+++ B/etc/init.d/ntp	2016-08-02 17:13:22.258213781 +0000
@@ -61,6 +61,7 @@
   		start-stop-daemon --start --quiet --oknodo --pidfile $PIDFILE --startas $DAEMON -- -p $PIDFILE $NTPD_OPTS
 		status=$?
 		unlock_ntpdate
+		initctl emit -n ntp-started
 		log_end_msg $status
   		;;
 	stop)
END

bin_path=/usr/local/bin/ntp-ready
cat <<'END' >$bin_path
#!/bin/sh
for attempt in {1..30} ; do ntpq -np | grep -q '^[*+]' && break ; sleep 1 ; done
END
chmod +x $bin_path

cat <<'END' >/etc/init/ntp-ready.conf
start on ntp-started 
author "Cisco Systems"
description "Wait for NTP to have peering established"
task
exec /usr/local/bin/ntp-ready
END

sed -i -e '/start on/s/$/ and stopped ntp-ready/' /etc/init/{nova,neutron,glance,cinder}*.conf
