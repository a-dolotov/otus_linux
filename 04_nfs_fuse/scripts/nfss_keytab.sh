#!/bin/expect -f
set timeout -1
spawn /bin/kadmin -s nfskdc.testnfs.lan -p root/admin@TESTNFS.LAN -w "passroot"
send "ktadd -k /etc/krb5.keytab nfs/nfss.testnfs.lan@TESTNFS.LAN\r"
send "quit\r"
expect eof
