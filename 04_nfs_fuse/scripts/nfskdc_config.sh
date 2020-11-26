#!/bin/expect -f
set timeout -1
spawn /usr/sbin/kdb5_util create -s -r TESTNFS.LAN
send "passnfs\r"
send "passnfs\r"
send "quit\r"
expect eof
