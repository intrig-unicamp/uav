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

    /***********************  H E A D E R S  ************************/


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

header ethernet_h {
    mac_addr_t dst_addr;
    mac_addr_t src_addr;
    bit<16> ether_type;
}

header vlan_tag_h {
    bit<3> pcp;
    bit<1> cfi;
    vlan_id_t vid;
    bit<16> ether_type;
}

header calc_h {
    bit<8> op;
    bit<32> result;
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
    bit<160> routeid;
}

struct headers {
    ethernet_h   ethernet;
	rec_h	rec;
    vlan_tag_h   vlan_tag;
    ipv4_h       ipv4;
    calc_h       calc;
}


struct empty_header_t {}

struct empty_metadata_t {}

struct my_ingress_metadata_t {
    // PolKa
    bit<112> ndata;
    bit<16> diff;
    bit<16> nres;
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
        transition parse_calc;
    }

    state parse_calc {
        packet.extract(hdr.calc);
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

    // PolKa routing
    CRCPolynomial<bit<16>>(
                            coeff    = (65581 & 0xffff),
                            reversed = false,
                            msb      = false,
                            extended = false,
                            init     = 16w0x0000,
                            xor      = 16w0x0000) poly2;
    Hash<bit<16>>(HashAlgorithm_t.CUSTOM, poly2) hash2;

    CRCPolynomial<bit<16>>(
                            coeff    = (65593 & 0xffff),
                            reversed = false,
                            msb      = false,
                            extended = false,
                            init     = 16w0x0000,
                            xor      = 16w0x0000) poly3;
    Hash<bit<16>>(HashAlgorithm_t.CUSTOM, poly3) hash3;

    CRCPolynomial<bit<16>>(
                            coeff    = (65599 & 0xffff),
                            reversed = false,
                            msb      = false,
                            extended = false,
                            init     = 16w0x0000,
                            xor      = 16w0x0000) poly4;
    Hash<bit<16>>(HashAlgorithm_t.CUSTOM, poly4) hash4;

    CRCPolynomial<bit<16>>(
                            coeff    = (65607 & 0xffff),
                            reversed = false,
                            msb      = false,
                            extended = false,
                            init     = 16w0x0000,
                            xor      = 16w0x0000) poly5;
    Hash<bit<16>>(HashAlgorithm_t.CUSTOM, poly5) hash5;

    action send_next_2() {
        // PolKa routing
        md.ndata = (bit<112>) (hdr.rec.routeid >> 16);
        md.diff = (bit<16>) hdr.rec.routeid;

        // PolKa routing
        md.nres = hash2.get(md.ndata);
        hdr.rec.sw = md.nres ^ md.diff; // Next link by PolKa
    }
    action send_next_3() {
        // PolKa routing
        md.ndata = (bit<112>) (hdr.rec.routeid >> 16);
        md.diff = (bit<16>) hdr.rec.routeid;

        // PolKa routing
        md.nres = hash3.get(md.ndata);
        hdr.rec.sw = md.nres ^ md.diff; // Next link by PolKa
    }
    action send_next_4() {
        // PolKa routing
        md.ndata = (bit<112>) (hdr.rec.routeid >> 16);
        md.diff = (bit<16>) hdr.rec.routeid;

        // PolKa routing
        // md.nres = hash4.get(md.ndata);
        // hdr.rec.sw = md.nres ^ md.diff; // Next link by PolKa
    }
    action send_next_5() {
        // PolKa routing
        md.ndata = (bit<112>) (hdr.rec.routeid >> 16);
        md.diff = (bit<16>) hdr.rec.routeid;

        // PolKa routing
        // md.nres = hash5.get(md.ndata);
        // hdr.rec.sw = md.nres ^ md.diff; // Next link by PolKa
    }

    action operation_add(bit<8> value) {
        hdr.ipv4.ttl = hdr.ipv4.ttl + value;
    }

    action operation_xor(bit<8> value) {
        hdr.ipv4.ttl = hdr.ipv4.ttl ^ value;
    }

    action operation_and(bit<8> value) {
        hdr.ipv4.ttl = hdr.ipv4.ttl & value;
    }

    action operation_or(bit<8> value) {
        hdr.ipv4.ttl = hdr.ipv4.ttl | value;
    }

    action drop() {
        ig_intr_dprsr_md.drop_ctl = 0x1;
    }

    table basic_fwd_hash {
        key = {
            hdr.rec.sw_id : exact;
        }
        actions = {
            send_next_2;
            send_next_3;
            send_next_4;
            send_next_5;
            @defaultonly drop;
        }
        const default_action = drop();
        size = 128;
    }

    table calculate {
        key = {
			hdr.rec.sw_id   : exact;
            hdr.ipv4.dst_addr        : exact;
        }
        actions = {
            operation_add;
            operation_xor;
            operation_and;
            operation_or;
            @defaultonly drop;
        }
        const default_action = drop();
        size = 1024;
    }


    apply {
        calculate.apply();
        ig_intr_tm_md.bypass_egress = 1w1;
        basic_fwd_hash.apply();
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

