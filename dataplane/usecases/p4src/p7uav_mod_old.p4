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
const bit<4> UAV_ID = 4w0x1;        //ID = 1

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

header id_h {
    bit<4>  val;
    bit<4>  id;
}

header position_h {
    bit<48> x;
    bit<48> y;
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
    position_h      position;
}

struct empty_header_t {}

struct empty_metadata_t {}

struct my_ingress_metadata_t {
    bit<4> x_pos_a;
    bit<4> x_pos_b;
    bit<4> x_pos_c;
    bit<4> x_pos_d;
    bit<4> x_pos_e;
    bit<16> x_pos_dec;
    bit<16> x_pos_int;

    bit<4> y_pos_a;
    bit<4> y_pos_b;
    bit<4> y_pos_c;
    bit<4> y_pos_d;
    bit<4> y_pos_e;
    bit<16> y_pos_dec;
    bit<16> y_pos_int;
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
            UAV_ID:  parse_position;
            default: accept;
        }
    }

    state parse_position {
        packet.extract(hdr.position);

        //a.bcde
        // md.x_pos_a = hdr.position.x[43:40];
        // md.x_pos_b = hdr.position.x[27:24];
        // md.x_pos_c = hdr.position.x[19:16];
        // md.x_pos_d = hdr.position.x[11:8];
        // md.x_pos_e = hdr.position.x[3:0];
        // md.x_pos_dec = (md.x_pos_b << 12) | (md.x_pos_c << 8) | (md.x_pos_d << 4) | md.x_pos_e;
        // md.x_pos_int = (md.x_pos_a << 12) | (md.x_pos_b << 8) | (md.x_pos_c << 4) | md.x_pos_d;

        // md.x_pos_dec[15:12] = hdr.position.x[27:24];
        // md.x_pos_dec[11:8] = hdr.position.x[19:16];
        // md.x_pos_dec[7:4] = hdr.position.x[11:8];
        // md.x_pos_dec[3:0] = hdr.position.x[3:0];

        // md.x_pos_int[15:12] = hdr.position.x[43:40];
        // md.x_pos_int[11:8] = hdr.position.x[27:24];
        // md.x_pos_int[7:4] = hdr.position.x[19:16];
        // md.x_pos_int[3:0] = hdr.position.x[11:8];

        // md.y_pos_a = hdr.position.y[43:40];
        // md.y_pos_b = hdr.position.y[27:24];
        // md.y_pos_c = hdr.position.y[19:16];
        // md.y_pos_d = hdr.position.y[11:8];
        // md.y_pos_e = hdr.position.y[3:0];
        // md.y_pos_dec = (md.y_pos_b << 12) | (md.y_pos_c << 8) | (md.y_pos_d << 4) | md.y_pos_e;
        // md.y_pos_int = (md.y_pos_a << 12) | (md.y_pos_b << 8) | (md.y_pos_c << 4) | md.y_pos_d;

        // md.y_pos_dec[15:12] = hdr.position.y[27:24];
        // md.y_pos_dec[11:8] = hdr.position.y[19:16];
        // md.y_pos_dec[7:4] = hdr.position.y[11:8];
        // md.y_pos_dec[3:0] = hdr.position.y[3:0];

        // md.y_pos_int[15:12] = hdr.position.y[43:40];
        // md.y_pos_int[11:8] = hdr.position.y[27:24];
        // md.y_pos_int[7:4] = hdr.position.y[19:16];
        // md.y_pos_int[3:0] = hdr.position.y[11:8];

        transition accept;
    }
}


control SwitchIngressDeparser(
        packet_out pkt,
        inout headers hdr,
        in my_ingress_metadata_t ig_md,
        in ingress_intrinsic_metadata_for_deparser_t ig_intr_dprsr_md) {

    apply {
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

    bit<16> x_pos_hex = 0;
    bit<16> y_pos_hex = 0;

    action drop() {
        ig_intr_dprsr_md.drop_ctl = 0x1;
    }

    action forward(){
        ig_intr_tm_md.bypass_egress = 1w1;
    }

    action dectohex_x(bit<16> hexval){
        x_pos_hex = hexval;
    }

    action dectohex_y(bit<16> hexval){
        y_pos_hex = hexval;
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

    apply { 

        if(hdr.position.isValid()){
            // extract position

            x_pos_int[15:12] = hdr.position.x[43:40];
            x_pos_int[11:8] = hdr.position.x[27:24];
            x_pos_int[7:4] = hdr.position.x[19:16];
            x_pos_int[3:0] = hdr.position.x[11:8];
            y_pos_int[15:12] = hdr.position.y[43:40];
            y_pos_int[11:8] = hdr.position.y[27:24];
            y_pos_int[7:4] = hdr.position.y[19:16];
            y_pos_int[3:0] = hdr.position.y[11:8];  

            transform_x.apply();
            transform_y.apply();

            


            hdr.position.x[15:0] = x_pos_hex;
            hdr.position.x[47:16] = 32w0x00000000;
            hdr.position.y[15:0] = y_pos_hex;
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
    	ig_intr_tm_md.ucast_egress_port = 196;
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


