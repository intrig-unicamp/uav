import sys
import os

other_script_path = 'client_zmq_rxtx.py'

def kill_process():
    os.system('pkill -9 -f client_zmq_rxtx.py')
    os.system('pkill -9 -f remote_api.py')
    os.system('pkill -9 -f client_run.py')

if __name__ == '__main__':
    kill_process()