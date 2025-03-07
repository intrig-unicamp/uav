#include <tna.p4>

/*************************************************************************
 ************* C O N S T A N T S    A N D   T Y P E S  *******************
**************************************************************************/

typedef bit<48> mac_addr_t;
typedef bit<32> ipv4_addr_t;
typedef bit<128> ipv6_addr_t;
typedef bit<12> vlan_id_t;


typedef bit<16> ether_type_t;
const ether_type_t ETHERTYPE_IPV4 = 16w0x0800;
const ether_type_t ETHERTYPE_REC = 16w0x9966;
const ether_type_t ETHERTYPE_ARP = 16w0x0806;
const ether_type_t ETHERTYPE_IPV6 = 16w0x86dd;
const ether_type_t ETHERTYPE_VLAN = 16w0x8100;
const bit<8> UDP_TYPE = 8w0x11;
const bit<8> TCP_TYPE = 8w0x06;
const bit<16> SRC_TCP = 16w0x15b3;  //src_port = 5555

// Message ID
// Identify the packet ID
// 0   get objects ID Request
// 1   get objects ID Reply
// 2   get position Request
// 3   get position Reply
// 4   set position Request
// 5   set position Reply
// 6-9 Reserved
const bit<4> object_id_request =    4w0x0;        //ID = 0
const bit<4> object_id_reply =      4w0x1;        //ID = 1
const bit<4> get_position_request = 4w0x2;        //ID = 2
const bit<4> get_position_reply =   4w0x3;        //ID = 3
const bit<4> set_position_request = 4w0x4;        //ID = 4
const bit<4> set_position_reply =   4w0x5;        //ID = 5

// Mirror packer
typedef bit<8>  pkt_type_t;
const pkt_type_t PKT_TYPE_NORMAL = 1;
const pkt_type_t PKT_TYPE_MIRROR = 2;
typedef bit<3> mirror_type_t;
const mirror_type_t MIRROR_TYPE_I2E = 1;

/***********************  H E A D E R S  ************************/

header ethernet_h {
    mac_addr_t dst_addr;
    mac_addr_t src_addr;
    bit<16> ether_type;
}

// Address Resolution Protocol -- RFC 6747
header arp_h {
    bit<16> hw_type;
    bit<16> proto_type;
    bit<8> hw_addr_len;
    bit<8> proto_addr_len;
    bit<16> opcode;
    bit<48> hwSrcAddr;
    bit<32> protoSrcAddr;
    bit<48> hwDstAddr;
    bit<32> dest_ip;
}

header vlan_tag_h {
    bit<3> pcp;
    bit<1> cfi;
    vlan_id_t vid;
    bit<16> ether_type;
}

header ipv4_h {
    bit<4> version;
    bit<4> ihl;
    bit<8> diffserv;
    bit<16> total_len;
    bit<16> identification;
    bit<16> flags;
    bit<8> ttl;
    bit<8> protocol;
    bit<16> hdr_checksum;
    ipv4_addr_t src_addr;
    ipv4_addr_t dst_addr;
}

header tcp_h {
    bit<16> sport;
    bit<16> dport;
    bit<32> seq_no;
    bit<32> ack_no;
    bit<4>  data_offset;
    bit<3>  res;
    bit<3>  ecn;
    bit<6>  ctrl;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgent_ptr;
    bit<96> options;
}

// Message ID
header id_h {
    bit<4>  val;
    bit<4>  id;
}

// get position Request
header position_id_h {
    bit<16> object_id;
    bit<16> reference;
}

// get position Reply
header position_h {
    bit<16> object_id;
    bit<48> x;
    bit<48> y;
    bit<48> z;
}

// New Set position request
header new_payload_h {
    bit<16> object_id;
    bit<48> x;
    bit<48> y;
    bit<48> z;
    bit<16> reference;
}

struct empty_header_t {}

struct empty_metadata_t {}

struct my_ingress_metadata_t {
    bit<1> recalculate_ipv4_checksum;
    bit<1> recalculate_tcp_checksum;
    bit<16> new_object_id_mod;
    bit<16> x_pos_hex;
    bit<16> y_pos_hex;
    bit<16> collision_detected;

    bit<16> ipv4_id;
    bit<32> tcp_seq;
    bit<32> tcp_len;

    bit<16> tcpLength;

    bit<1> do_ing_mirroring;  // Enable ingress mirroring
    MirrorId_t ing_mir_ses;   // Ingress mirror session ID
    pkt_type_t pkt_type;

    bit<16> checksum_tcp_tmp;

    bit<16> collision_ok;
}

header rec_h {
	bit<32> ts;
	bit<32> num;
	bit<32> jitter;
	bit<16> sw;
	bit<16> sw_id;
	bit<16> ether_type;
	bit<32> dest_ip;
	bit<1> signal;
	bit<31> pad;
}

struct headers {
    ethernet_h      ethernet;
	rec_h	rec;
    arp_h           arp;
    vlan_tag_h      vlan_tag;
    ipv4_h          ipv4;
    tcp_h           tcp;
    id_h            id;
    position_id_h   position_id;
    position_h      position;
    new_payload_h   new_payload;
}


/*************************************************************************
 **************  I N G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/


parser SwitchIngressParser(
       packet_in packet, 
       out headers hdr, 
       out my_ingress_metadata_t md,
       out ingress_intrinsic_metadata_t ig_intr_md) {

    Checksum() ipv4_checksum;
    Checksum() tcp_checksum;

    state start {
        packet.extract(ig_intr_md);
        packet.advance(PORT_METADATA_SIZE);
        transition parse_ethernet;
    }

    state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {

			16w0x9966:   parse_rec;

            ETHERTYPE_IPV4:  parse_ipv4;
            ETHERTYPE_VLAN:  parse_vlan;
            default: accept;
        }
    }

	state parse_rec { 
		packet.extract(hdr.rec);
		transition select(hdr.rec.ether_type){
            ETHERTYPE_IPV4:  parse_ipv4;
            ETHERTYPE_VLAN:  parse_vlan;
            default: accept;
        }
	}
    
    state parse_vlan {
        packet.extract(hdr.vlan_tag);
        transition select(hdr.vlan_tag.ether_type) {
            ETHERTYPE_IPV4:  parse_ipv4;
            default: accept;
        }
    }

    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        ipv4_checksum.add(hdr.ipv4);
        tcp_checksum.subtract({hdr.ipv4.src_addr});
        transition select(hdr.ipv4.protocol) {
            TCP_TYPE: parse_tcp;
            default: accept;
        }
    }

    state parse_tcp {
        packet.extract(hdr.tcp);
        tcp_checksum.subtract({hdr.tcp.checksum});
        tcp_checksum.subtract({hdr.tcp.sport});
        md.checksum_tcp_tmp = tcp_checksum.get();
        transition select(hdr.tcp.sport) {
            SRC_TCP:  parse_id;
            default: accept;
        }
    }

    state parse_id {
        packet.extract(hdr.id);
        transition select(hdr.id.id) {
            object_id_request:      accept;
            object_id_reply:        accept;
            get_position_request:   parse_position_request;
            get_position_reply:     parse_position_reply;
            set_position_request:   accept;
            set_position_reply:     accept;
            default: accept;
        }
    }

    state parse_position_request {
        packet.extract(hdr.position_id);
        transition accept;
    }

    state parse_position_reply {
        packet.extract(hdr.position);
        transition accept;
    }
}

control SwitchIngressDeparser(
        packet_out pkt,
        inout headers hdr,
        in my_ingress_metadata_t ig_md,
        in ingress_intrinsic_metadata_for_deparser_t ig_intr_dprsr_md) {

    Mirror() mirror;

    Checksum() ipv4_checksum;
    Checksum() tcp_checksum;

    apply {

        if (ig_md.recalculate_ipv4_checksum == 1){
            hdr.ipv4.hdr_checksum = ipv4_checksum.update({
                hdr.ipv4.version,
                hdr.ipv4.ihl,
                hdr.ipv4.diffserv,
                hdr.ipv4.total_len,
                hdr.ipv4.identification,
                hdr.ipv4.flags,
                hdr.ipv4.ttl,
                hdr.ipv4.protocol,
                hdr.ipv4.src_addr,
                hdr.ipv4.dst_addr
            });
        }
        if (ig_md.recalculate_tcp_checksum == 1){
            hdr.tcp.checksum = tcp_checksum.update({
                hdr.ipv4.src_addr,
                hdr.ipv4.dst_addr,
                8w0,
                hdr.ipv4.protocol,
                ig_md.tcpLength,
                hdr.tcp.sport,
                hdr.tcp.dport,
                hdr.tcp.seq_no,
                hdr.tcp.ack_no,
                hdr.tcp.data_offset,
                hdr.tcp.res,
                hdr.tcp.ecn,
                hdr.tcp.ctrl,
                hdr.tcp.window,
                hdr.tcp.urgent_ptr,
                hdr.tcp.options
            });
        }

        pkt.emit(hdr);

        if (ig_intr_dprsr_md.mirror_type == 2) {
            mirror.emit(ig_md.ing_mir_ses);
        }

    }
}

control SwitchIngress(
        inout headers hdr, 
        inout my_ingress_metadata_t md,
        in ingress_intrinsic_metadata_t ig_intr_md,
        in ingress_intrinsic_metadata_from_parser_t ig_intr_prsr_md,
        inout ingress_intrinsic_metadata_for_deparser_t ig_intr_dprsr_md,
        inout ingress_intrinsic_metadata_for_tm_t ig_intr_tm_md) {

    bit<16> x_pos_int = 0;
    bit<16> y_pos_int = 0;

    bit<16> collision_1 = 0;
    bit<16> collision_1_l = 0;

    bit<16> collision_2 = 0;
    bit<16> collision_2_l = 0;

    bit<16> collision_3 = 0;
    bit<16> collision_3_l = 0;

    bit<8> object_id = 0;
    bit<16> object_index = 0;

    bit<16> ipv4_tcp_len_reg = 0;

    // New heder temporal values
    mac_addr_t mac_addr = 0;
    ipv4_addr_t ipv4_addr = 0;
    bit<16> tcp_port = 0;

    // Enable mirror packet
    action set_mirror_type() {
        ig_intr_dprsr_md.mirror_type = 2;
        md.ing_mir_ses = 2;
    }

    // Register to save collision status
    Register <bit<16>, _> (32w1)  collision_sent;

    RegisterAction<bit<16>, bit<16>, bit<16>>(collision_sent) collision_sent_action = {
        void apply(inout bit<16> value){
            value = 1;
        }
    };

    RegisterAction<bit<16>, bit<16>, bit<16>>(collision_sent) collision_sent_get_action = {
        void apply(inout bit<16> value, out bit<16> readvalue){
            readvalue = value;
            value = 0;
        }
    };

    // Register to save tcp seq
    Register <bit<32>, _> (32w1)  tcp_seq_num;
    // Register to save ipv4 
    Register <bit<16>, _> (32w1)  ipv4_len_num;
    // Register to save tcp len
    Register <bit<16>, _> (32w1)  tcp_len_num;

    RegisterAction<bit<32>, bit<32>, bit<32>>(tcp_seq_num) tcp_seq_num_action = {
        void apply(inout bit<32> value){
            value = hdr.tcp.seq_no;
        }
    };

    RegisterAction<bit<32>, bit<32>, bit<32>>(tcp_seq_num) tcp_seq_num_get_action = {
        void apply(inout bit<32> value, out bit<32> readvalue){
            readvalue = value;
        }
    };

    RegisterAction<bit<16>, bit<16>, bit<16>>(ipv4_len_num) ipv4_len_num_action = {
        void apply(inout bit<16> value){
            value = hdr.ipv4.identification;
        }
    };

    RegisterAction<bit<16>, bit<16>, bit<16>>(ipv4_len_num) ipv4_len_num_get_action = {
        void apply(inout bit<16> value, out bit<16> readvalue){
            readvalue = value;
        }
    };

    RegisterAction<bit<16>, bit<16>, bit<16>>(tcp_len_num) tcp_len_num_action = {
        void apply(inout bit<16> value){
            value = hdr.ipv4.total_len - 52;
        }
    };

    RegisterAction<bit<16>, bit<16>, bit<16>>(tcp_len_num) tcp_len_num_get_action = {
        void apply(inout bit<16> value, out bit<16> readvalue){
            readvalue = value;
        }
    };

    // Register per UAV
    Register <bit<16>, _> (32w1)  uav1;
    Register <bit<16>, _> (32w1)  uav2;
    Register <bit<16>, _> (32w1)  uav3;

    Register <bit<16>, _> (32w1)  uav4;

    Register <bit<16>, _> (32w1)  uav1_l;
    Register <bit<16>, _> (32w1)  uav2_l;
    Register <bit<16>, _> (32w1)  uav3_l;

    Register <bit<16>, _> (32w1)  uav4_l;

    RegisterAction<bit<16>, bit<16>, bit<16>>(uav1) uav1_update_action = {
        void apply(inout bit<16> value){
            value = md.x_pos_hex;
        }
    };

    RegisterAction<bit<16>, bit<16>, bit<16>>(uav1) uav1_check_action = {
        void apply(inout bit<16> value, out bit<16> readvalue){
            // if (((md.x_pos_hex - value) < 10) && ((md.y_pos_hex - value) < 10)){
            //     readvalue = 1;
            // }
            // else{
            //     readvalue = 0;
            // }

            if (md.x_pos_hex > (value-10) && md.x_pos_hex < (value+10)){
                    readvalue = 1;
            }
            else{
                readvalue = 0;
            }
        }
    };

    RegisterAction<bit<16>, bit<16>, bit<16>>(uav1_l) uav1_l_update_action = {
        void apply(inout bit<16> value){
            value = md.y_pos_hex;
        }
    };

    RegisterAction<bit<16>, bit<16>, bit<16>>(uav1_l) uav1_l_check_action = {
        void apply(inout bit<16> value, out bit<16> readvalue){
            if (md.y_pos_hex > (value-10) && md.y_pos_hex < (value+10)){
                readvalue = 1;
            }
            else{
                readvalue = 0;
            }
        }
    };

    RegisterAction<bit<16>, bit<16>, bit<16>>(uav2) uav2_update_action = {
        void apply(inout bit<16> value){
            value = md.x_pos_hex;
        }
    };

    RegisterAction<bit<16>, bit<16>, bit<16>>(uav2) uav2_check_action = {
        void apply(inout bit<16> value, out bit<16> readvalue){
            if (md.x_pos_hex > (value-10) && md.x_pos_hex < (value+10)){
                    readvalue = 1;
            }
            else{
                readvalue = 0;
            }
        }
    };

    RegisterAction<bit<16>, bit<16>, bit<16>>(uav2_l) uav2_l_update_action = {
        void apply(inout bit<16> value){
            value = md.y_pos_hex;
        }
    };

    RegisterAction<bit<16>, bit<16>, bit<16>>(uav2_l) uav2_l_check_action = {
        void apply(inout bit<16> value, out bit<16> readvalue){
            if (md.y_pos_hex > (value-10) && md.y_pos_hex < (value+10)){
                readvalue = 1;
            }
            else{
                readvalue = 0;
            }
        }
    };

    RegisterAction<bit<16>, bit<16>, bit<16>>(uav3) uav3_update_action = {
        void apply(inout bit<16> value){
            value = md.x_pos_hex;
        }
    };

    RegisterAction<bit<16>, bit<16>, bit<16>>(uav3) uav3_check_action = {
        void apply(inout bit<16> value, out bit<16> readvalue){
            if (md.x_pos_hex > (value-10) && md.x_pos_hex < (value+10)){
                    readvalue = 1;
            }
            else{
                readvalue = 0;
            }
        }
    };

    RegisterAction<bit<16>, bit<16>, bit<16>>(uav3_l) uav3_l_update_action = {
        void apply(inout bit<16> value){
            value = md.y_pos_hex;
        }
    };

    RegisterAction<bit<16>, bit<16>, bit<16>>(uav3_l) uav3_l_check_action = {
        void apply(inout bit<16> value, out bit<16> readvalue){
            if (md.y_pos_hex > (value-10) && md.y_pos_hex < (value+10)){
                readvalue = 1;
            }
            else{
                readvalue = 0;
            }
        }
    };


    ///////
    RegisterAction<bit<16>, bit<16>, bit<16>>(uav4) uav4_update_action = {
        void apply(inout bit<16> value){
            value = md.x_pos_hex;
        }
    };

    RegisterAction<bit<16>, bit<16>, bit<16>>(uav4) uav4_check_action = {
        void apply(inout bit<16> value, out bit<16> readvalue){
            if (md.x_pos_hex > (value-10) && md.x_pos_hex < (value+10)){
                    readvalue = 1;
            }
            else{
                readvalue = 0;
            }
        }
    };

    RegisterAction<bit<16>, bit<16>, bit<16>>(uav4_l) uav4_l_update_action = {
        void apply(inout bit<16> value){
            value = md.y_pos_hex;
        }
    };

    RegisterAction<bit<16>, bit<16>, bit<16>>(uav4_l) uav4_l_check_action = {
        void apply(inout bit<16> value, out bit<16> readvalue){
            if (md.y_pos_hex > (value-10) && md.y_pos_hex < (value+10)){
                readvalue = 1;
            }
            else{
                readvalue = 0;
            }
        }
    };

    ////

    action drop() {
        ig_intr_dprsr_md.drop_ctl = 0x1;
    }

    action forward(){
        ig_intr_tm_md.bypass_egress = 1w1;
    }

    action dectohex_x(bit<16> hexval){
        md.x_pos_hex = hexval;
    }

    action dectohex_y(bit<16> hexval){
        md.y_pos_hex = hexval;
    }

    // Collision avoidance action
    action collision_action(bit<48> new_x,
                            bit<48> new_y,
                            bit<48> new_z){
        // Updating packet headers
        // P7 -> send back the packet
        hdr.rec.sw = 0;
        hdr.rec.dest_ip = hdr.ipv4.dst_addr;
        // Ethernet
        mac_addr = hdr.ethernet.dst_addr;
        hdr.ethernet.dst_addr = hdr.ethernet.src_addr;
        hdr.ethernet.src_addr = mac_addr;
        // IP
        hdr.ipv4.total_len = 75;
        hdr.ipv4.identification = md.ipv4_id + 1;
        ipv4_addr = hdr.ipv4.src_addr;
        hdr.ipv4.src_addr = hdr.ipv4.dst_addr;
        hdr.ipv4.dst_addr = ipv4_addr;
        // TCP
        tcp_port = hdr.tcp.sport;
        hdr.tcp.sport = hdr.tcp.dport;
        hdr.tcp.dport = tcp_port;
        hdr.tcp.ack_no = hdr.tcp.seq_no + 23;
        hdr.tcp.seq_no = md.tcp_seq + md.tcp_len;
        // Set new message ID = 4
        hdr.id.id = set_position_request;
        // Disable position header
        hdr.position.setInvalid();
        // Enable New playload
        hdr.new_payload.setValid();
        // Seting new header values
        // object_id = 65
        // x = 0.0100
        // y = -0.020
        // z = 0.0000
        // reference = 65
        // hdr.new_payload.object_id = 16w0x3635;
        // hdr.new_payload.x = 48w0x302e30313030;
        // hdr.new_payload.y = 48w0x2d302e303230;
        // hdr.new_payload.z = 48w0x302e30303030;
        // hdr.new_payload.reference = 16w0x3635;
        hdr.new_payload.object_id = md.new_object_id_mod;
        hdr.new_payload.x = new_x;
        hdr.new_payload.y = new_y;
        hdr.new_payload.z = new_z;
        hdr.new_payload.reference = md.new_object_id_mod;
    }

    table transform_x{
        key = {
			hdr.rec.sw_id   : exact;
            x_pos_int : exact;
        }
        actions = {
            dectohex_x;
            @defaultonly forward;
        }
        const default_action = forward();
        size = 5000;
    }

    table transform_y{
        key = {
			hdr.rec.sw_id   : exact;
            y_pos_int : exact;
        }
        actions = {
            dectohex_y;
            @defaultonly forward;
        }
        const default_action = forward();
        size = 5000;
    }

    table check_collision{
        key = {
			hdr.rec.sw_id   : exact;
            md.x_pos_hex : range;
            md.y_pos_hex : range;
        }
        actions = {
            collision_action;
            @defaultonly forward;
        }
        const default_action = forward();
        size = 2048;
    }

    apply { 
        // Not mirror packets
        ig_intr_dprsr_md.mirror_type = 1;
        md.ing_mir_ses = 1;
        
        // Checksum validation flag
        md.recalculate_ipv4_checksum = 0;
        md.recalculate_tcp_checksum = 0;

        // Collision detection in process flag
        md.collision_ok = 0;
        
        if(!hdr.position.isValid() && hdr.tcp.dport == 5555){     
            // md.collision_ok = collision_sent_get_action.execute(0);
            if(hdr.id.id == set_position_request){
                drop();
            }  
            // Sabe the tcp seq number
            tcp_seq_num_action.execute(0);
            // Save the ipv4 id
            ipv4_len_num_action.execute(0);
            // Save the tcp segment len
            tcp_len_num_action.execute(0);
        }
        else if(hdr.position.isValid()){
            // Extract position
            // The position cames in ASCII format
            // to exptract, we skipt the first 4 bits 
            // of each byte group.
            x_pos_int[15:12] = hdr.position.x[43:40];
            x_pos_int[11:8] = hdr.position.x[27:24];
            x_pos_int[7:4] = hdr.position.x[19:16];
            x_pos_int[3:0] = hdr.position.x[11:8];
            y_pos_int[15:12] = hdr.position.y[43:40];
            y_pos_int[11:8] = hdr.position.y[27:24];
            y_pos_int[7:4] = hdr.position.y[19:16];
            y_pos_int[3:0] = hdr.position.y[11:8];  

            // Save the drone referece ID in ASCII format
            if (hdr.position.object_id == 0x3339){
                md.new_object_id_mod = 0x3430;
            }
            else if (hdr.position.object_id == 0x3634){
                md.new_object_id_mod = 0x3635;
            }
            else{
                md.new_object_id_mod = 0x3930;
            }

            // Transform the HEX extracted from the ASCII 
            // format to an valid HEX to process the information.
            // Result in md.x_pos_hex and md.y_pos_hex
            transform_x.apply();
            transform_y.apply();

            // Retrive the information from the registers
            md.tcp_seq = tcp_seq_num_get_action.execute(0);
            md.ipv4_id = ipv4_len_num_get_action.execute(0);
            ipv4_tcp_len_reg = ipv4_len_num_get_action.execute(0);
            md.tcp_len = 0;
            md.tcp_len[15:0] = ipv4_tcp_len_reg;

            // Check collision with objects
            // In case of collision applu the avoidance process.
            // If there is not a collision with an object,
            // validate a possible collision with other drones.
            if(!check_collision.apply().hit){
                if (hdr.position.object_id == 0x3339){
                    // Update the position register of the current drone.
                    // Validate collision with the other drones.
                    uav1_update_action.execute(0);
                    uav1_l_update_action.execute(0);
                    // X axis collision detection
                    collision_1 = uav2_check_action.execute(0);
                    // Y axis collision detection
                    if (collision_1 == 1){
                        collision_1_l = uav2_l_check_action.execute(0);
                    }
                    // X axis collision detection
                    collision_2 = uav3_check_action.execute(0);
                    // Y axis collision detection
                    if (collision_2 == 1){
                        collision_2_l = uav3_l_check_action.execute(0);
                    }
                    collision_3 = uav4_check_action.execute(0);
                    // Y axis collision detection
                    if (collision_3 == 1){
                        collision_3_l = uav4_l_check_action.execute(0);
                    }

                    // hdr.ethernet.src_addr = 48w0x111111111111;
                    // hdr.ethernet.dst_addr = 48w0x111111111111;
                }
                else {
                    if (hdr.position.object_id == 0x3634){
                        // Update the position register of the current drone.
                        // Validate collision with the other drones.
                        uav2_update_action.execute(0);
                        uav2_l_update_action.execute(0);
                        // X axis collision detection
                        collision_1 = uav1_check_action.execute(0);
                        // Y axis collision detection
                        if (collision_1 == 1){
                            collision_1_l = uav1_l_check_action.execute(0);
                        }
                        // X axis collision detection
                        collision_2 = uav3_check_action.execute(0);
                        // Y axis collision detection
                        if (collision_2 == 1){
                            collision_2_l = uav3_l_check_action.execute(0);
                        }

                        collision_3 = uav4_check_action.execute(0);
                        // Y axis collision detection
                        if (collision_3 == 1){
                            collision_3_l = uav4_l_check_action.execute(0);
                        }

                        // hdr.ethernet.src_addr = 48w0x222222222222;
                        // hdr.ethernet.dst_addr = 48w0x222222222222;
                    }
                    else{
                        if (hdr.position.object_id == 0x3839){
                            // Update the position register of the current drone.
                            // Validate collision with the other drones.
                            uav3_update_action.execute(0);
                            uav3_l_update_action.execute(0);
                            // X axis collision detection
                            collision_1 = uav1_check_action.execute(0);
                            // Y axis collision detection
                            if (collision_1 == 1){
                                collision_1_l = uav1_l_check_action.execute(0);
                            }
                            // X axis collision detection
                            collision_2 = uav2_check_action.execute(0);
                            // Y axis collision detection
                            if (collision_2 == 1){
                                collision_2_l = uav2_l_check_action.execute(0);
                            }

                            collision_3 = uav4_check_action.execute(0);
                            // Y axis collision detection
                            if (collision_3 == 1){
                                collision_3_l = uav4_l_check_action.execute(0);
                            }

                            // hdr.ethernet.src_addr = 48w0x222222222222;
                            // hdr.ethernet.dst_addr = 48w0x222222222222;
                        }
                        else{
                            // Update the position register of the current drone.
                            // Validate collision with the other drones.
                            uav4_update_action.execute(0);
                            uav4_l_update_action.execute(0);
                            // X axis collision detection
                            collision_1 = uav1_check_action.execute(0);
                            // Y axis collision detection
                            if (collision_1 == 1){
                                collision_1_l = uav1_l_check_action.execute(0);
                            }
                            // X axis collision detection
                            collision_2 = uav2_check_action.execute(0);
                            // Y axis collision detection
                            if (collision_2 == 1){
                                collision_2_l = uav2_l_check_action.execute(0);
                            }
                            collision_3 = uav3_check_action.execute(0);
                            // Y axis collision detection
                            if (collision_3 == 1){
                                collision_3_l = uav3_l_check_action.execute(0);
                            }
                            // hdr.ethernet.src_addr = 48w0x333333333333;
                            // hdr.ethernet.dst_addr = 48w0x333333333333;
                        }
                    }
                }

                // If a collision is detect with other drone,
                // perform the avoidance process.
                if ((collision_1_l == 1) || (collision_2_l == 1) || (collision_3_l == 1)){
                    collision_action(48w0x302e30313030,
                                     48w0x2d302e303230,
                                     48w0x302e30303030);
                    // hdr.ethernet.src_addr = 48w0x444444444444;
                    // hdr.ethernet.dst_addr = 48w0x444444444444;
                    // Enable mirror packet 
                    set_mirror_type();
                    // Update checksum 
                    md.recalculate_ipv4_checksum = 1;
                    md.recalculate_tcp_checksum = 1;
                    // Set collision register to 1
                    md.collision_ok = 1;
                }

            }
            else{
                // hdr.ethernet.src_addr = 48w0x666666666666;
                // hdr.ethernet.dst_addr = 48w0x666666666666;
                // Enable mirror packet 
                set_mirror_type();
                // Update checksum 
                md.recalculate_ipv4_checksum = 1;
                md.recalculate_tcp_checksum = 1;
                 // Set collision register to 1
                md.collision_ok = 1;
            }
            
        }

        // if (md.collision_ok == 1){
        //     collision_sent_action.execute(0);
        // }

        // TCP length for checksum
        if(hdr.ipv4.isValid()){
            md.tcpLength = hdr.ipv4.total_len - 20;
        }

        ig_intr_tm_md.bypass_egress = 1w1;
   	ig_intr_tm_md.ucast_egress_port = 196;
	 }
}


// Egress parser/control blocks
// Handle the mirror packet
parser EmptyEgressParser(
        packet_in pkt,
        out headers hdr,
        out empty_metadata_t eg_md,
        out egress_intrinsic_metadata_t eg_intr_md) {
    state start {
        pkt.extract(eg_intr_md);
        pkt.extract(hdr.ethernet);
        transition accept;
    }
}

// Emmit the mirror packet
control EmptyEgressDeparser(
        packet_out pkt,
        inout headers hdr,
        in empty_metadata_t eg_md,
        in egress_intrinsic_metadata_for_deparser_t ig_intr_dprs_md) {
    apply {
        pkt.emit(hdr);
    }
}

control EmptyEgress(
        inout headers hdr,
        inout empty_metadata_t eg_md,
        in egress_intrinsic_metadata_t eg_intr_md,
        in egress_intrinsic_metadata_from_parser_t eg_intr_md_from_prsr,
        inout egress_intrinsic_metadata_for_deparser_t ig_intr_dprs_md,
        inout egress_intrinsic_metadata_for_output_port_t eg_intr_oport_md) {

    // Register <bit<16>, _> (32w1)  val;

    // RegisterAction<bit<16>, bit<16>, bit<16>>(val) val_update_action = {
    //     void apply(inout bit<16> value){
    //         value = 15;
    //     }
    // };

    apply {
        // val_update_action.execute(0);
    }
}

Pipeline(SwitchIngressParser(),
         SwitchIngress(),
         SwitchIngressDeparser(),
         EmptyEgressParser(),
         EmptyEgress(),
         EmptyEgressDeparser()) pipe;

Switch(pipe) main;

