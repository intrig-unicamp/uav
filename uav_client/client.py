#!/usr/bin/python

# Make sure to have the server side running in CoppeliaSim
# Run setNodePosition.py to update station location
# If there is an error to connect to the socket run sudo pkill -9 -f python

import sys
import time
import socket
import os

path = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, '{}/libs/'.format(path))

try:
    import sim
except:
    print('--------------------------------------------------------------')
    print('"sim.py" could not be imported. This means very probably that')
    print('either "sim.py" or the remoteApi library could not be found.')
    print('Make sure both are in the same folder as this file,')
    print('or appropriately adjust the file "sim.py"')
    print('--------------------------------------------------------------')
    print('')


def drone_position(args):
    drones = [[] for i in range(3)]
    drones_names = ['Quadricopter_base', 'Quadricopter_base#0', 'Quadricopter_base#1']
    reference_names = 'Cylinder'
    # reference = []
    nodes = []
    data = [[] for i in range(3)]

    if len(args) > 1:
        for n in range(1, len(args)):
            nodes.append(args[n])
    else:
        print("No nodes defined")
        exit()

    print('Program started')
    sim.simxFinish(-1)  # just in case, close all opened connections
    clientID = sim.simxStart('127.0.0.1', 19999, True, True, 5000, 5)  # Connect to CoppeliaSim

    host = '10.1.1.43'
    port = 65432  # Make sure it's within the > 1024 $$ <65535 range
    s = socket.socket()
    s.connect((host, port))

    if clientID != -1:
        res = None
        print('Connected to remote API server')
        # Getting the ID of the drones from the simulation
        for i in range(0, len(drones)):
            [res, drones[i]] = sim.simxGetObjectHandle(clientID,
                                                       drones_names[i],
                                                       sim.simx_opmode_oneshot_wait)

        [res, reference] = sim.simxGetObjectHandle(clientID,
                                                    reference_names,
                                                    sim.simx_opmode_oneshot_wait)

        if res == sim.simx_return_ok:
            print('Connected with CoppeliaSim')
        else:
            print('Remote API function call returned with error code: ', res)

        time.sleep(2)
        # Starting the getPosition function streaming
        for i in range(0, len(drones)):
            sim.simxGetObjectPosition(clientID,
                                      drones[i],
                                      -1,
                                      sim.simx_opmode_streaming)

        sim.simxGetObjectPosition(clientID,
                                      reference,
                                      -1,
                                      sim.simx_opmode_streaming)

        while True:
            # Getting the positions as buffers
            
            returnCode, data_ref = sim.simxGetObjectPosition(clientID,
                                                                reference,
                                                                -1,
                                                                sim.simx_opmode_buffer)

            print(data_ref)

            for i in range(0, len(drones)):
                # Try to retrieve the streamed data
                returnCode, data[i] = sim.simxGetObjectPosition(clientID,
                                                                drones[i],
                                                                sim.handle_parent,
                                                                sim.simx_opmode_buffer)
            # Storing the position in data files

            


            for i in range(0, len(data)):
                # send_file(data[i], nodes[i])
                file_position = "Position(\"" \
                                 + str(i+1) + "," \
                                 + str(data[i][0]) + "," \
                                 + str(data[i][1]) + "," \
                                 + str(data[i][2]) + "\")"
                s.send(str(file_position).encode('utf-8'))
                data_rx = s.recv(1024).decode('utf-8')
                #print(str(data_rx))

            #time.sleep(1)

        # Now close the connection to CoppeliaSim:
        sim.simxFinish(clientID)
    else:
        print('Failed connecting to remote API server')
    print('Program ended')


def send_file(data, node):
    path = os.path.dirname(os.path.abspath(__file__))
    file_name = "{}/data/".format(path) + node + ".txt"
    f = open(file_name, "w")
    file_position = ','.join(map(str, data))
    f.write(file_position)
    f.close()


if __name__ == '__main__':
    drone_position(sys.argv)