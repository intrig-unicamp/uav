 ################################################################################
 # Copyright 2025 INTRIG
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

#!/usr/bin/python

'UAV Server'

import sys
import time
from datetime import datetime
import socket
import os
import math
import signal
import subprocess
from numpy import *

#Getting the simulation parameters manually
#Drones
drones_names = [    "/Quadricopter[0]/Quadricopter_base", 
                    "/Quadricopter[1]/Quadricopter_base", 
                    "/Quadricopter[2]/Quadricopter_base"]
#Tarject position object
drones_targets = [  "/Quadricopter_target[0]", 
                    "/Quadricopter_target[1]", 
                    "/Quadricopter_target[2]"]
#Static objects
cuboid_names = ["/Cuboid", "/Cuboid0", "/Cuboid1"]
#Reference
reference_names = "/Cylinder"

# Flag to determine ctrl+c to exit
run = 0

# original 0.02
steps = 0.1

# original 0.01
cstep_x = 0.1

#original 0.02
cstep_y = 0.1

#Center of the histogram
#We use the absolute position when getting the object position.
center_a = 24
center_b = 24

#min distance to detect collision 30 cm
min_distance = 3

#objects size 
#object 20*20cm
#drone 30*30cm
object_size = [2, 3] #assume square objects

#Area size
#Flor 5m -> 50 represents 10cm
#Selected 50 as resolution to be easy the visualization in the terminal
histogram_resolution = 50
#Initialize histogram
histogram = [[0 for i in range(histogram_resolution)] for i in range(histogram_resolution)]

flag_collision = 0
flag_delay = 0
dt = datetime.now()
data_save = [[] for i in range(3)]

#Ctrl+C to exit the simmulation
def handler(signum, frame):
    global run 
    run = 1

#Verify
#Round the numbers
def round_num(num):
    return [round(float( '%g' % ( num[0] ) )*10,0),round(float( '%g' % ( num[1] ) )*10,0), num[2]]

#Update histogram
def histogram_update(object_data,data,drones):
    object_xy = [[] for i in range(3)]
    drones_xy = [[] for i in range(3)]
    hist = [[0 for i in range(50)] for i in range(50)]
    for i in range(0,len(drones)):
        object_xy[i] = [object_data[i][0],object_data[i][1],object_data[i][2]]
        object_xy[i] = round_num(object_xy[i])
        for j in range(object_size[0]):
            hist[center_a+int(object_xy[i][0])+j][center_b+int(object_xy[i][1])] = 1
            hist[center_a+int(object_xy[i][0])+j][center_b+int(object_xy[i][1])+1] = 1
    for i in range(0,len(drones)):
        drones_xy[i] = [data[i][0],data[i][1],data[i][2]]
        drones_xy[i] = round_num(drones_xy[i])
        for j in range(object_size[1]):
            hist[center_a+int(drones_xy[i][0])+j][center_b+int(drones_xy[i][1])] = 1
            hist[center_a+int(drones_xy[i][0])+j][center_b+int(drones_xy[i][1])+1] = 1
            hist[center_a+int(drones_xy[i][0])+j][center_b+int(drones_xy[i][1])+2] = 1
    return hist

def check_collision(object_data,data,drones):
    global flag_collision       #Collision dr0
    global flag_collision_dr1   #Collision dr1
    global flag_collision_dr2   #Collision dr2
    global min_distance         #min distance
    global dt                   #time
    global dt_dr1                  #time
    global flag_delay           #Detect delay dr0 message
    global flag_delay_dr1       #Detect delay dr1 message
    global flag_delay_dr2       #Detect delay dr2 message
    global data_save            #Detected collision position        
    global print_flag           #Print messages

    flag = 0
    object_xy = [[] for i in range(3)]
    drones_xy = [[] for i in range(3)]
    for i in range(0,len(drones)):
        flag = 0
        drones_xy[i] = [data[i][0],data[i][1],data[i][2]]
        drones_xy_copy = drones_xy.copy()
        # for j in range(0,len(drones_xy)):
        #     print("Before Round: ", drones_xy[i][j]) 
        drones_xy[i] = round_num(drones_xy[i])
        # for j in range(0,len(drones_xy)):
        #     print("After Round: ", drones_xy[i][j]) 
        for j in range(len(object_xy)):
            object_xy[j] = [object_data[j][0],object_data[j][1],object_data[j][2]]
            object_xy[j] = round_num(object_xy[j])
            # print("BEFORE X ", abs(object_xy[i][0] - object_size[0]/2 - drones_xy[i][0] - object_size[1]/2), " Y ",abs(object_xy[i][1] - object_size[0]/2 - drones_xy[i][1] - object_size[1]/2), " MIN ", min_distance)
            if abs(object_xy[j][0] - object_size[0]/2 - drones_xy[i][0] - object_size[1]/2) < min_distance and abs(object_xy[j][1] - object_size[0]/2 - drones_xy[i][1] - object_size[1]/2)  <  min_distance:
                flag = 1
                if (flag_delay == 0 and i == 0) or (flag_delay_dr1 == 0 and i == 1):
                    # print("P4 MESSAGE: Remote collision drone", i, " detected X ", abs(object_xy[j][0] - object_size[0]/2 - drones_xy[i][0] - object_size[1]/2), " Y ",abs(object_xy[j][1] - object_size[0]/2 - drones_xy[i][1] - object_size[1]/2))
                    if print_flag < 2 and i == 1:
                        print("1 P4 MESSAGE: Remote collision drone %s detected: %.2f, %.2f" %(i,drones_xy_copy[i][0],drones_xy_copy[i][1]))
                        print_flag = print_flag + 1
                    elif i != 1:
                        print("2 P4 MESSAGE: Remote collision drone %s detected: %.2f, %.2f" %(i,drones_xy_copy[i][0],drones_xy_copy[i][1])) 
                    data_save[i] = [data[i][0],data[i][1],data[i][2]]
                    
                    if i==0:
                        flag_delay = 1
                        dt = datetime.now()
                    if i==1:
                        flag_delay_dr1 = 1
                        dt_dr1 = datetime.now()
                    if i==2:
                        flag_delay_dr2 = 1
            # exit()
        if i==0:
            flag_collision = flag
        if i==1:
            flag_collision_dr1 = flag
        if i==2:
            flag_collision_dr2 = flag

def clear_histogram(hist):
    for i in range(len(hist[0])):
        for j in range(len(hist[0])):
            hist[i][j] = 0
    return hist

def print_histogram(hist):
    histogram_print = [[0 for i in range(50)] for i in range(50)]
    for i in range(len(hist[0])):
        for j in range(len(hist[0])):
            if hist[i][j] == 0:
                histogram_print[i][j] = " "
            else:
                histogram_print[i][j] = "X"
    return histogram_print

def send_message(s, data):
    s.send(data.encode('utf-8'))
    info = s.recv(1024).decode('utf-8')
    return info

#|ID|MESSAGE DATA|
def getObject(s, message_data):
    message = str(0) + str(message_data)
    # print("Message: " + message)
    info = send_message(s,message)
    # print('Message from client: '+ info)
    if int(info[0]) != 1:
        print("Wrong message responce")
        exit()
    return int(info[1:])

#|ID|OBJECT ID|REFERENCE|         TX ->
#|ID|DATA POSITION X|DATA POSITION Y|           RX <-
def getObjectPosition(s, object_id, objectHandle_reference):
    #print("REF GET " + str(objectHandle_reference))
    message = str(2) + str(object_id) + str(objectHandle_reference)
    # print("Message: " + message)
    info = send_message(s,message)
    # print('Message from client: '+ info)
    if int(info[0]) != 3:
        print("Wrong message responce")
        exit()
    if info[6] == '0':
        position = [float(info[1:6]),float(info[6:12]),float(info[12:])]
    else:
        position = [float(info[1:6]),float(info[7:13]),float(info[13:])]
    # print('Position: ' + str(position[0]) + ',' + str(position[1]) + ',' + str(position[2]))
    send_file(position, str(object_id))
    return position

#|ID|OBJECT ID|DATA POSITION X|DATA POSITION Y|DATA POSITION Z|REFERENCE|         TX ->
#|ID|                                                                           RX <-
def setObjectPosition(s, object_id, data_position, objectHandle_reference):
    # print('NEW Position ' + str(data_position[0]) + ',' + str(data_position[1]) + ',' + str(data_position[2]))
    #print("REF SET " + str(objectHandle_reference))
    data_position_adjusted = adjust_num(data_position)
    #print('Adjusted NEW Position ' + str(data_position_adjusted[0]) + ',' + str(data_position_adjusted[1]) + ',' + str(data_position_adjusted[2]))
    message = str(4) + str(object_id) + str(data_position_adjusted[0]) + str(data_position_adjusted[1]) + str(data_position_adjusted[2]) + str(objectHandle_reference)
    # print("Message: " + message)
    info = send_message(s,message)
    # print('Message from client: '+ info)
    if int(info[0]) != 5:
        print("Wrong message responce")
        exit()
    return int(info[0])

def adjust_num(num):
    return [str(num[0]).ljust(6, '0'), str(num[1]).ljust(6, '0'), str(num[2]).ljust(6, '0')]

def send_file(data, node):
    file_name = "data/" + node + ".txt"
    f = open(file_name, "a")
    file_position = ','.join(map(str, data)) + "\n"
    f.write(file_position)
    f.close()

def api(args):
    global flag_collision       #Collision dr0
    global flag_collision_dr1   #Collision dr1
    global flag_collision_dr2   #Collision dr2
    global min_distance         #min distance
    global dt                   #time
    global dt_dr1                  #time
    global flag_delay           #Detect delay dr0 message
    global flag_delay_dr1       #Detect delay dr1 message
    global flag_delay_dr2       #Detect delay dr2 message
    global data_save            #Detected collision position

    flag_delay = 0
    flag_delay_dr1 = 0

    os.system('rm data/*')

    drones = [[] for i in range(3)]
    
    drones_target = [[] for i in range(3)]
    cuboid = [[] for i in range(3)]
    
    nodes = []
    position0 = []
    data = [[] for i in range(3)]
    object_data = [[] for i in range(3)]
    histogram_copy = [[0 for i in range(50)] for i in range(50)]
    count = 0
    count_dr1 = 0

    flag_send = 0

    global print_flag 
    print_flag = 0 

    #Connect to remote API
    host = '192.168.100.110' #client zmq rxtx
    port = 5555  # Make sure it's within the > 1024 $$ <65535 range

    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, True)
    s.connect((host, port))
    print('Connected to Client')

    #Start checking Ctrl+C signal
    signal.signal(signal.SIGINT, handler)

    #python simpleTest.py dr1 dr2 dr3 1.45 -0.25 0.51 3 0.01
    if len(args) > 1:
        for n in range(1,len(args)):
            nodes.append(args[n])
    else:
        print("No nodes defined")
        # exit()

    #drones names
    #dr1 nodes[0]
    #dr2 nodes[1]
    #dr3 nodes[2]
    
    #target_pos dr0 [x,y,z]
    #target_pos[nodes[3],nodes[4],nodes[5]]
    
    #min distance nodes[6]
    
    #delay nodes[7]


    #Define the different messages and actions
    #0  get objects ID
    #1  get position
    #2  set position
    #9  message to server

    # Getting the ID of the drones from the simulation
    print('Getting object name')
    print('Getting object handle')
    for i in range(0, len(drones)):
        drones[i] = getObject(s, drones_names[i])
        drones_target[i] = getObject(s, drones_targets[i])
        cuboid[i] = getObject(s, cuboid_names[i])
    objectHandle_reference = getObject(s, reference_names)
    
    # time.sleep(2)

    #Getting the positions as buffers
    print('Getting the positions as buffers')
    while data[0] == [0.0,0.0,0.0] or data[0] == [] or object_data[0] == [0.0,0.0,0.0] or object_data[0] == []:
        for i in range(0,len(drones)):
            data[i] = getObjectPosition(s,drones[i],objectHandle_reference) # Try to retrieve the streamed data
            object_data[i] = getObjectPosition(s,cuboid[i],objectHandle_reference) # Try to retrieve the streamed data

    #object_data[2] = [1.1450001430511475, 1.3999994993209839, 0.24999991059303284]

    # target_pos = [float(nodes[3]),float(nodes[4]),float(nodes[5])]
    target_pos = [3,2.18,0.30]

    # target_pos_dr1 = [0.7,1.5,0.51]
    target_pos_dr1 = [4.3,3.8,0.30]

    print('Running Simulation...')

    print("Number of drones: 3")

    print("Secure distance: %s" % min_distance)

    print("REMOTE API: Target position Drone 0: %.2f, %.2f" %(float(nodes[3]),float(nodes[4])))
    print("REMOTE API: Target position Drone 1: %.2f, %.2f" %(target_pos_dr1[0],target_pos_dr1[1]))

    position0 = [0.0,0.0,0.0]
    position0_dr1 = [0.0,0.0,0.0]
    
    dist = math.sqrt((target_pos[0] - data[0][0])**2 + (target_pos[1] - data[0][1])**2)
    dist_dr1 = math.sqrt((target_pos_dr1[0] - data[1][0])**2 + (target_pos_dr1[1] - data[1][1])**2)
    # print("dist", dist)

    dista = abs(target_pos[0] - data[0][0])
    # print("target_pos[0]", target_pos[0])
    # print("data[0][0]", data[0][0])

    distb = abs(target_pos[1] - data[0][1])
    # print("target_pos[1]", target_pos[1])
    # print("data[0][1]", data[0][1])

    dista_dr1 = abs(target_pos_dr1[0] - data[1][0])
    distb_dr1 = abs(target_pos_dr1[1] - data[1][1])

    # print("dista", dista)
    # print("distb", distb)

    flaga = 0
    flagb = 0
    flaga_dr1 = 0
    flagb_dr1 = 0

    #Update Histogram with objects
    # histogram = histogram_update(object_data,data,drones)
    # for i in range(50):
    #     print(histogram[i])  
    # histogram_copy = print_histogram(histogram)

    # subprocess.call("clear")
    # for i in range(50):
    #     print(histogram_copy[i])

    # histogram_update(histogram)

    num_rep = 0
    num_rep_dr1 = 0

    while run==0:
        for i in range(0, len(drones)):
            data[i] = getObjectPosition(s,drones[i],objectHandle_reference) # Try to retrieve the streamed data
            object_data[i] = getObjectPosition(s,cuboid[i],objectHandle_reference) # Try to retrieve the streamed data

        #object_data[2] = [1.1450001430511475, 1.3999994993209839, 0.24999991059303284]

        #Update Histogram with objects
        # histogram = histogram_update(object_data,data,drones)
        # histogram_copy = print_histogram(histogram)

        # subprocess.call("clear")
        # for i in range(50):
        #    print(histogram_copy[i])

        min_distance = float(nodes[6])
        check_collision(object_data,data,drones)

        if flag_collision == 1 and abs(count) < 0.16:
            if (datetime.now().timestamp() - dt.timestamp() > float(nodes[7]) ):
                print('Avoiding DR0')
                # if flag_send == 0:
                #     for i in range(0, len(data)):
                #         send_file_position(data[i],data_save[i],object_data[i],nodes[i])
                #     flag_send = 1
                position0[0] = cstep_x
                position0[1] = -cstep_y
                count = count + abs(position0[1])
                returnCode = setObjectPosition(s,drones_target[0],position0, drones_target[0]) # Try to retrieve the streamed data
        elif abs(count) > 0.1:
            count = 0
            flag_collision = 0
        else:
            if dista < 0.2:
                flaga  = 1
                position0[0] = 0
                # print('dista > -0.2 and dista < 0.2 ----- flaga = ' + str(flaga))
            elif target_pos[0] > data[0][0] and flaga ==0:
                position0[0] = steps #cambio
                dista = dista - position0[0]
                # print('target_pos[0] > data[0][0] ----- dista = ' + str(dista))
            elif target_pos[0] < data[0][0] and flaga ==0:
                position0[0] = -steps #cambio
                dista = dista + position0[0]
                # print('target_pos[0] < data[0[0] ----- dista = ' + str(dista))

            if distb < 0.2:
                flagb  = 1
                position0[1] = 0
                # print('distb > -0.2 and distb ----- flagb = ' + str(flagb))
            elif target_pos[1] > data[0][1] and flagb ==0:
                position0[1] = steps
                distb = distb - position0[1]
                # print('target_pos[1] > data[0][1] ----- distb = ' + str(distb))
            elif target_pos[1] < data[0][1] and flagb ==0:
                position0[1] = -steps
                distb = distb + position0[1]
                # print('target_pos[1] < data[0][1] ----- distb = ' + str(distb))

            if flaga == 1 and flagb == 1:
                
                if num_rep == 0:
                    target_pos = [3,1.5,0.30]
                if num_rep == 1:
                    target_pos = [2.5,1,0.30]
                if num_rep == 2:
                    target_pos = [1.5,1.5,0.30]
                if num_rep == 3:
                    target_pos = [1.17,2.4,0.30]
                if num_rep == 4:
                    # target_pos = [float(nodes[3]),float(nodes[4]),float(nodes[5])]
                    target_pos = [3,2.18,0.30]

                print("REMOTE API: New Target position Drone 0: %.2f, %.2f" %(target_pos[0],target_pos[1]))
                position0 = [0.0,0.0,0.0]

                dist = math.sqrt((target_pos[0] - data[0][0])**2 + (target_pos[1] - data[0][1])**2)
                # print("dist", dist)

                dista = abs(target_pos[0] - data[0][0])
                # print("target_pos[0]", target_pos[0])
                # print("data[0][0]", data[0][0])

                distb = abs(target_pos[1] - data[0][1])
                # print("target_pos[1]", target_pos[1])
                # print("data[0][1]", data[0][1])

                # print("dista", dista)
                # print("distb", distb)

                flaga = 0
                flagb = 0

                flag_delay = 0

                num_rep = num_rep + 1

                if num_rep == 5:
                    num_rep = 0

            #Setting position
            returnCode = setObjectPosition(s,drones_target[0], position0,drones_target[0])

        if flag_collision_dr1 == 1 and abs(count_dr1) < 0.16:
            if (datetime.now().timestamp() - dt_dr1.timestamp() > float(nodes[7]) ):
                print('Avoiding DR1')
                # if flag_send == 0:
                #     for i in range(0, len(data)):
                #         send_file_position(data[i],data_save[i],object_data[i],nodes[i])
                #     flag_send = 1
                position0_dr1[0] = cstep_x
                position0_dr1[1] = -cstep_y
                count_dr1 = count_dr1 + abs(position0_dr1[1])
                returnCode = setObjectPosition(s,drones_target[1],position0_dr1, drones_target[1]) # Try to retrieve the streamed data
        elif abs(count_dr1) > 0.1:
            count_dr1 = 0
            flag_collision_dr1 = 0
        else:
            if dista_dr1 < 0.2:
                flaga_dr1  = 1
                position0_dr1[0] = 0

            elif target_pos_dr1[0] > data[1][0] and flaga_dr1 ==0:
                position0_dr1[0] = steps
                dista_dr1 = dista_dr1 - position0_dr1[0]
            elif target_pos_dr1[0] < data[1][0] and flaga_dr1 ==0:
                position0_dr1[0] = -steps
                dista_dr1 = dista_dr1 + position0_dr1[0]

            if distb_dr1 < 0.2:
                flagb_dr1  = 1
                position0_dr1[1] = 0
            elif target_pos_dr1[1] > data[1][1] and flagb_dr1 ==0:
                position0_dr1[1] = steps
                distb_dr1 = distb_dr1 - position0_dr1[1]
            elif target_pos_dr1[1] < data[1][1] and flagb_dr1 ==0:
                position0_dr1[1] = -steps
                distb_dr1 = distb_dr1 + position0_dr1[1]

            if flaga_dr1 == 1 and flagb_dr1 == 1:
                
                if num_rep_dr1 == 0:
                    target_pos_dr1 = [4.3,4.8,0.51]
                if num_rep_dr1 == 1:
                    target_pos_dr1 = [3.5,4.8,0.51]
                if num_rep_dr1 == 2:
                    target_pos_dr1 = [2,4.2,0.51]
                if num_rep_dr1 == 3:
                    target_pos_dr1 = [2.45,3.6,0.51]
                if num_rep_dr1 == 4:
                    target_pos_dr1 = [4.3,3.8,0.30]

                
                print("REMOTE API: New Target position Drone 1: %.2f, %.2f" %(target_pos_dr1[0],target_pos_dr1[1]))
                
                position0_dr1 = [0.0,0.0,0.0]

                dist_dr1 = math.sqrt((target_pos_dr1[0] - data[1][0])**2 + (target_pos_dr1[1] - data[1][1])**2)
                # print("dist", dist)

                dista_dr1 = abs(target_pos_dr1[0] - data[1][0])
                distb_dr1 = abs(target_pos_dr1[1] - data[1][1])

                # print("dista", dista)
                # print("distb", distb)

                flaga_dr1 = 0
                flagb_dr1 = 0

                flag_delay_dr1 = 0

                num_rep_dr1 = num_rep_dr1 + 1

                if num_rep_dr1 == 5:
                    num_rep_dr1 = 0
         
            returnCode = setObjectPosition(s,drones_target[1], position0_dr1,drones_target[1]) 

        # time.sleep(0.1)
    print('\nClossing connection with Remote API...')
    s.close()

if __name__ == '__main__':
    api(sys.argv)
