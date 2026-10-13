import Foundation

/// Máquina de estados de la sesión de mods. Recuerda si hay mods ACTIVOS en el
/// contenedor, para que el botón sepa si corresponde activar o desactivar.
///
/// El flujo indetectable es: activar con el juego CERRADO → cargar el juego →
/// desactivar con el juego ABIERTO y ya cargado. Los assets quedan en RAM.
final class ModSession {
    static let shared = ModSession()
    private init() {}

    private let installedKey = "FX.modSession.installed"

    /// true = hay mods escritos en el contenedor ahora mismo.
    var isInstalled: Bool {
        get { UserDefaults.standard.bool(forKey: installedKey) }
        set { UserDefaults.standard.set(newValue, forKey: installedKey) }
    }

    /// Carpeta de backups FUERA del contenedor del juego: <Documents de FX>/NLBackup
    /// Así el contenedor de Free Fire queda 100% limpio.
    var externalBackupRoot: URL {
        let docs = (try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: true)) ?? FileManager.default.temporaryDirectory
        let u = docs.appendingPathComponent("NLBackup")
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }
}
