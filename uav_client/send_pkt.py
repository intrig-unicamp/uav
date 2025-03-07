#!/usr/bin/python

import os
import sys

if os.getuid() !=0:
    print """
ERROR: This script requires root privileges. 
       Use 'sudo' to run it.
"""
    quit()

from scapy.all import *

ip_src = "192.168.100.110"
ip_dst = "192.168.100.2"
inter = "enp3s0f0.1920"
tcp_src = 5555
tcp_dst = 33478
payload = "12.42512.42490.04998058083150825"

print "Sending IP packet to", ip_dst
p = (Ether()/
     IP(src=ip_src, dst=ip_dst)/
     TCP(sport=tcp_src,dport=tcp_dst)/
     payload)
sendp(p, iface=inter)
