import Foundation
import CryptoKit

/// Instalador SEGURO de mods: respalda originales, copia atómico, verifica y revierte.
final class ModInstaller {
    static let shared = ModInstaller()
    private let fm = FileManager.default

    private let backupFolder = "NLBackup"
    private let manifestFile = "manifest.json"

    /// Si está seteado, los backups viven ACÁ (fuera del contenedor del juego)
    /// para que el contenedor de Free Fire quede 100% limpio = más indetectable.
    var externalBackupRoot: URL?

    private init() {}

    struct Entry: Codable {
        let modID: String
        let hadOriginal: Bool
    }
    struct Manifest: Codable {
        var entries: [String: Entry] = [:]
    }
    struct InstallReport {
        var installedFiles: Int
        var backedUpOriginals: Int
        var skipped: Int
    }
    struct RestoreReport {
        var restoredOriginals: Int
        var removedAddedFiles: Int
    }

    enum InstallError: LocalizedError {
        case sourceMissing(String)
        case sourceEmpty(String)
        case verifyFailed(String)
        case writeFailed(String, Error)
        var errorDescription: String? {
            switch self {
            case .sourceMissing(let m): return "No se encontró la carpeta del mod '\(m)'."
            case .sourceEmpty(let m): return "El mod '\(m)' no tiene archivos adentro."
            case .verifyFailed(let f): return "Integridad falló en '\(f)' (se revirtió)."
            case .writeFailed(let f, let e): return "Error escribiendo '\(f)': \(e.localizedDescription)"
            }
        }
    }

    // MARK: - Rutas internas

    private func backupRoot(in destination: URL) -> URL {
        if let e = externalBackupRoot { return e }
        return destination.appendingPathComponent(backupFolder)
    }
    private func manifestURL(in destination: URL) -> URL {
        backupRoot(in: destination).appendingPathComponent(manifestFile)
    }
    private func loadManifest(in destination: URL) -> Manifest {
        guard let data = try? Data(contentsOf: manifestURL(in: destination)),
              let m = try? JSONDecoder().decode(Manifest.self, from: data) else { return Manifest() }
        return m
    }
    private func saveManifest(_ m: Manifest, in destination: URL) throws {
        let root = backupRoot(in: destination)
        if !fm.fileExists(atPath: root.path) {
            try fm.createDirectory(at: root, withIntermediateDirectories: true)
        }
        try JSONEncoder().encode(m).write(to: manifestURL(in: destination), options: .atomic)
    }

    // MARK: - Instalar un mod

    func install(modID: String, from source: URL, into destination: URL) throws -> InstallReport {
        guard fm.fileExists(atPath: source.path) else { throw InstallError.sourceMissing(modID) }

        var manifest = loadManifest(in: destination)
        var report = InstallReport(installedFiles: 0, backedUpOriginals: 0, skipped: 0)
        let files = relativeFiles(in: source)

        if files.isEmpty { throw InstallError.sourceEmpty(modID) }

        for rel in files {
            let srcURL = source.appendingPathComponent(rel)
            let dstURL = destination.appendingPathComponent(rel)

            if fm.fileExists(atPath: dstURL.path), sameContent(srcURL, dstURL) {
                report.skipped += 1
                continue
            }

            if manifest.entries[rel] == nil {
                if fm.fileExists(atPath: dstURL.path) {
                    let bak = backupRoot(in: destination).appendingPathComponent(rel)
                    try? fm.createDirectory(at: bak.deletingLastPathComponent(), withIntermediateDirectories: true)
                    if fm.fileExists(atPath: bak.path) { try? fm.removeItem(at: bak) }
                    do { try fm.copyItem(at: dstURL, to: bak) }
                    catch { throw InstallError.writeFailed("backup \(rel)", error) }
                    manifest.entries[rel] = Entry(modID: modID, hadOriginal: true)
                    report.backedUpOriginals += 1
                } else {
                    manifest.entries[rel] = Entry(modID: modID, hadOriginal: false)
                }
            }

            try? fm.createDirectory(at: dstURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            do { try atomicCopy(srcURL, to: dstURL) }
            catch { throw InstallError.writeFailed(rel, error) }

            if !sameContent(srcURL, dstURL) {
                if let e = manifest.entries[rel], e.hadOriginal {
                    let bak = backupRoot(in: destination).appendingPathComponent(rel)
                    try? fm.removeItem(at: dstURL)
                    try? fm.copyItem(at: bak, to: dstURL)
                }
                throw InstallError.verifyFailed(rel)
            }

            report.installedFiles += 1
        }

        try saveManifest(manifest, in: destination)
        return report
    }

    // MARK: - Restaurar todo al original (SEGURO CON EL JUEGO ABIERTO)

    func restoreAll(in destination: URL) throws -> RestoreReport {
        let manifest = loadManifest(in: destination)
        var report = RestoreReport(restoredOriginals: 0, removedAddedFiles: 0)

        for (rel, entry) in manifest.entries {
            let dstURL = destination.appendingPathComponent(rel)
            if entry.hadOriginal {
                let bak = backupRoot(in: destination).appendingPathComponent(rel)
                if fm.fileExists(atPath: bak.path) {
                    try? fm.removeItem(at: dstURL)
                    try? fm.copyItem(at: bak, to: dstURL)
                    report.restoredOriginals += 1
                }
            } else {
                if fm.fileExists(atPath: dstURL.path) {
                    try? fm.removeItem(at: dstURL)
                    report.removedAddedFiles += 1
                }
            }
        }

        try? fm.removeItem(at: backupRoot(in: destination))
        return report
    }

    // MARK: - Helpers

    private func relativeFiles(in root: URL) -> [String] {
        var out: [String] = []
        guard let en = fm.enumerator(at: root,
                                     includingPropertiesForKeys: [.isDirectoryKey],
                                     options: []) else { return [] }
        for case let u as URL in en {
            let isDir = (try? u.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDir { continue }
            let name = u.lastPathComponent
            if name == ".gitkeep" || name == ".DS_Store" { continue }
            out.append(u.path.replacingOccurrences(of: root.path + "/", with: ""))
        }
        return out
    }

    private func atomicCopy(_ src: URL, to dst: URL) throws {
        let tmp = dst.deletingLastPathComponent()
            .appendingPathComponent(".nl_tmp_\(UUID().uuidString)")
        try fm.copyItem(at: src, to: tmp)
        if fm.fileExists(atPath: dst.path) { try fm.removeItem(at: dst) }
        try fm.moveItem(at: tmp, to: dst)
    }

    private func sameContent(_ a: URL, _ b: URL) -> Bool {
        guard let sa = try? a.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              let sb = try? b.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              sa == sb else { return false }
        guard let da = try? Data(contentsOf: a), let db = try? Data(contentsOf: b) else { return false }
        return SHA256.hash(data: da) == SHA256.hash(data: db)
    }
}
