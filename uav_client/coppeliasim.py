#!/usr/bin/python

'UAVs represented as stations using CoppeliaSim'

import time
import os

def sim():

    print("*** Starting CoppeliaSim\n")
    path = os.path.dirname(os.path.abspath(__file__))
    os.system('{}/CoppeliaSim_Edu_Ubuntu/coppeliaSim.sh -s {}'
              '/simulation.ttt -gGUIITEMS_2 &'.format(path, path))

if __name__ == '__main__':
    sim()