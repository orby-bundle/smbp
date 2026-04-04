import Foundation
import CryptoKit

/// Cache manager responsible for persisting binary and text resources (HTML, PDF, summaries, translations)
/// in the application's caches directory for 72 hours.
/// It mirrors the behaviour of a lightweight browser cache so that repeated network calls can be avoided
/// while still respecting temporary storage semantics.
final class CacheManager {

    // MARK: - Nested Types

    /// Logical buckets to keep cached resources isolated by their usage.
    enum CacheCategory: Hashable {
        case pdf
        case html
        case summary
        case translation
        case custom(name: String, fileExtension: String)

        var directoryName: String {
            switch self {
            case .pdf: return "pdf"
            case .html: return "html"
            case .summary: return "summary"
            case .translation: return "translation"
            case .custom(let name, _): return name
            }
        }

        var fileExtension: String {
            switch self {
            case .pdf: return "pdf"
            case .html: return "html"
            case .summary: return "txt"
            case .translation: return "txt"
            case .custom(_, let ext): return ext
            }
        }
    }

    /// Lightweight descriptor for cached files returned by the manager.
    struct CacheEntry {
        let key: String
        let category: CacheCategory
        let fileURL: URL
        let expirationDate: Date
        let fileSize: Int64
    }

    enum CacheManagerError: Error {
        case failedToEncodeString
        case failedToDecodeString
        case failedToEncodeObject
        case failedToDecodeObject
    }

    // MARK: - Public Interface

    static let shared = CacheManager()

    /// Default time-to-live for cached resources (72 hours).
    let defaultTTL: TimeInterval = 72 * 60 * 60

    // MARK: - Private Properties

    private let fileManager: FileManager
    private let cachesRootDirectory: URL
    private let ioQueue = DispatchQueue(label: "com.bazaprawna.cache", qos: .utility)

    // MARK: - Init

    private init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let rootDirectory = cachesDirectory.appendingPathComponent("BazaPrawnaCache", isDirectory: true)
        self.cachesRootDirectory = rootDirectory

        createDirectoryIfNeeded(at: rootDirectory)
        excludeFromBackup(url: rootDirectory)
        cleanupExpiredEntries()
    }

    // MARK: - Public API (Store)

    /// Stores raw data for the provided key inside the specified cache bucket.
    func storeData(_ data: Data, forKey key: String, category: CacheCategory, ttl: TimeInterval? = nil) throws {
        let fileURL = makeFileURL(for: key, category: category)
        let directory = fileURL.deletingLastPathComponent()

        ioQueue.sync {
            createDirectoryIfNeeded(at: directory)
        }

        try data.write(to: fileURL, options: [.atomic])
        excludeFromBackup(url: fileURL)
        try applyExpirationDate(ttl ?? defaultTTL, to: fileURL)
    }

    /// Stores a string using UTF-8 encoding.
    func storeString(_ string: String, forKey key: String, category: CacheCategory, ttl: TimeInterval? = nil, encoding: String.Encoding = .utf8) throws {
        guard let data = string.data(using: encoding) else { throw CacheManagerError.failedToEncodeString }
        try storeData(data, forKey: key, category: category, ttl: ttl)
    }

    /// Stores an encodable object as JSON data.
    func storeCodable<T: Codable>(_ object: T, forKey key: String, category: CacheCategory, ttl: TimeInterval? = nil, encoder: JSONEncoder = JSONEncoder()) throws {
        guard let data = try? encoder.encode(object) else { throw CacheManagerError.failedToEncodeObject }
        try storeData(data, forKey: key, category: category, ttl: ttl)
    }

    // MARK: - Public API (Retrieve)

    /// Returns cached data if it exists and is not expired.
    func data(forKey key: String, category: CacheCategory) -> Data? {
        let fileURL = makeFileURL(for: key, category: category)

        guard isFileUsable(at: fileURL) else { return nil }
        return try? Data(contentsOf: fileURL)
    }

    /// Returns cached string if it exists and is not expired.
    func string(forKey key: String, category: CacheCategory, encoding: String.Encoding = .utf8) -> String? {
        guard let data = data(forKey: key, category: category) else { return nil }
        guard let stringValue = String(data: data, encoding: encoding) else {
            // Data exists but decoding failed – treat as stale and remove.
            removeValue(forKey: key, category: category)
            return nil
        }
        return stringValue
    }

    /// Returns a decoded codable object if it exists and is not expired.
    func codableValue<T: Codable>(forKey key: String, category: CacheCategory, as type: T.Type, decoder: JSONDecoder = JSONDecoder()) -> T? {
        guard let data = data(forKey: key, category: category) else { return nil }
        guard let value = try? decoder.decode(T.self, from: data) else {
            removeValue(forKey: key, category: category)
            return nil
        }
        return value
    }

    /// Returns metadata about the cached entry if present and valid.
    func cacheEntry(forKey key: String, category: CacheCategory) -> CacheEntry? {
        let fileURL = makeFileURL(for: key, category: category)

        guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
              let expirationDate = attributes[.modificationDate] as? Date,
              expirationDate > Date() else {
            return nil
        }

        let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        return CacheEntry(key: key, category: category, fileURL: fileURL, expirationDate: expirationDate, fileSize: fileSize)
    }

    // MARK: - Public API (Maintenance)

    /// Removes the cached resource for the given key.
    func removeValue(forKey key: String, category: CacheCategory) {
        let fileURL = makeFileURL(for: key, category: category)
        try? fileManager.removeItem(at: fileURL)
    }

    /// Clears every cached file inside a specific bucket.
    @discardableResult
    func clear(_ category: CacheCategory) -> Int {
        let directory = categoryDirectory(for: category)
        return removeContents(of: directory)
    }

    /// Removes every cached file managed by the cache manager.
    @discardableResult
    func clearAll() -> Int {
        return removeContents(of: cachesRootDirectory)
    }

    /// Iterates over all cached files and purges the expired ones.
    @discardableResult
    func cleanupExpiredEntries() -> Int {
        var removedFiles = 0
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey]

        guard let enumerator = fileManager.enumerator(at: cachesRootDirectory, includingPropertiesForKeys: resourceKeys) else {
            return removedFiles
        }

        for case let fileURL as URL in enumerator {
            guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                  let expirationDate = attributes[.modificationDate] as? Date else {
                continue
            }

            if expirationDate <= Date() {
                try? fileManager.removeItem(at: fileURL)
                removedFiles += 1
            }
        }

        return removedFiles
    }

    // MARK: - Helpers

    private func makeFileURL(for key: String, category: CacheCategory) -> URL {
        let directory = categoryDirectory(for: category)
        let hashedName = hashedFileName(for: key)
        return directory.appendingPathComponent(hashedName).appendingPathExtension(category.fileExtension)
    }

    private func categoryDirectory(for category: CacheCategory) -> URL {
        let directory = cachesRootDirectory.appendingPathComponent(category.directoryName, isDirectory: true)
        createDirectoryIfNeeded(at: directory)
        return directory
    }

    private func createDirectoryIfNeeded(at url: URL) {
        guard !fileManager.fileExists(atPath: url.path) else { return }
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func excludeFromBackup(url: URL) {
        var resourceURL = url
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try? resourceURL.setResourceValues(resourceValues)
    }

    private func applyExpirationDate(_ ttl: TimeInterval, to fileURL: URL) throws {
        let expirationDate = Date().addingTimeInterval(ttl)
        try fileManager.setAttributes([.modificationDate: expirationDate], ofItemAtPath: fileURL.path)
    }

    private func isFileUsable(at url: URL) -> Bool {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let expirationDate = attributes[.modificationDate] as? Date else {
            return false
        }

        if expirationDate <= Date() {
            try? fileManager.removeItem(at: url)
            return false
        }

        return true
    }

    private func hashedFileName(for key: String) -> String {
        let data = Data(key.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    @discardableResult
    private func removeContents(of directory: URL) -> Int {
        guard let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return 0
        }

        var removed = 0
        for url in contents {
            try? fileManager.removeItem(at: url)
            removed += 1
        }
        return removed
    }
}

