In-network P4-based Unmanned Aerial Vehicle Collision Avoidance Algorithm
==

# About In-network P4-based Collision Avoidance Algorithm
This work delves into the potential of in-network solutions to enhance performance and safety using programmable data plane technologies, particularly P4. The main contribution relies on implementing an in-network collision avoidance algorithm for UAVs, facilitating real-time obstacle navigation and collision prevention. By integrating P4-based solutions, this work demonstrates significant latency, responsiveness, and reliability improvements over traditional approaches, opening new application possibilities.

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

# Setup
To facilitate the hardware setup of different scenarios, the [P7 (P4 Programmable Patch Panel: an instant 100G emulated network testbed in a pizza box)](https://github.com/intrig-unicamp/p7) emulator creates an environment that allows us to define and modify various link metrics. The P4 code with the link metrics configuration is defined using P7 over a Tofino switch. The UAVs and their physics and flying logic will be simulated in [CoppeliaSim](https://www.coppeliarobotics.com/) (1), which runs on another server. P7 will define the link metrics, which can be customized in the emulator. For example, the first (2) represents the Access and Edge of a 5G network, while the second (4) represents the MEC or Cloud. The collision avoidance logic implemented using P4 code will run in the switch and be managed by P7 (3). Lastly, the remote API (5) will run a Python script to establish a connection with the UAVs.

![](https://github.com/intrig-unicamp/uav/blob/main/fig/topo.png)

Considering the scenario, the setup will be divided into three sections: (i) UAV client, (ii) P4 Data Plane, and (iii) Remote API.

First, clone the repository in each device (Host, Tofino Switch, and Server)

```
git clone https://github.com/intrig-unicamp/uav.git
```

## (i) UAV client - Host
For the client running the UAV simulation in CoppeliaSim, we need to start the simulation UAV environment and the client sender.

Since the P7 emulator requires a specific VLAN for internal processing, the first step is to create the necessary VLAN in the system. In this example, we use the interface enp3s0f0, the VLAN 1920 (this VLAN tag needs to be aligned with the one defined in the P7 config file), and the IP 192.168.100.110:

### Configure VLAN ports
```
sudo ip link add link enp3s0f0 name enp3s0f0.1920 type vlan id 1920
sudo ifconfig enp3s0f0.1920 192.168.100.110 up
```

### Install CoppeliaSim
After setting the network interface, we need to install **CoppeliaSim** and the **zmqremoteapi-client** library:

```
cd ~/uav/uav_client
sudo ./install.sh
python3 -m pip install coppeliasim-zmqremoteapi-client
```

### Start CoppeliaSim
Then start the **CoppeliaSim** environemnt and open the project `~/uav_client/Drones.ttt`:

```
cd CoppeliaSim_Edu_Ubuntu
./coppeliaSim.sh -f ../Drones.ttt
```

### Run Simulation in CoppeliaSim
In the **CoppeliaSim** environment. Start the simulation by pressing the `Start simulation` button ▶.

### Start ZMQ Client
With the Coppeliasim running, we need to start the ZMQ client:

```
cd ~/uav/uav_client
sudo python client_run.py
python client_zmq_rxtx.py
```

> [!NOTE]
> The `python client_run.py` is intended to clean the environment for possible background scripts running with the ZMQ client.

> [!TIP]
> For any issue related to CoppeliaSim, please refer to its official [documentation](https://manual.coppeliarobotics.com/).

## (ii) P4 Data Plane - Tofino Switch
The core part of the environment is the P4 code, where the collision avoidance algorithm will act, and all communication will be synchronized.

For tuning the environment, it is recommended that at least three terminals be used: one for the P7 emulator, one to compile and run the P4 code, and a third to fill the tables and set up the ports.

### Terminal 1 - Prepare the P7 environment
The P7 `main.py` file defines how the P4 emulation will be performed. Aligning the configuration with the environment is important to prepare the switch.

> [!WARNING]
> Take special care with the network configuration (i.e., IP, VLAN); this needs to be aligned with your environment
> Also, verify the Tofino port numbers (i.e., port, D_P, speed, AU, FEC) and pipeline configuration to set up the switch correctly.

For the pipelines check the file `~/dataplane/main.py` lines `21-26`

``` python
# Recirculation ports
# In this example, the P7 main pipe is 1 and the user defined is 0
# P7 main pipe (pipe 1 = 196)
topo.addrec_port(196)
# Custom user pipe (pipe 0 = 68)
topo.addrec_port_user(68)
```

For the ports check the file `~/dataplane/main.py` lines `33-36`

``` python
# addhost(name, port, D_P, speed_bps, AU, FEC, vlan, IP)
# include the link configuration
topo.addhost("h1","1/0", 132, 10000000000, "False", "False", 1920, "192.168.100.110")
topo.addhost("h2","1/2", 134, 10000000000, "False", "False", 1920, "192.168.100.2")
```

After verifying the initial setup, we can compile and generate all the necessary files to run the Tofino switch:

```
cd ~/uav/dataplane
sudo python3 main.p7
./set_files
```

> [!NOTE]
> More details about how P7 works, please refere to its [wiki](https://github.com/intrig-unicamp/p7/wiki)

### Terminal 2 - Compile and run the P4 code
To compile and run the P4 code, you need access to the P4 Studio from INTEL and the necessary supporting tools. The code was validated and tested with version `bf-sde-9.12.0`. The P7 emulator generates the P4 codes necessary to run, as well as the custom pipeline configuration file, since the P7 uses two pipelines for running the environment.

```
cd ~/bf-sde-9.12.0
. ../tools/set_sde.bash
../tools/p4_build.sh ~/uav/dataplane/p4src/p7uav_mod.p4
../tools/p4_build.sh ~/uav/dataplane/p4src/p7_default.p4
./run_switchd.sh -p p7_default p7calc_mod -c /~/uav/dataplane/p4src/multiprogram_custom_bfrt.conf
```

> [!NOTE]
> For any additional information regarding the SDE compilation process and issues, please refer to the INTEL [forum](https://community.intel.com/t5/Intel-Connectivity-Research/gh-p/connectivity-research-program)

> [!TIP]
> When running the switch, if the driver fails to load, you can run the command `bf_kdrv_mod_load $SDE_INSTALL`

### Terminal 3 - Configure tables and ports
When the P7 emulator is compiled, all the necessary files are generated, including the tables and ports configuration. Using these generated files, we configure the Tofino Switch.

```
cd ~/bf-sde-9.12.0
. ../tools/set_sde.bash
bfshell -b ~/uav/dataplane/files/bfrt.py
bfshell -f ~/uav/dataplane/files/ports_config.txt -i
```

> [!TIP]
> You do not need to edit the ports configuration file; it follows the configuration defined in the `main.py` P7 file.

## (iii) Remote API - Server
The Remote API starts a connection with the ZMQ Client to define each UAV's initial configuration and target position.

### Configure VLAN ports
Similar to the Client, we need to define the network interfaces with the correct IP and VLAN tag:

```
sudo ip link add link enp6s0f0 name enp6s0f0.1920 type vlan id 1920
sudo ifconfig enp6s0f0.1920 192.168.100.2 up
```

### Running the Remote API
For the remote API, we use a Python script that establishes the remote connection with the Client and sends the environment setup to start the test.

```
cd ~/uav/remote_api/
python remote_api.py dr1 dr2 dr3 1.45 -0.25 0.51 3 0.001
```

> [!TIP]
> Before running the server, validate that everything runs correctly in the Tofino switch and the client.

## Contributing
PRs are very much appreciated. For bugs/features, consider creating an issue before sending a PR.

## Team
We are members of [INTRIG (Information & Networking Technologies Research & Innovation Group)](http://intrig.dca.fee.unicamp.br) at the University of Campinas—Unicamp, SP, Brazil.