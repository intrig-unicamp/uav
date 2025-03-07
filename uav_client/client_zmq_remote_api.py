#!/usr/bin/python

# Make sure to have the server side running in CoppeliaSim
# Run setNodePosition.py to update station location
# If there is an error to connect to the socket run sudo pkill -9 -f python

import sys
import time
from datetime import datetime
import socket
import os
import math
import signal
import subprocess
from numpy import *
from coppeliasim_zmqremoteapi_client import RemoteAPIClient

# Flag to determine ctrl+c to exit
run = 0

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

#Getting the simulation parameters manually
#Drones
drones_names = ["/Quadricopter[0]/Quadricopter_base", 
                    "/Quadricopter[1]/Quadricopter_base", 
                    "/Quadricopter[2]/Quadricopter_base"]
#Tarject position object
drones_targets = ["/Quadricopter[0]/Quadricopter_target", 
                    "/Quadricopter1]/Quadricopter_target", 
                    "/Quadricopter[2]/Quadricopter_target"]
#Static objects
cuboid_names = ["/Cuboid", "/Cuboid0", "/Cuboid1"]
#Reference
reference_names = "/Cylinder"

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
    global flag_delay           #Detect delay dr0 message
    global flag_delay_dr1       #Detect delay dr1 message
    global flag_delay_dr2       #Detect delay dr2 message
    global data_save            #Detected collision position        
    global print_flag           #Print messages

    flag = 0
    object_xy = [[] for i in range(3)]
    drones_xy = [[] for i in range(3)]
    for i in range(0,len(drones)):
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
                        print("P4 MESSAGE: Remote collision drone %s detected: %.2f, %.2f" %(i,drones_xy_copy[i][0],drones_xy_copy[i][1]))
                        print_flag = print_flag + 1
                    elif i != 1:
                        print("P4 MESSAGE: Remote collision drone %s detected: %.2f, %.2f" %(i,drones_xy_copy[i][0],drones_xy_copy[i][1])) 
                    data_save[i] = [data[i][0],data[i][1],data[i][2]]
                    dt = datetime.now()
                    if i==0:
                        flag_delay = 1
                    if i==1:
                        flag_delay_dr1 = 1
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

def send_file(data, node):
    file_name = "data/" + node + ".txt"
    f = open(file_name, "w")
    file_position = ','.join(map(str, data))
    f.write(file_position)
    f.close()

def send_file_position(data, data2, data3, node):
    file_name = "data/position_" + node + ".txt"
    f = open(file_name, "w")
    file_position = ','.join(map(str, data))
    f.write(file_position)
    f.write('\n')
    file_position_2 = ','.join(map(str, data2))
    f.write(file_position_2)
    f.write('\n')
    file_position_3 = ','.join(map(str, data3))
    f.write(file_position_3)
    f.close()

def drone_position(args):
    global run                  #Running flag
    global flag_collision       #Collision dr0
    global flag_collision_dr1   #Collision dr1
    global flag_collision_dr2   #Collision dr2
    global min_distance         #min distance
    global dt                   #time
    global flag_delay           #Detect delay dr0 message
    global flag_delay_dr1       #Detect delay dr1 message
    global flag_delay_dr2       #Detect delay dr2 message
    global data_save            #Detected collision position

    flag_delay = 0
    flag_delay_dr1 = 0

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
    host = '10.1.1.43'
    port = 65432  # Make sure it's within the > 1024 $$ <65535 range
    s = socket.socket()
    s.connect((host, port))
    print('Connected to remote API server')

    #Start checking Ctrl+C signal
    signal.signal(signal.SIGINT, handler)

    #Start connection with Coppeliasim
    client = RemoteAPIClient()
    sim = client.require('sim')
    sim.setStepping(True)
    sim.startSimulation()
    print('Starting Simulation')

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


    # Getting the ID of the drones from the simulation
    for i in range(0, len(drones)):
        drones[i] = sim.getObject(drones_names[i])
        drones_target[i] = sim.getObject(drones_targets[i])
        cuboid[i] = sim.getObject(cuboid_names[i])
    objectHandle_reference = sim.getObject(reference_names)
    print('Getting object name')
    print('Getting object handle')

    time.sleep(2)

    #Getting the positions as buffers
    while data[0] == [0.0,0.0,0.0] or data[0] == [] or object_data[0] == [0.0,0.0,0.0] or object_data[0] == []:
        for i in range(0,len(drones)):
            data[i] = sim.getObjectPosition(drones[i],objectHandle_reference) # Try to retrieve the streamed data
            object_data[i] = sim.getObjectPosition(cuboid[i],objectHandle_reference) # Try to retrieve the streamed data

    object_data[2] = [1.1450001430511475, 1.3999994993209839, 0.24999991059303284]

    target_pos = [float(nodes[3]),float(nodes[4]),float(nodes[5])]

    target_pos_dr1 = [0.7,1.5,0.51]

    print('Running Simulation...')

    print("Number of drones: 3")

    print("Secure distance: %s" % min_distance)

    print("REMOTE API: Target position Drone 0: %.2f, %.2f" %(float(nodes[3]),float(nodes[4])))
    print("REMOTE API: Target position Drone 1: %.2f, %.2f" %(target_pos_dr1[0] + data[1][0],target_pos_dr1[1]+ data[1][1]))

    position0 = [0.0,0.0,0.0]
    position0_dr1 = [0.0,0.0,0.0]
    
    dist = math.sqrt((target_pos[0] - data[0][0])**2 + (target_pos[1] - data[0][1])**2)
    dist_dr1 = math.sqrt((target_pos_dr1[0] - data[1][0])**2 + (target_pos_dr1[1] - data[1][1])**2)
    # print("dist", dist)

    dista = target_pos[0] - data[0][0]
    distb = target_pos[1] - data[0][1]

    dista_dr1 = target_pos_dr1[0] - data[1][0]
    distb_dr1 = target_pos_dr1[1] - data[1][1]

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
        sim.step()

        for i in range(0, len(drones)):
            data[i] = sim.getObjectPosition(drones[i],objectHandle_reference) # Try to retrieve the streamed data
            object_data[i] = sim.getObjectPosition(cuboid[i],objectHandle_reference) # Try to retrieve the streamed data

        object_data[2] = [1.1450001430511475, 1.3999994993209839, 0.24999991059303284]

        #Update Histogram with objects
        # histogram = histogram_update(object_data,data,drones)
        # histogram_copy = print_histogram(histogram)

        # subprocess.call("clear")
        # for i in range(50):
        #    print(histogram_copy[i])

        min_distance = float(nodes[6])
        check_collision(object_data,data,drones)

        if flag_collision == 1 and abs(count) < 0.3:
            if (datetime.now().timestamp() - dt.timestamp() > float(nodes[7]) ):
                if flag_send == 0:
                    for i in range(0, len(data)):
                        send_file_position(data[i],data_save[i],object_data[i],nodes[i])
                    flag_send = 1
                position0[0] = 0.005
                position0[1] = -0.02
                count = count + position0[1]
                returnCode = sim.setObjectPosition(drones_target[0],position0, drones_target[0]) # Try to retrieve the streamed data
                continue
        elif count > 0.1:
            count = 0
            flag_collision = 0

        if flag_collision_dr1 == 1 and abs(count_dr1) < 0.3:
            if (datetime.now().timestamp() - dt.timestamp() > float(nodes[7]) ):
                if flag_send == 0:
                    for i in range(0, len(data)):
                        send_file_position(data[i],data_save[i],object_data[i],nodes[i])
                    flag_send = 1
                position0_dr1[0] = -0.02
                position0_dr1[1] = -0.04
                count_dr1 = count_dr1 + position0_dr1[1]
                returnCode = sim.setObjectPosition(drones_target[1],position0_dr1, drones_target[1]) # Try to retrieve the streamed data
                continue
        elif count_dr1 > 0.1:
            count_dr1 = 0
            flag_collision_dr1 = 0


        if dista > -0.2 and dista < 0.2:
            flaga  = 1
            position0[0] = 0

        elif target_pos[0] > data[0][0] and flaga ==0:
            position0[0] = 0.02
            dista = dista - position0[0]
        elif target_pos[0] < data[0][0] and flaga ==0:
            position0[0] = -0.02
            dista = dista - position0[0]

        if distb > -0.2 and distb < 0.2:
            flagb  = 1
            position0[1] = 0
        elif target_pos[1] > data[0][1] and flagb ==0:
            position0[1] = 0.02
            distb = distb - position0[1]
        elif target_pos[1] < data[0][1] and flagb ==0:
            position0[1] = -0.02
            distb = distb - position0[1]



        if dista_dr1 > -0.2 and dista_dr1 < 0.2:
            flaga_dr1  = 1
            position0_dr1[0] = 0

        elif target_pos_dr1[0] > data[1][0] and flaga_dr1 ==0:
            position0_dr1[0] = 0.02
            dista_dr1 = dista_dr1 - position0_dr1[0]
        elif target_pos_dr1[0] < data[1][0] and flaga_dr1 ==0:
            position0_dr1[0] = -0.02
            dista_dr1 = dista_dr1 - position0_dr1[0]

        if distb_dr1 > -0.2 and distb_dr1 < 0.2:
            flagb_dr1  = 1
            position0_dr1[1] = 0
        elif target_pos_dr1[1] > data[1][1] and flagb_dr1 ==0:
            position0_dr1[1] = 0.02
            distb_dr1 = distb_dr1 - position0_dr1[1]
        elif target_pos_dr1[1] < data[1][1] and flagb_dr1 ==0:
            position0_dr1[1] = -0.02
            distb_dr1 = distb_dr1 - position0_dr1[1]




        if flaga == 1 and flagb == 1:
            
            if num_rep == 0:
                target_pos = [1.3,-1.5,0.51]
            if num_rep == 1:
                target_pos = [0.85,-1,0.51]
            if num_rep == 2:
                target_pos = [-0.1,-0.5,0.51]
            if num_rep == 3:
                target_pos = [-1.25,-0.25,0.51]
            if num_rep == 4:
                target_pos = [float(nodes[3]),float(nodes[4]),float(nodes[5])]

            print("REMOTE API: New Target position Drone 0: %.2f, %.2f" %(target_pos[0] + data[0][0],target_pos[1]+data[0][1]))
            position0 = [0.0,0.0,0.0]

            dist = math.sqrt((target_pos[0] - data[0][0])**2 + (target_pos[1] - data[0][1])**2)
            # print("dist", dist)

            dista = target_pos[0] - data[0][0]
            distb = target_pos[1] - data[0][1]

            # print("dista", dista)
            # print("distb", distb)

            flaga = 0
            flagb = 0

            flag_delay = 0

            num_rep = num_rep + 1

            if num_rep == 5:
                num_rep = 0

        if flaga_dr1 == 1 and flagb_dr1 == 1:
            
            if num_rep_dr1 == 0:
                target_pos_dr1 = [0.7,1.5,0.51]
            if num_rep_dr1 == 1:
                target_pos_dr1 = [-0.85,1.5,0.51]
            if num_rep_dr1 == 2:
                target_pos_dr1 = [-1,1.3,0.51]
            if num_rep_dr1 == 3:
                target_pos_dr1 = [0.1,1,0.51]
            if num_rep_dr1 == 4:
                target_pos_dr1 = [0.7,1.5,0.51]

            
            print("REMOTE API: New Target position Drone 1: %.2f, %.2f" %(target_pos_dr1[0] + data[1][0],target_pos_dr1[1] + data[1][0]))
            
            position0_dr1 = [0.0,0.0,0.0]

            dist_dr1 = math.sqrt((target_pos_dr1[0] - data[1][0])**2 + (target_pos_dr1[1] - data[1][1])**2)
            # print("dist", dist)

            dista_dr1 = target_pos_dr1[0] - data[1][0]
            distb_dr1 = target_pos_dr1[1] - data[1][1]

            # print("dista", dista)
            # print("distb", distb)

            flaga_dr1 = 0
            flagb_dr1 = 0

            flag_delay_dr1 = 0

            num_rep_dr1 = num_rep_dr1 + 1

            if num_rep_dr1 == 5:
                num_rep_dr1 = 0


        #Setting the positions
        # position0 = [data[0]]
        
        # position0[0] = position0[0] + 0.002
        # position0[1] = position0[0] + 0.002
        # print("1", dista)
        # print("2", distb)

        #Setting position
        returnCode = sim.setObjectPosition(drones_target[0], position0,drones_target[0]) 
        returnCode = sim.setObjectPosition(drones_target[1], position0_dr1,drones_target[1]) 
        
        #Storing the position in data files        
        # for i in range(0, len(data)):
        #     send_file(data[i],nodes[i])

        time.sleep(0.1)






        #Send to the remote API the information
        for i in range(0, len(data)):
            file_position = "Position(\"" \
                             + str(i+1) + "," \
                             + str(data[i][0]) + "," \
                             + str(data[i][1]) + "," \
                             + str(data[i][2]) + "\")"
            s.send(str(file_position).encode('utf-8'))
            data_rx = s.recv(1024).decode('utf-8')
            # print(file_position)

    #Stop the simulation Ctrl+C
    print('\nStopping Simulation...')
    sim.stopSimulation()

if __name__ == '__main__':
    drone_position(sys.argv)