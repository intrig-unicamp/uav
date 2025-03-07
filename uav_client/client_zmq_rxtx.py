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

host = '192.168.100.110' #client zmq rxtx
port = 5555  # Make sure it's within the > 1024 $$ <65535 range

# Flag to determine ctrl+c to exit
run = 0

#Ctrl+C to exit the simmulation
def handler(signum, frame):
    global run 
    run = 1

def round_num(num):
    data  = [round(float( '%g' % ( num[0] ) ),4),round(float( '%g' % ( num[1] ) ),4), num[2]] 
    return [str(data[0]).ljust(6, '0'), str(data[1]).ljust(6, '0'), str(data[2])]
    # return [round(float( '%g' % ( num[0] ) )*10,0),round(float( '%g' % ( num[1] ) )*10,0), num[2]]

def drone_position(args):
    global run                  #Running flag

    #Start checking Ctrl+C signal
    signal.signal(signal.SIGINT, handler)

    #Start connection with Coppeliasim
    client = RemoteAPIClient()
    sim = client.require('sim')
    sim.setStepping(True)
    sim.startSimulation()
    print('Starting Simulation')

    with socket.socket() as s:

        s.bind((host, port))
        s.listen()
        conn, addr = s.accept()
        with conn:
            print("Connected to remote API server: " + str(addr))
            print('Running Simulation...')
            #Connect to remote API
            #main connection loop
            while run==0:
                sim.step()
                data = conn.recv(1024).decode('utf-8')
                if not data:
                    # if data is not received break
                    break

                #Simple parse the received message
                message_id = int(data[0])
                message_data = data[1:]
                print(data)
                print("Message ID:" + str(message_id))
                print("Data: " + str(message_data))

                #Define the different messages and actions
                # 0   get objects ID Request
                # 1   get objects ID Reply
                # 2   get position Request
                # 3   get position Reply
                # 4   set position Request
                # 5   set position Reply
                # 6-9 Reserved
                match message_id:
                    case 0:
                        # Getting the ID of the drones from the simulation
                        #|ID|DATA|
                        print('Getting object name')
                        print('Getting object handle')
                        object_id = sim.getObject(message_data)
                        
                        object_id = str(1) + str(object_id)

                        print('Sending objenct name: ' + object_id)
                        conn.send(object_id.encode('utf-8'))
                    case 2:
                        # Get position
                        #|ID|OBJECT ID|REFERENCE|         TX ->
                        #|ID|DATA POSITION X|DATA POSITION Y|           RX <-
                        print('Getting position information')
                        object_id = int(message_data[0:2])
                        objectHandle_reference = int(message_data[2:])
                        print('ID: ' + str(object_id))
                        print('Reference: ' + str(objectHandle_reference))

                        data_position = sim.getObjectPosition(object_id, objectHandle_reference)
                        print('Position ' + str(data_position[0]) + ','+ str(data_position[1]) + ','+ str(data_position[2]))
                        data_position_adjusted = round_num(data_position)
                        print('Adjusted Position ' + str(data_position_adjusted[0]) + ','+ str(data_position_adjusted[1]) + ','+ str(data_position_adjusted[2]))

                        data_position_tx = str(3) + str(data_position_adjusted[0]) + str(data_position_adjusted[1]) + str(data_position_adjusted[2])
                        
                        print('Data: ' + data_position_tx)
                        conn.send(data_position_tx.encode('utf-8'))
                    case 4:
                        # Set position
                        #|ID|OBJECT ID|DATA POSITION X|DATA POSITION Y|DATA POSITION Z|REFERENCE|         TX ->
                        #|ID|                                                                             RX <-
                        print('Getting NEW position information')                                                                    
                        object_id = int(message_data[0:2])                                         
                        new_position = [float(message_data[2:8]),float(message_data[8:14]),float(message_data[14:20])]
                        objectHandle_reference = int(message_data[20:])
                        print('ID: ' + str(object_id))
                        print('Position: ' + str(new_position[0]) + ',' + str(new_position[1]) + ',' + str(new_position[2]) + ',')
                        print('Reference: ' + str(objectHandle_reference))
                        returnCode = sim.setObjectPosition(object_id, new_position, objectHandle_reference)
                        data = str(5) + str("00")
                        conn.send(data.encode('utf-8'))
                    case _:
                        break

            #Stop the simulation Ctrl+C
            print('\nStopping Simulation...')
            sim.stopSimulation()
            print('\nClossing connection with Remote API...')
            s.close()

if __name__ == '__main__':
    drone_position(sys.argv)
