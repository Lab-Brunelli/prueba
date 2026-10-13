import Foundation

/// Biblioteca de mods: vive en el Documents de ESTA app (visible en la app Archivos)
/// y se auto-siembra desde los FFAssets del bundle la primera vez.
/// Así se agregan/cambian mods SIN recompilar el IPA.
final class ModsLibrary {
    static let shared = ModsLibrary()
    private let fm = FileManager.default
    private init() {}

    /// Carpeta raíz de mods: <Documents de FX>/Mods
    var modsRoot: URL {
        let docs = (try? fm.url(for: .documentDirectory, in: .userDomainMask,
                                appropriateFor: nil, create: true)) ?? fm.temporaryDirectory
        return docs.appendingPathComponent("Mods")
    }

    func ensureReady() {
        if !fm.fileExists(atPath: modsRoot.path) {
            try? fm.createDirectory(at: modsRoot, withIntermediateDirectories: true)
        }
        seedFromBundleIfNeeded()
        ensureSelfTest()
    }

    /// Copia los FFAssets del bundle a Documents/Mods solo si aún no existen.
    private func seedFromBundleIfNeeded() {
        guard let res = Bundle.main.resourceURL else { return }
        let bundleAssets = res.appendingPathComponent("FFAssets")
        guard let ids = try? fm.contentsOfDirectory(atPath: bundleAssets.path) else { return }
        for id in ids where !id.hasPrefix(".") {
            let dst = modsRoot.appendingPathComponent(id)
            if !fm.fileExists(atPath: dst.path) {
                try? fm.copyItem(at: bundleAssets.appendingPathComponent(id), to: dst)
            }
        }
    }

    /// Crea un mod de prueba con un archivo real, para validar el pipeline sin assets del juego.
    private func ensureSelfTest() {
        let dir = modsRoot.appendingPathComponent("_selftest")
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let marker = dir.appendingPathComponent("FX_SELFTEST.txt")
        if !fm.fileExists(atPath: marker.path) {
            let text = "FX selftest OK\ncreado: \(ISO8601DateFormatter().string(from: Date()))\n"
            try? text.data(using: .utf8)?.write(to: marker)
        }
    }

    /// Mods disponibles = carpetas dentro de Documents/Mods
    func availableMods() -> [String] {
        ensureReady()
        let ids = (try? fm.contentsOfDirectory(atPath: modsRoot.path)) ?? []
        return ids.filter { !$0.hasPrefix(".") }.sorted()
    }

    /// URL de origen de un mod por id.
    func sourceURL(for id: String) -> URL? {
        ensureReady()
        let u = modsRoot.appendingPathComponent(id)
        return fm.fileExists(atPath: u.path) ? u : nil
    }
}
