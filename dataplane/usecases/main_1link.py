 ################################################################################
 # Copyright 2022 INTRIG
 #
 # Licensed under the Apache License, Version 2.0 (the "License");
 # you may not use this file except in compliance with the License.
 # You may obtain a copy of the License at
 #
 #     http://www.apache.org/licenses/LICENSE-2.0
 #
 # Unless required by applicable law or agreed to in writing, software
 # distributed under the License is distributed on an "AS IS" BASIS,
 # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 # See the License for the specific language governing permissions and
 # limitations under the License.
 ################################################################################

from src.data import *

topo = generator('main')

# Recirculation port default 68
topo.addrec_port(196)
topo.addrec_port_user(68)

# addswitch(name)
#topo.addswitch("sw1")
#topo.addp4("p4src/p7uav_2drones.p4")

# addhost(name,port,D_P,speed_bps,AU,FEC,vlan)
# include the link configuration
topo.addhost("h1","1/0", 132, 10000000000, "False", "False", 1920, "192.168.100.110")
topo.addhost("h2","1/2", 134, 10000000000, "False", "False", 1920, "192.168.100.2")

# addlink(node1, node2, bw, pkt_loss, latency, jitter, percentage)
# bw is considered just for the first defined link
topo.addlink("h1","h2", 10000000000, 0, 0, 0, 100)
#topo.addlink("h2","sw1", 10000000000, 0, 0, 0, 100)

# addvlan_port(port,D_P,speed_bps,AU,FEC)
# Vlan and port not P7 process
topo.addvlan_port("1/1", 133, 10000000000, "False", "False")
topo.addvlan_port("1/3", 135, 10000000000, "False", "False")

# addvlan_link(D_P1, D_P2, vlan)
topo.addvlan_link(133,135, 716)


#Generate files
topo.generate_chassis()
topo.generate_ports()
topo.generate_p4rt()
topo.generate_bfrt()
topo.generate_p4code()
topo.generate_graph()
topo.parse_usercode()
