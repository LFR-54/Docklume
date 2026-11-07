import Foundation
import Network

/// Whether a drive's server answers at all, checked before rclone starts. A macFUSE mount whose server never
/// answers does not fail: macOS waits for the volume's size, rclone waits for the server, up to ten attempts of a
/// minute each, and meanwhile anything listing the volumes, the Finder included, waits too.
enum Reachability {
    struct Endpoint: Equatable, Sendable {
        let host: String
        let port: UInt16
    }

    /// The server a remote's backend talks to, from its type and settings, following the remotes that wrap another
    /// one; nil when Docklume does not know it, and then nothing is checked.
    static func endpoint(of remote: String, in dump: [String: [String: String]], depth: Int = 0) -> Endpoint? {
        guard depth < 4, let config = dump[remote], let type = config["type"] else { return nil }
        switch type {
        case "webdav", "http":
            return config["url"].flatMap(endpoint(url:))
        case "s3":
            guard let value = config["endpoint"], !value.isEmpty else { return Endpoint(host: "s3.amazonaws.com", port: 443) }
            return endpoint(url: value.contains("://") ? value : "https://\(value)")
        case "sftp":
            return config["host"].map { Endpoint(host: $0, port: UInt16(config["port"] ?? "") ?? 22) }
        case "ftp":
            return config["host"].map { Endpoint(host: $0, port: UInt16(config["port"] ?? "") ?? 21) }
        case "smb":
            return config["host"].map { Endpoint(host: $0, port: UInt16(config["port"] ?? "") ?? 445) }
        case "dropbox": return Endpoint(host: "api.dropboxapi.com", port: 443)
        case "drive": return Endpoint(host: "www.googleapis.com", port: 443)
        case "onedrive": return Endpoint(host: "graph.microsoft.com", port: 443)
        case "box": return Endpoint(host: "api.box.com", port: 443)
        case "crypt", "alias", "chunker", "compress", "hasher":
            // "other:path" or "other:" names the remote underneath; a local path has no server.
            guard let wrapped = config["remote"], let colon = wrapped.firstIndex(of: ":") else { return nil }
            return endpoint(of: String(wrapped[..<colon]), in: dump, depth: depth + 1)
        default:
            return nil
        }
    }

    static func endpoint(url: String) -> Endpoint? {
        guard let components = URLComponents(string: url), let host = components.host, !host.isEmpty else { return nil }
        let port = components.port ?? (components.scheme == "http" ? 80 : 443)
        return UInt16(exactly: port).map { Endpoint(host: host, port: $0) }
    }

    /// Opens a TCP connection to the server and closes it: false when its name does not resolve, nothing routes to
    /// it, it refuses, or it has not answered within `timeout`.
    static func answers(_ endpoint: Endpoint, timeout: Duration = .seconds(8)) async -> Bool {
        guard let port = NWEndpoint.Port(rawValue: endpoint.port) else { return false }
        let connection = NWConnection(host: NWEndpoint.Host(endpoint.host), port: port, using: .tcp)
        let outcome = Outcome()
        return await withCheckedContinuation { continuation in
            let finish: @Sendable (Bool) -> Void = { answered in
                guard outcome.settle() else { return }
                connection.cancel()
                continuation.resume(returning: answered)
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: finish(true)
                // Waiting means the connection failed and would be tried again later: no network, no name, refused.
                case .waiting, .failed: finish(false)
                default: break
                }
            }
            let queue = DispatchQueue(label: "Docklume.Reachability")
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + Double(timeout.components.seconds)) { finish(false) }
        }
    }

    /// Lets only the first of the connection's outcomes and the timeout through.
    private final class Outcome: @unchecked Sendable {
        private let lock = NSLock()
        private var settled = false

        func settle() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            guard !settled else { return false }
            settled = true
            return true
        }
    }
}
