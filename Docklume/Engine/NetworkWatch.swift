import Network

/// Tells when the Mac's network comes back or changes: an interface gone or new, as when a cable is plugged back
/// or Wi-Fi takes over. An outage beyond the router leaves the path as it is; the bundled rclone notices that one
/// itself when its next connection works.
final class NetworkWatch: @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "Docklume.NetworkWatch")
    /// Touched on `queue` only.
    private var last: (online: Bool, interfaces: [String])?

    /// Called on the main actor, once the network is usable again after a change.
    init(onChange: @escaping @MainActor @Sendable () -> Void) {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let now = (online: path.status == .satisfied, interfaces: path.availableInterfaces.map(\.name).sorted())
            defer { last = now }
            // The first report only says how things stand.
            guard let last, now.online, !last.online || last.interfaces != now.interfaces else { return }
            Task { @MainActor in onChange() }
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }
}
