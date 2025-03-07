#!/usr/bin/python

# Make sure to have the server side running in CoppeliaSim
# Run setNodePosition.py to update station location
# If there is an error to connect to the socket run sudo pkill -9 -f python

import sys
import time
import socket
import os
import signal

from coppeliasim_zmqremoteapi_client import RemoteAPIClient

run = 0

def handler(signum, frame):
    global run 
    run = 1

def drone_position(args):
    global run 
    host = '127.0.0.1'
    port = 65432  # Make sure it's within the > 1024 $$ <65535 range
    s = socket.socket()
    s.connect((host, port))
    print('Connected to remote API server')

    signal.signal(signal.SIGINT, handler)

    client = RemoteAPIClient()
    sim = client.require('sim')

    sim.setStepping(True)

    sim.startSimulation()

    print('Starting Simulation')

    drones = [[] for i in range(3)]
    drones_names = ["/Quadricopter[0]/Quadricopter_base", 
                    "/Quadricopter_target[0]", 
                    "/Quadricopter[2]/Quadricopter_base"]
    reference_names = "/Cylinder"

    print('Getting object name')

    data = [[] for i in range(3)]

    # Getting the ID of the drones from the simulation
    for i in range(0, len(drones)):
        drones[i] = sim.getObject(drones_names[i])
        print(str(drones[i]))
    objectHandle_reference = sim.getObject(reference_names)

    print('Getting object handle')

    print('Running Simulation...')

    while run==0:
        sim.step()

        for i in range(0, len(drones)):
            data[i]=sim.getObjectPosition(drones[i],objectHandle_reference)

        for i in range(0, len(data)):
            file_position = "Position(\"" \
                             + str(i+1) + "," \
                             + str(data[i][0]) + "," \
                             + str(data[i][1]) + "," \
                             + str(data[i][2]) + "\")"
            s.send(str(file_position).encode('utf-8'))
            data_rx = s.recv(1024).decode('utf-8')
            # print(file_position)

    print('\nStopping Simulation...')
    sim.stopSimulation()

if __name__ == '__main__':
    drone_position(sys.argv)