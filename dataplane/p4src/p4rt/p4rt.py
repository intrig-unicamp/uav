import p4runtime_sh.shell as sh
import argparse

sh.setup(
        device_id=1,
        grpc_addr='',  #Update with the Stratum IP
        election_id=(0, 1), # (high, low)
        config=sh.FwdPipeConfig('/workspace/output_dir/p4info.txt', '/workspace/output_dir/pipeline_config.pb.bin')
        )

te = sh.TableEntry('SwitchIngress.vlan_fwd')(action='SwitchIngress.match')
te.match['vid'] = '1920'
te.match['ingress_port'] = '132'
te.action['link']  = '0'
te.insert()

te = sh.TableEntry('SwitchIngress.vlan_fwd')(action='SwitchIngress.match')
te.match['vid'] = '1920'
te.match['ingress_port'] = '134'
te.action['link']  = '1'
te.insert()

te = sh.TableEntry('SwitchIngress.arp_fwd')(action='SwitchIngress.match_arp')
te.match['vid'] = '1920'
te.match['ingress_port'] = '132'
te.action['link']  = '0'
te.insert()

te = sh.TableEntry('SwitchIngress.arp_fwd')(action='SwitchIngress.match_arp')
te.match['vid'] = '1920'
te.match['ingress_port'] = '134'
te.action['link']  = '1'
te.insert()

te = sh.TableEntry('SwitchIngress.basic_fwd')(action='SwitchIngress.send')
te.match['sw'] = '1'
te.match['dest_ip'] = '192.168.100.2'
te.action['port']  = '134'
te.insert()

te = sh.TableEntry('SwitchIngress.basic_fwd')(action='SwitchIngress.send_next')
te.match['sw'] = '1'
te.match['dest_ip'] = '192.168.100.110'
te.action['sw_id']  = '0'
te.insert()

te = sh.TableEntry('SwitchIngress.basic_fwd')(action='SwitchIngress.send')
te.match['sw'] = '0'
te.match['dest_ip'] = '192.168.100.110'
te.action['port']  = '132'
te.insert()

te = sh.TableEntry('SwitchIngress.basic_fwd')(action='SwitchIngress.send_next')
te.match['sw'] = '0'
te.match['dest_ip'] = '192.168.100.2'
te.action['sw_id']  = '1'
te.insert()

te = sh.TableEntry('SwitchIngress.vlan_fwd')(action='SwitchIngress.send_direct')
te.match['vid'] = '716'
te.match['ingress_port'] = '133'
te.action['port']  = '135'
te.insert()

te = sh.TableEntry('SwitchIngress.vlan_fwd')(action='SwitchIngress.send_direct')
te.match['vid'] = '716'
te.match['ingress_port'] = '135'
te.action['port']  = '133'
te.insert()

sh.teardown()
