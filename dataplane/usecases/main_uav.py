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
topo.addswitch("sw1")
topo.addp4("p4src/p7uav_2drones.p4")

# addhost(name,port,D_P,speed_bps,AU,FEC,vlan)
# include the link configuration
topo.addhost("h1","1/0", 132, 10000000000, "False", "False", 1920, "192.168.100.110")
topo.addhost("h2","1/2", 134, 10000000000, "False", "False", 1920, "192.168.100.2")

# addlink(node1, node2, bw, pkt_loss, latency, jitter, percentage)
# bw is considered just for the first defined link
topo.addlink("h1","sw1", 10000000000, 0, 0, 0, 100)
topo.addlink("h2","sw1", 10000000000, 0, 0, 0, 100)

# addvlan_port(port,D_P,speed_bps,AU,FEC)
# Vlan and port not P7 process
topo.addvlan_port("1/1", 133, 10000000000, "False", "False")
topo.addvlan_port("1/3", 135, 10000000000, "False", "False")

# addvlan_link(D_P1, D_P2, vlan)
topo.addvlan_link(133,135, 716)

hex_flag = [0x0000 for i in range(0,5001)]
flag_1 = 0
flag_2 = 0
flag_3 = 0
flag_4 = 0

for i in range(1,5001):
	if flag_1 < 9:
		hex_flag[i] = hex_flag[i-1] + 0x0001
		flag_1 = flag_1 + 1
		continue
	if flag_2 < 9 and flag_1 == 9:
		temp = hex_flag[i-1]
		temp = 0xFFF0 & temp
		hex_flag[i] = temp + 0x0010
		flag_2 = flag_2 + 1
		flag_1 = 0
		continue
	if flag_3 < 9 and flag_2 == 9 and flag_1 == 9:
		temp = hex_flag[i-1]
		temp = 0xFF00 & temp
		hex_flag[i] = temp + 0x0100
		flag_3 = flag_3 + 1
		flag_2 = 0
		flag_1 = 0
		continue
	if flag_4 < 9 and flag_3 == 9 and flag_2 == 9 and flag_1 == 9:
		temp = hex_flag[i-1]
		temp = 0xF000 & temp
		hex_flag[i] = temp + 0x1000
		flag_4 = flag_4 + 1
		flag_3 = 0
		flag_2 = 0
		flag_1 = 0
		continue

for i in range(1,5001):
	hexval = str(hex(i))

	topo.addtable('sw1','SwitchIngress.transform_x')
	topo.addaction('SwitchIngress.dectohex_x')
	topo.addmatch('x_pos_int',str(hex_flag[i]))
	topo.addactionvalue('hexval',hexval)
	topo.insert()

	topo.addtable('sw1','SwitchIngress.transform_y')
	topo.addaction('SwitchIngress.dectohex_y')
	topo.addmatch('y_pos_int',str(hex_flag[i]))
	topo.addactionvalue('hexval',hexval)
	topo.insert()


#Collision table
topo.addtable('sw1','SwitchIngress.check_collision')
topo.addaction('SwitchIngress.collision_action')
topo.addmatch('x_pos_hex_start',str(2001))
topo.addmatch('x_pos_hex_end',str(3300))
topo.addmatch('y_pos_hex_start',str(1201))
topo.addmatch('y_pos_hex_end',str(2700))
topo.addactionvalue('new_x',str(0x302e30313030))
topo.addactionvalue('new_y',str(0x2d302e303230))
topo.addactionvalue('new_z',str(0x302e30303030))
topo.insert()

topo.addtable('sw1','SwitchIngress.check_collision')
topo.addaction('SwitchIngress.collision_action')
topo.addmatch('x_pos_hex_start',str(3401))
topo.addmatch('x_pos_hex_end',str(4200))
topo.addmatch('y_pos_hex_start',str(3101))
topo.addmatch('y_pos_hex_end',str(3900))
topo.addactionvalue('new_x',str(0x302e30313030))
topo.addactionvalue('new_y',str(0x2d302e303230))
topo.addactionvalue('new_z',str(0x302e30303030))
topo.insert()

topo.addmirror('normal', 
				sid=2,
				direction='BOTH',
				session_enable='True',
				ucast_egress_port=196,
				ucast_egress_port_valid=1,
				max_pkt_len=16384)
topo.push()

#Generate files
topo.generate_chassis()
topo.generate_ports()
topo.generate_p4rt()
topo.generate_bfrt()
topo.generate_p4code()
topo.generate_graph()
topo.parse_usercode()
