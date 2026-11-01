import Foundation

// Persists compiled layout sources to disk so the app avoids recompiling on
// every cold launch. Stores the full LayoutResponse JSON; the Swift closures
// themselves can't be serialised, so we re-compile from source on launch.
//
// Layout sequence:
//   Cold launch  → loadAll() → compile each → warm LayoutCache  (no skeleton)
//   Server fetch → version higher? → save() + LayoutCache.receive() → recompile
actor LayoutDiskCache {
    static let shared = LayoutDiskCache()

    private let directory: URL

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        directory = caches.appendingPathComponent("bdui", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func save(_ response: LayoutResponse) {
        let id = response.layoutID
        let version = response.version
        cleanOldVersions(for: id, keepVersion: version)
        let url = fileURL(id: id, version: version)
        try? JSONEncoder().encode(response).write(to: url)
    }

    func loadAll() -> [LayoutResponse] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return [] }
        let decoder = JSONDecoder()
        return files.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(LayoutResponse.self, from: data)
        }
    }

    private func fileURL(id: String, version: Int) -> URL {
        directory.appendingPathComponent("\(id)_v\(version).json")
    }

    private func cleanOldVersions(for id: String, keepVersion: Int) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return }
        let keepName = "\(id)_v\(keepVersion).json"
        for file in files {
            let name = file.lastPathComponent
            if name.hasPrefix(id + "_v") && name != keepName {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}
