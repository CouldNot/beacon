import Foundation

/// Verifies end-to-end connectivity by opening a connection through the running
/// SOCKS5 inbound to a public host. Unlike a plain TCP probe to the proxy port,
/// this exercises the full path (local → xray → server → internet), so it
/// detects "xray is alive but the tunnel is dead" cases (e.g. the server-side
/// connection was dropped from a NAT table after a long idle period).
enum HealthProbe {

    /// Probes connectivity through the SOCKS5 proxy. Returns true if a CONNECT
    /// to `targetHost:targetPort` succeeds. Runs off the main actor.
    static func throughSocks(host: String, port: Int,
                             targetHost: String = "1.1.1.1", targetPort: UInt16 = 80,
                             timeout: TimeInterval = 5.0) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let ok = blockingSocksProbe(host: host, port: port,
                                            targetHost: targetHost, targetPort: targetPort,
                                            timeout: timeout)
                continuation.resume(returning: ok)
            }
        }
    }

    private static func blockingSocksProbe(host: String, port: Int,
                                           targetHost: String, targetPort: UInt16,
                                           timeout: TimeInterval) -> Bool {
        var hints = addrinfo(ai_flags: 0, ai_family: AF_UNSPEC, ai_socktype: SOCK_STREAM,
                             ai_protocol: IPPROTO_TCP, ai_addrlen: 0,
                             ai_canonname: nil, ai_addr: nil, ai_next: nil)
        var info: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, String(port), &hints, &info) == 0, let addr = info else {
            return false
        }
        defer { freeaddrinfo(info) }

        let fd = socket(addr.pointee.ai_family, addr.pointee.ai_socktype, addr.pointee.ai_protocol)
        guard fd >= 0 else { return false }
        defer { close(fd) }

        // Apply send/recv timeouts so a hung proxy can't block us indefinitely.
        var tv = timeval(tv_sec: Int(timeout),
                         tv_usec: Int32((timeout - floor(timeout)) * 1_000_000))
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        guard connect(fd, addr.pointee.ai_addr, addr.pointee.ai_addrlen) == 0 else {
            return false
        }

        // SOCKS5 greeting: version 5, 1 method, no-auth (0x00).
        let greeting: [UInt8] = [0x05, 0x01, 0x00]
        guard writeAll(fd, greeting) else { return false }

        // Method-selection reply: [version, method]. Expect 0x05 0x00.
        var reply = [UInt8](repeating: 0, count: 2)
        guard readExact(fd, &reply, 2), reply[0] == 0x05, reply[1] == 0x00 else {
            return false
        }

        // CONNECT request to an IPv4 target.
        guard let ip = ipv4Bytes(targetHost) else { return false }
        var req: [UInt8] = [0x05, 0x01, 0x00, 0x01]
        req.append(contentsOf: ip)
        req.append(UInt8(targetPort >> 8))
        req.append(UInt8(targetPort & 0xff))
        guard writeAll(fd, req) else { return false }

        // CONNECT reply header: [ver, rep, rsv, atyp]. rep == 0x00 means success.
        var head = [UInt8](repeating: 0, count: 4)
        guard readExact(fd, &head, 4), head[0] == 0x05, head[1] == 0x00 else {
            return false
        }
        return true
    }

    private static func ipv4Bytes(_ host: String) -> [UInt8]? {
        let parts = host.split(separator: ".").compactMap { UInt8($0) }
        return parts.count == 4 ? parts : nil
    }

    private static func writeAll(_ fd: Int32, _ bytes: [UInt8]) -> Bool {
        var sent = 0
        return bytes.withUnsafeBytes { raw -> Bool in
            let base = raw.bindMemory(to: UInt8.self).baseAddress!
            while sent < bytes.count {
                let n = write(fd, base + sent, bytes.count - sent)
                if n <= 0 { return false }
                sent += n
            }
            return true
        }
    }

    private static func readExact(_ fd: Int32, _ buf: inout [UInt8], _ count: Int) -> Bool {
        var got = 0
        return buf.withUnsafeMutableBytes { raw -> Bool in
            let base = raw.bindMemory(to: UInt8.self).baseAddress!
            while got < count {
                let n = read(fd, base + got, count - got)
                if n <= 0 { return false }
                got += n
            }
            return true
        }
    }
}
