const std = @import("std");
const os = std.os;
const print = std.debug.print; // defaults to wrinting into stderr
const linux = os.linux;
const net = std.net;
const util = @import("./utils.zig");

// WARN: Run this with SUDO, don't remember that please
// Also mate, errno 1 means EPERM -> operation not permitted
//
// INFO: Also I'll be running this with one cmd arg - net ifi (either eth0 or eno1 is what I have)

pub fn main() !u8 { // returning u8 'cause I also want to handle errors respectively
    // If I want to use cmd arguments I can still do os.args as in Go

    const args = os.argv; // This approach works only on linux
    // To work cross platform, look at argsAlloc
    if (args.len < 2) {
        print("You have to also provide the net interface\n", .{});
        return 1;
    }
    // print("Running ...\nArgs: {s}\n", .{args});
    print("Running ... \n", .{});

    // const sockfd = try std.posix.socket(AF_PACKET, SOCK_RAW, ETH_P_ALL);
    const sockfd = linux.socket(util.AF_INET, util.SOCK_RAW, util.IPPROTO_TCP);
    // defer linux.close(sockfd);
    defer _ = util.close(sockfd);

    const eth = args[1]; // string as in "eno1" or "eth1" or "wlan"
    print("Eth val: {s}\n", .{eth});
    const eth_len = std.mem.len(eth);

    var ifi: linux.ifreq = undefined;
    @memcpy(&ifi.ifrn.name, eth);
    @memset(ifi.ifrn.name[eth_len..], 0);

    // I have to actually find the ifindex
    // try std.posix.ioctl_SIOCGIFINDEX(sockfd, &ifi);
    // linux.ioctl(sockfd, linux.SIOCGIFINDEX, &ifi);
    // util.myIOCTL(sockfd, linux.SIOCGIFINDEX, &ifi);
    try util.FindIFINDEX(sockfd, &ifi);

    print("Ifi val: {s}\nIfindex: {d}\n", .{ ifi.ifrn.name, ifi.ifru.ivalue });

    // for AF_INET I should use sockaddr.in
    const addr = linux.sockaddr.in{
        .family = util.AF_INET,
        .addr = @as(u32, util.INADDR_ANY), // Initialize to an empty 8-byte array
        .port = 0,
    };

    // const addr = linux.sockaddr.ll{
    //     .family = AF_PACKET, // it defaults to AF_PACKET
    //     .protocol = ETH_P_ALL,
    //     .ifindex = ifi.ifru.ivalue,
    //     .hatype = 0, // Hardware address type (defaulting to 0)
    //     .pkttype = 0, // Packet type (e.g., host, broadcast, etc.)
    //     .halen = 0, // Length of hardware address (0 for now)
    //     .addr = .{0} ** 8, // Initialize to an empty 8-byte array
    // };

    var addr_size: u32 = @sizeOf(@TypeOf(addr));

    // Now as always I have to bind the sock
    // try linux.bind(sockfd, @ptrCast(&addr), addr_size);
    _ = util.bind(sockfd, @ptrCast(&addr), addr_size);

    print("Listening... \n", .{});

    // Create the log file (cwd = current working directory)
    const log_file: std.fs.File = try std.fs.cwd().createFile("logs.txt", .{
        .read = true,
    });

    defer log_file.close();

    var buf: [util.BUF_MAX]u8 = undefined; // the number is max for u16
    // ???: does this actually allocate the memory for the buffer? Don't I need to allocate it myself?

    while (true) {
        const data_size = std.posix.recvfrom(sockfd, &buf, 0, @ptrCast(@constCast(&addr)), &addr_size) catch |err| {
            // TODO: Also make own func for this recvfrom
            // and make two files... one with posix implementation and one with own lib for this socket stuff
            // talking 'bout that, make your socket programming lib for these kind of things probably
            print("Error in recvfrom: {}\n", .{err});
            return 1;
        };
        if (data_size < 0) {
            print("Error receiving packet\n", .{});
            return 1;
        }

        // print("Received packet: {d} bytes\n", .{data_size});

        // Now I have to proccess the gotten data (from buffer)
        // proccessPacket(buf, data_size, log_file);
        util.proccessPacket(&buf);
    }

    return 0;
}
