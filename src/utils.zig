pub const std = @import("std");
pub const AF_PACKET = std.os.linux.AF.PACKET;
pub const AF_INET = std.os.linux.AF.INET;
pub const SOCK_RAW = std.os.linux.SOCK.RAW;
pub const ETH_P_ALL = @as(u16, 0x0003) << 8; // Capture all protocols; also htons(ETH_P_ALL)
pub const BUF_MAX = 65536;
pub const IPPROTO_TCP = std.os.linux.IPPROTO.TCP;
pub const IPPROTO_IP = std.os.linux.IPPROTO.IP;
pub const INADDR_ANY = 0x00000000;

var total: u24 = 0;
var other: u24 = 0;
var udp: u24 = 0;
var icmp: u24 = 0;
var tcp: u24 = 0;
var igmp: u24 = 0;

pub fn proccessPacket(buf: []u8) void {
    // I want to get the ip header and use the protocol in switch statement to then count exact packets types

    const ip_header = buf[0..20];
    const prot = ip_header[9];

    switch (prot) {
        1 => {
            icmp += 1;
        },
        2 => {
            igmp += 1;
        },
        6 => {
            tcp += 1;
        },
        17 => {
            udp += 1;
        },
        else => {
            other += 1;
        },
    }

    total += 1;

    std.debug.print("TCP: {d}, UDP: {d}, ICMP: {d}, IGMP: {d}, Others: {d}, Total: {d}\r", .{ tcp, udp, icmp, igmp, other, total });
}
