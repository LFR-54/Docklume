import Foundation

/// Free space on the cache volume and the size of a drive's cache.
enum DiskSpace {
    /// Below this, the app empties a drive's cache itself.
    static let floor: Int64 = 3_000_000_000

    /// On the disk of `url`, or of its closest existing parent: the cache folder only exists once a drive has used it.
    static func available(at url: URL) -> Int64? {
        var folder = url.standardizedFileURL
        while !FileManager.default.fileExists(atPath: folder.path), folder.pathComponents.count > 1 { folder = folder.deletingLastPathComponent() }
        return try? folder.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage
    }

    /// Bytes allocated on disk under a folder; cache files are sparse, so their length overstates them.
    static func allocated(in folder: URL) -> Int64 {
        guard let items = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.totalFileAllocatedSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let item as URL in items {
            total += Int64((try? item.resourceValues(forKeys: [.totalFileAllocatedSizeKey]))?.totalFileAllocatedSize ?? 0)
        }
        return total
    }
}
