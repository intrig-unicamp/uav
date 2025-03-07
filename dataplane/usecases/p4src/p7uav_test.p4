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
    //bit<96> options;
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
    bit<16> object_id;
    bit<16> x_pos_hex;
    bit<16> y_pos_hex;
    bit<16> collision_detected;

    bit<1> do_ing_mirroring;  // Enable ingress mirroring
    MirrorId_t ing_mir_ses;   // Ingress mirror session ID
    pkt_type_t pkt_type;
}

header mirror_bridged_metadata_h {
    pkt_type_t pkt_type;
    @flexible bit<1> do_egr_mirroring;  //  Enable egress mirroring
    @flexible MirrorId_t egr_mir_ses;   // Egress mirror session ID
}

header mirror_h {
    pkt_type_t  pkt_type;
}

struct headers {
    mirror_bridged_metadata_h   bridged_md;
    ethernet_h      ethernet;
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

    state start {
        packet.extract(ig_intr_md);
        packet.advance(PORT_METADATA_SIZE);
        transition parse_ethernet;
    }

    state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
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
        transition select(hdr.ipv4.protocol) {
            TCP_TYPE: parse_tcp;
            default: accept;
        }
    }

    state parse_tcp {
        packet.extract(hdr.tcp);
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

    apply {

        if (ig_intr_dprsr_md.mirror_type == MIRROR_TYPE_I2E) {
            mirror.emit<mirror_h>(ig_md.ing_mir_ses, {ig_md.pkt_type});
        }

        pkt.emit(hdr);
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
    bit<16> collision_2 = 0;

    bit<8> object_id = 0;
    bit<16> object_index = 0;

    action set_mirror_type() {
        ig_intr_dprsr_md.mirror_type = MIRROR_TYPE_I2E;
        md.pkt_type = PKT_TYPE_MIRROR;
    }

    action set_normal_pkt() {
        hdr.bridged_md.setValid();
        hdr.bridged_md.pkt_type = PKT_TYPE_NORMAL;
    }

    // Register <bit<32>, _> (32w1)  uav_id;

    // RegisterAction<bit<32>, _, bit<32>>(uav_id) get_uav_id = {
    //     void apply(inout bit<32> value, out bit<32> readvalue){
    //         readvalue = value;
    //     }
    // };

    // RegisterAction<bit<32>, _, bit<32>>(uav_id) set_uav_id = {
    //     void apply(inout bit<32> value){
    //         value = hdr.position_id.object_id;
    //     }
    // };

    // Register to save the object ID of the UAVs
    Register <bit<16>, _> (32w2048)  index_uav;
    Register <bit<16>, _> (32w2048)  table_uav;

    RegisterAction<bit<16>, bit<16>, bit<16>>(index_uav) index_uav_action = {
        void apply(inout bit<16> value, out bit<16> readvalue){
            readvalue = value;
            value = value + 1;
        }
    };

    RegisterAction<bit<16>, bit<16>, bit<16>>(table_uav) table_uav_action = {
        void apply(inout bit<16> value){
               value = md.object_id;
        }
    };

    RegisterAction<bit<16>, bit<16>, bit<16>>(table_uav) table_uav_get_action = {
        void apply(inout bit<16> value, out bit<16> readvalue){
               readvalue = value;
        }
    };

    // Register per UAV
    Register <bit<16>, _> (32w2048)  uav1;
    Register <bit<16>, _> (32w2048)  uav2;
    Register <bit<16>, _> (32w2048)  uav3;

    RegisterAction<bit<16>, bit<16>, bit<16>>(uav1) uav1_update_action = {
        void apply(inout bit<16> value){
            value = md.x_pos_hex;
        }
    };

    RegisterAction<bit<16>, bit<16>, bit<16>>(uav1) uav1_check_action = {
        void apply(inout bit<16> value, out bit<16> readvalue){
            if (((md.x_pos_hex - value) < 10) && ((md.y_pos_hex - value) < 10)){
                readvalue = 1;
            }
            else{
                readvalue = 0;
            }

        //     if (md.x_pos_hex > (value-10) && md.x_pos_hex < (value+10)){
        //         //if (md.y_pos_hex > (value-10) && md.y_pos_hex < (value+10)){
        //             readvalue = 1;
        //         //}
        //         //else{
        //         //    readvalue = 0;
        //         //}
        //     }
        //     else{
        //         readvalue = 0;
        //     }
        }
    };

    RegisterAction<bit<16>, bit<16>, bit<16>>(uav2) uav2_update_action = {
        void apply(inout bit<16> value){
            value = md.x_pos_hex;
        }
    };

    RegisterAction<bit<16>, bit<16>, bit<16>>(uav2) uav2_check_action = {
        void apply(inout bit<16> value, out bit<16> readvalue){
            if (((md.x_pos_hex - value) < 10) && ((md.y_pos_hex - value) < 10)){
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
            if (((md.x_pos_hex - value) < 10) && ((md.y_pos_hex - value) < 10)){
                readvalue = 1;
            }
            else{
                readvalue = 0;
            }
        }
    };

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

    action collision_action(){
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
        hdr.new_payload.object_id = 16w0x3635;
        hdr.new_payload.x = 48w0x302e30313030;
        hdr.new_payload.y = 48w0x2d302e303230;
        hdr.new_payload.z = 48w0x302e30303030;
        hdr.new_payload.reference = 16w0x3635;

        // hdr.tcp.seq_no = ????;
        // hdr.tcp.ack_no = ????;
    }

    table transform_x{
        key = {
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
            y_pos_int : exact;
        }
        actions = {
            dectohex_y;
            @defaultonly forward;
        }
        const default_action = forward();
        size = 5000;
    }

    action avoidance(bit<16> new_object_id,
                     bit<48> new_x,
                     bit<48> new_y,
                     bit<48> new_z,
                     bit<16> new_reference){
        hdr.new_payload.setValid();
        hdr.new_payload.object_id = new_object_id;
        hdr.new_payload.x = new_x;
        hdr.new_payload.y = new_y;
        hdr.new_payload.z = new_z;
        hdr.new_payload.reference = new_reference;

        // hdr.tcp.seq_no = ????;
        // hdr.tcp.ack_no = ????;
    }

    table check_collision{
        key = {
            md.x_pos_hex : range;
            md.y_pos_hex : range;
        }
        actions = {
            avoidance;
            @defaultonly forward;
        }
        const default_action = forward();
        size = 2048;
    }

    apply { 

        if(hdr.position_id.isValid()){
            //Get uav index
            object_index = index_uav_action.execute(1);
            table_uav_action.execute(object_index);
        }
        else if(hdr.position.isValid()){
            // extract position
            x_pos_int[15:12] = hdr.position.x[43:40];
            x_pos_int[11:8] = hdr.position.x[27:24];
            x_pos_int[7:4] = hdr.position.x[19:16];
            x_pos_int[3:0] = hdr.position.x[11:8];
            y_pos_int[15:12] = hdr.position.y[43:40];
            y_pos_int[11:8] = hdr.position.y[27:24];
            y_pos_int[7:4] = hdr.position.y[19:16];
            y_pos_int[3:0] = hdr.position.y[11:8];  

            md.object_id[7:4] = hdr.position.object_id[11:8];
            md.object_id[3:0] = hdr.position.object_id[3:0];

            //Result in md.x_pos_hex and md.y_pos_hex
            transform_x.apply();
            transform_y.apply();

            //Check collision with objects
            if(!check_collision.apply().hit){

                // object_index = 0x1;

                // Update object 
                if (md.object_id == 0x39){
                    uav1_update_action.execute(1);
                    collision_1 = uav2_check_action.execute(1);
                    collision_2 = uav3_check_action.execute(1);
                }
                else {
                    // object_index = table_uav_get_action.execute(1);
                    if (md.object_id == 0x64){
                        uav2_update_action.execute(1);
                        collision_1 = uav1_check_action.execute(1);
                        collision_2 = uav3_check_action.execute(1);
                    }
                    else{
                        uav3_update_action.execute(1);
                        collision_1 = uav1_check_action.execute(1);
                        collision_2 = uav2_check_action.execute(1);
                    }
                }

                if ((collision_1 == 1) || (collision_2 == 1)){
                    collision_action();
                }
            }

            hdr.position.x[15:0] = md.x_pos_hex;
            hdr.position.x[47:16] = 32w0x00000000;
            hdr.position.y[15:0] = md.y_pos_hex;
            hdr.position.y[47:16] = 32w0x00000000;

            // hdr.ethernet.src_addr = 48w0x111111111111;
            // hdr.ethernet.dst_addr = 48w0x111111111111;
        }
        // else{

        //     if(hdr.tcp.isValid()){
        //         hdr.ethernet.src_addr = 48w0x222222222222;
        //         hdr.ethernet.dst_addr = 48w0x222222222222;

        //         hdr.tcp.dport = SRC_TCP;
        //     }
        //     else{
        //         hdr.ethernet.src_addr = 48w0x000000000000;
        //         hdr.ethernet.dst_addr = 48w0x000000000000;
        //     }

            
        // }


        ig_intr_tm_md.bypass_egress = 1w1;
    }
}


// Empty egress parser/control blocks
parser EmptyEgressParser(
        packet_in pkt,
        out empty_header_t hdr,
        out empty_metadata_t eg_md,
        out egress_intrinsic_metadata_t eg_intr_md) {
    state start {
        transition accept;
    }
}

control EmptyEgressDeparser(
        packet_out pkt,
        inout empty_header_t hdr,
        in empty_metadata_t eg_md,
        in egress_intrinsic_metadata_for_deparser_t ig_intr_dprs_md) {
    apply {}
}

control EmptyEgress(
        inout empty_header_t hdr,
        inout empty_metadata_t eg_md,
        in egress_intrinsic_metadata_t eg_intr_md,
        in egress_intrinsic_metadata_from_parser_t eg_intr_md_from_prsr,
        inout egress_intrinsic_metadata_for_deparser_t ig_intr_dprs_md,
        inout egress_intrinsic_metadata_for_output_port_t eg_intr_oport_md) {
    apply {}
}



Pipeline(SwitchIngressParser(),
         SwitchIngress(),
         SwitchIngressDeparser(),
         EmptyEgressParser(),
         EmptyEgress(),
         EmptyEgressDeparser()) pipe;

Switch(pipe) main;

