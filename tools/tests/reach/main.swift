import AppKit

// Mounts two WebDAV drives through the real DriveStore: one whose server never answers, one served locally.
// No catalog, so the store leaves ~/Cloud/Tags alone; caches and mount points stay in the test folder.
let folder = URL(filePath: CommandLine.arguments[1], directoryHint: .isDirectory)
let suiteName = "docklume.reach.test"

@MainActor func describe(_ store: DriveStore, _ start: Date) {
    let line = store.drives.map { drive -> String in
        let state: String
        switch drive.state {
        case .unmounted: state = "non monté"
        case .mounting: state = "montage"
        case .mounted: state = "monté"
        case .unmounting: state = "démontage"
        case .failed(let message): state = "échec (\(message))"
        }
        return "\(drive.name) : \(state)\(drive.notice.map { " — \($0)" } ?? "")"
    }.joined(separator: " | ")
    print(String(format: "%5.1f s  ", Date().timeIntervalSince(start)) + line)
}

MainActor.assumeIsolated {
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    for key in ["notifyMountFailure", "notifySessionExpired", "notifyNearlyFull"] { defaults.set(false, forKey: key) }
    defaults.set(folder.appending(path: "cache").path, forKey: "cacheBase")
    let store = DriveStore(preferences: Preferences(defaults: defaults), catalog: nil)
    Task { @MainActor in
        await store.load()
        for drive in store.drives {
            drive.record.settings.parentFolder = folder.appending(path: "mnt").path
            drive.record.settings.method = .nfs
        }
        let start = Date()
        for drive in store.drives { store.mount(drive) }
        for _ in 0..<10 {
            describe(store, start)
            try? await Task.sleep(for: .seconds(2))
        }
        await store.unmountAll()
        try? await Task.sleep(for: .seconds(2))
        describe(store, start)
        print("journaux : " + store.drives.map { $0.logFile.path }.joined(separator: " "))
        defaults.removePersistentDomain(forName: suiteName)
        exit(0)
    }
    RunLoop.main.run()
}
