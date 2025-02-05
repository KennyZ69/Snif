const std = @import("std");
const builtin = @import("builtin");
const util = @import("utils.zig");

const TCPPacket = struct {
    src_port: u16,
    dst_port: u16,
    seq: u32,
    ack_num: u32,
    dof: u16, // data offset flags || also header length
    window: u16,
    checksum: u16,
    urgent_ptr: u16,

    fn fromBytes(buf: []u8) TCPPacket {
        return TCPPacket{
            .src_port = std.mem.readInt(u16, buf[0..2], .big),
            .dst_port = std.mem.readInt(u16, buf[2..4], .big),
            .seq = std.mem.readInt(u32, buf[4..8], .big),
            .ack_num = std.mem.readInt(u32, buf[8..12], .big),
            .dof = std.mem.readInt(u16, buf[12..14], .big),
            .window = std.mem.readInt(u16, buf[14..16], .big),
            .checksum = std.mem.readInt(u16, buf[16..18], .big),
            .urgent_ptr = std.mem.readInt(u16, buf[18..20], .big),
        };
    }

    // extract Data Offset
    fn dataOffset(self: TCPPacket) u16 {
        return ((self.dof >> 4) & 0xF) * 4;
    }
};

const IPHeader = struct {
    version_ihl: u8,
    tos: u8, // Type of Service
    length: u16, // u4 * 4
    id: u16,
    flags_offset: u16,
    ttl: u8,
    protocol: u8,
    checksum: u16,
    src_ip: u32,
    dst_ip: u32,

    fn fromBytes(buf: []u8) IPHeader {
        return IPHeader{
            .version_ihl = buf[0],
            .tos = buf[1],
            .length = std.mem.readInt(u16, buf[2..4], .big),
            .id = std.mem.readInt(u16, buf[4..6], .big),
            .flags_offset = std.mem.readInt(u16, buf[6..8], .big),
            .ttl = buf[8],
            .protocol = buf[9],
            .checksum = std.mem.readInt(u16, buf[10..12], .big),
            .src_ip = std.mem.readInt(u32, buf[12..16], .big),
            .dst_ip = std.mem.readInt(u32, buf[16..20], .big),
        };
    }

    // get the IP header length from a struct
    fn ihl(self: IPHeader) u8 {
        return (self.version_ihl & 0xF) * 4; // extract IP header length
    }
};

// pub fn SaveIcmpLog(file: *std.fs.File, buf: []u8) void {
//     const wr = file.writer();
//     wr.print(
//         "",
//     );
// }
// pub fn SaveUdpLog(file: *std.fs.File) void {}
pub fn SaveTcpLog(buf: []u8, file: *const std.fs.File) !void {
    const iphdr = IPHeader.fromBytes(buf);
    const ihl = iphdr.ihl();

    const tcphdr = TCPPacket.fromBytes(buf[ihl..]);

    try file.writer().print(
        \\
        \\================ TCP Packet =================
        \\Source Port      : {}
        \\Destination Port : {}
        \\Sequence Number  : {}
        \\Ack Number      : {}
        \\Header Length   : {} Bytes
        \\Window Size     : {}
        \\Checksum        : {}
        \\Urgent Pointer  : {}
        \\ 
        \\ 
    , .{
        tcphdr.src_port,
        tcphdr.dst_port,
        tcphdr.seq,
        tcphdr.ack_num,
        tcphdr.dataOffset(),
        tcphdr.window,
        tcphdr.checksum,
        tcphdr.urgent_ptr,
    });

    // print payload
    const payload = buf[ihl + tcphdr.dataOffset() ..];
    try printData(payload, file);
}

// fn printData(payload: []u8, file: *const std.fs.File) !void {
//     // try file.writer().print("Payload len: {}\n", .{payload.len});
//     var i: usize = 0;
//     while (i < payload.len and i % 16 == 0 and i != 0) : (i += 1) { // moving in hexadecimal numbers
//         var j: usize = i;
//     }
// }

fn printData(payload: []u8, file: *const std.fs.File) !void {
    const w: std.fs.File.Writer = file.writer();
    var i: usize = 0;
    while (i < payload.len) : (i += 1) {
        if (i % 16 == 0) try w.print("\n   ", .{});

        // ending the print func
        if (payload[i] == 0xAA) {
            try w.print("\n", .{});
            return;
        }

        // print hex value
        try w.print(" 0x{X:0>2}", .{payload[i]});

        // print it in ASCII at the end of a row
        if (i % 16 == 15 or i == payload.len - 1) {
            // Padding for short final rows
            var padding: usize = 15 - (i % 16);
            while (padding > 0) : (padding -= 1) {
                try w.print("   ", .{}); // Extra spacing
            }

            try w.print("    ", .{});

            var j: usize = i - (i % 16);
            while (j <= i) : (j += 1) {
                if (payload[j] >= 32 and payload[j] <= 126) {
                    try w.print("{c}", .{payload[j]});
                } else {
                    try w.print(".", .{});
                }
            }
        }
    }

    try w.print("\n", .{});
}
