import Foundation
import CryptoKit
import UIKit

// MARK: - Tipos de Datos y Progreso

public enum HashAlgorithm {
    case sha256
    case md5
}

// Localizaciones seguras dentro de los límites del sandbox
public enum SandboxLocation {
    case documents(subpath: String = "")
    case applicationSupport(subpath: String = "")
    case caches(subpath: String = "")
    case temporary(subpath: String = "")
    case appGroup(identifier: String, subpath: String = "")
    case custom(URL)
}

public struct SyncProgress {
    public let currentFile: String
    public let filesProcessed: Int
    public let totalFiles: Int
    public let bytesTransferred: Int64
    public let totalBytes: Int64
    
    public var fractionCompleted: Double {
        guard totalBytes > 0 else { return 0.0 }
        return Double(bytesTransferred) / Double(totalBytes)
    }
}

public struct SyncResult {
    public let copiedFilesCount: Int
    public let backedUpFilesCount: Int
    public let totalBytesCopied: Int64
    public let timestamp: Date
}

public struct RestoreResult {
    public let restoredFilesCount: Int
    public let removedNewFilesCount: Int
    public let timestamp: Date
}

// MARK: - Jerarquía de Errores Exhaustiva

public enum AssetSyncError: LocalizedError {
    case sourceNotFound(URL)
    case sourceNotReadable(URL)
    case destinationNotWritable(URL)
    case insufficientDiskSpace(requiredBytes: Int64, availableBytes: Int64)
    case checksumMismatch(file: URL, expected: String, actual: String)
    case backupFailed(file: URL, underlying: Error)
    case copyFailed(file: URL, underlying: Error)
    case restoreFailed(file: URL, underlying: Error)
    case noBackupFound(URL)
    case invalidURLScheme(String)
    case cannotOpenExternalApp(URL)
    case fileOperationFailed(description: String, underlying: Error?)
    
    public var errorDescription: String? {
        switch self {
        case .sourceNotFound(let url):
            return "El directorio o archivo de origen no existe: \(url.path)"
        case .sourceNotReadable(let url):
            return "Permisos insuficientes para leer la ruta de origen: \(url.path)"
        case .destinationNotWritable(let url):
            return "No hay permisos de escritura en la ruta de destino (Sandboxing/Permisos): \(url.path)"
        case .insufficientDiskSpace(let req, let avail):
            let reqMB = ByteCountFormatter.string(fromByteCount: req, countStyle: .file)
            let availMB = ByteCountFormatter.string(fromByteCount: avail, countStyle: .file)
            return "Espacio en disco insuficiente. Se requieren \(reqMB), pero solo hay \(availMB) disponibles."
        case .checksumMismatch(let file, let exp, let act):
            return "Fallo de integridad en '\(file.lastPathComponent)'. Esperado: \(exp), Calculado: \(act)"
        case .backupFailed(let file, let err):
            return "Fallo al crear la copia de seguridad (.bak) de '\(file.lastPathComponent)': \(err.localizedDescription)"
        case .copyFailed(let file, let err):
            return "Error al copiar el archivo '\(file.lastPathComponent)': \(err.localizedDescription)"
        case .restoreFailed(let file, let err):
            return "Fallo en la reversión/restauración de '\(file.lastPathComponent)': \(err.localizedDescription)"
        case .noBackupFound(let dir):
            return "No se encontraron copias de respaldo (.bak) para restaurar en: \(dir.path)"
        case .invalidURLScheme(let str):
            return "El formato del URL Scheme no es válido: \(str)"
        case .cannotOpenExternalApp(let url):
            return "El sistema iOS no pudo abrir la aplicación externa con el URL: \(url.absoluteString)"
        case .fileOperationFailed(let desc, let err):
            return "\(desc) \(err != nil ? "Detalle: \(err!.localizedDescription)" : "")"
        }
    }
}

// MARK: - Motor de Sincronización de Archivos y Recursos

/// Motor para preparar, auditar la integridad, respaldar y sincronizar
/// archivos de configuración y recursos dentro del Sandbox de iOS o contenedores App Group.
public final class AssetSyncEngine {
    
    public static let shared = AssetSyncEngine()
    
    private let fileManager: FileManager
    private let backupExtension = "bak"
    private let bufferSize = 64 * 1024 // 64 KB de buffer para streaming de hash sin saturar RAM
    
    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }
    
    // MARK: - 1. Verificación de Integridad Criptográfica (MD5 / SHA256)
    
    /// Calcula el hash criptográfico mediante streaming de bajo nivel con `FileHandle`
    /// para evitar agotar la memoria en archivos de gran tamaño.
    public func computeChecksum(of fileURL: URL, algorithm: HashAlgorithm = .sha256) throws -> String {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw AssetSyncError.sourceNotFound(fileURL)
        }
        guard fileManager.isReadableFile(atPath: fileURL.path) else {
            throw AssetSyncError.sourceNotReadable(fileURL)
        }
        
        let fileHandle = try FileHandle(forReadingFrom: fileURL)
        defer {
            try? fileHandle.close()
        }
        
        switch algorithm {
        case .sha256:
            var hasher = SHA256()
            while autoreleasepool(invoking: {
                let data = fileHandle.readData(ofLength: bufferSize)
                guard !data.isEmpty else { return false }
                hasher.update(data: data)
                return true
            }) {}
            return hasher.finalize().map { String(format: "%02x", $0) }.joined()
            
        case .md5:
            var hasher = Insecure.MD5()
            while autoreleasepool(invoking: {
                let data = fileHandle.readData(ofLength: bufferSize)
                guard !data.isEmpty else { return false }
                hasher.update(data: data)
                return true
            }) {}
            return hasher.finalize().map { String(format: "%02x", $0) }.joined()
        }
    }
    
    /// Valida que el archivo coincida exactamente con un hash esperado.
    public func validateIntegrity(
        of fileURL: URL,
        expectedHash: String,
        algorithm: HashAlgorithm = .sha256
    ) throws -> Bool {
        let actual = try computeChecksum(of: fileURL, algorithm: algorithm)
        let matches = actual.caseInsensitiveCompare(expectedHash) == .orderedSame
        if !matches {
            throw AssetSyncError.checksumMismatch(file: fileURL, expected: expectedHash, actual: actual)
        }
        return true
    }
    
    // MARK: - 2. Verificación de Espacio en Disco y Permisos
    
    /// Inspecciona el espacio disponible en el volumen del destino antes de escribir.
    public func verifyDiskSpace(at destinationDirectory: URL, requiredBytes: Int64) throws {
        // Asegurar que el directorio de destino exista para consultar sus atributos
        if !fileManager.fileExists(atPath: destinationDirectory.path) {
            try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        }
        
        let values = try destinationDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey])
        let availableCapacity = values.volumeAvailableCapacityForImportantUsage ?? Int64(values.volumeAvailableCapacity ?? 0)
        
        // Mantener un margen de seguridad mínimo del 10%
        let safeRequired = Int64(Double(requiredBytes) * 1.10)
        
        if availableCapacity < safeRequired {
            throw AssetSyncError.insufficientDiskSpace(requiredBytes: safeRequired, availableBytes: availableCapacity)
        }
    }
    
    /// Calcula el tamaño total en bytes de una estructura de archivos recursivamente.
    public func calculateTotalSize(at url: URL) throws -> (totalBytes: Int64, fileCount: Int) {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, thumbIsDir: &isDir) else {
            throw AssetSyncError.sourceNotFound(url)
        }
        
        if !isDir.boolValue {
            let attrs = try fileManager.attributesOfItem(atPath: url.path)
            let size = attrs[.size] as? Int64 ?? 0
            return (size, 1)
        }
        
        var total: Int64 = 0
        var count = 0
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return (0, 0)
        }
        
        for case let fileURL as URL in enumerator {
            let res = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
            if res.isDirectory == false {
                total += Int64(res.fileSize ?? 0)
                count += 1
            }
        }
        return (total, count)
    }
    
    // MARK: - 3. Sincronización Recursiva con Copias de Seguridad (.bak)
    
    /// Sincroniza recursivamente archivos desde `sourceURL` hacia `destinationURL`.
    /// - Parameters:
    ///   - sourceURL: Directorio o archivo de origen.
    ///   - destinationURL: Directorio de destino designado (por ejemplo App Group o Documents).
    ///   - expectedChecksums: Diccionario opcional [RutaRelativa: HashEsperado] para control de integridad estricto.
    ///   - algorithm: Algoritmo para verificar hashes (por defecto SHA256).
    ///   - progress: Callback en tiempo real de avance de sincronización.
    public func synchronize(
        from sourceURL: URL,
        to destinationURL: URL,
        expectedChecksums: [String: String]? = nil,
        algorithm: HashAlgorithm = .sha256,
        progress: ((SyncProgress) -> Void)? = nil
    ) async throws -> SyncResult {
        
        // 1. Validar existencia y lectura del origen
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw AssetSyncError.sourceNotFound(sourceURL)
        }
        guard fileManager.isReadableFile(atPath: sourceURL.path) else {
            throw AssetSyncError.sourceNotReadable(sourceURL)
        }
        
        // 2. Calcular tamaño total y verificar espacio libre
        let (totalBytes, totalFiles) = try calculateTotalSize(at: sourceURL)
        try verifyDiskSpace(at: destinationURL, requiredBytes: totalBytes)
        
        // 3. Validar permisos de escritura en el destino
        if fileManager.fileExists(atPath: destinationURL.path) && !fileManager.isWritableFile(atPath: destinationURL.path) {
            throw AssetSyncError.destinationNotWritable(destinationURL)
        }
        
        // 4. Obtener lista de archivos a procesar
        var filesToProcess: [URL] = []
        var isDir: ObjCBool = false
        fileManager.fileExists(atPath: sourceURL.path, thumbIsDir: &isDir)
        
        if isDir.boolValue {
            guard let enumerator = fileManager.enumerator(at: sourceURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
                throw AssetSyncError.fileOperationFailed(description: "No se pudo indexar el directorio de origen", underlying: nil)
            }
            for case let itemURL as URL in enumerator {
                let res = try itemURL.resourceValues(forKeys: [.isDirectoryKey])
                if res.isDirectory == false {
                    filesToProcess.append(itemURL)
                }
            }
        } else {
            filesToProcess.append(sourceURL)
        }
        
        var bytesTransferred: Int64 = 0
        var filesProcessed = 0
        var backedUpCount = 0
        
        // 5. Procesar cada archivo con backup y copia atómica
        for itemSourceURL in filesToProcess {
            let relativePath: String
            if isDir.boolValue {
                relativePath = itemSourceURL.path.replacingOccurrences(of: sourceURL.path + "/", with: "")
            } else {
                relativePath = itemSourceURL.lastPathComponent
            }
            
            let itemTargetURL = destinationURL.appendingPathComponent(relativePath)
            let itemTargetDir = itemTargetURL.deletingLastPathComponent()
            
            // Validar checksum antes de copiar si fue proporcionado
            if let expectedHash = expectedChecksums?[relativePath] {
                _ = try validateIntegrity(of: itemSourceURL, expectedHash: expectedHash, algorithm: algorithm)
            }
            
            // Asegurar que la carpeta intermedia exista
            if !fileManager.fileExists(atPath: itemTargetDir.path) {
                try fileManager.createDirectory(at: itemTargetDir, withIntermediateDirectories: true)
            }
            
            // Crear copia de seguridad (.bak) si el archivo destino ya existe
            if fileManager.fileExists(atPath: itemTargetURL.path) {
                let backupURL = itemTargetURL.appendingPathExtension(backupExtension)
                do {
                    // Si ya existía un backup previo de una iteración anterior, lo reemplazamos
                    if fileManager.fileExists(atPath: backupURL.path) {
                        try fileManager.removeItem(at: backupURL)
                    }
                    try fileManager.copyItem(at: itemTargetURL, to: backupURL)
                    backedUpCount += 1
                } catch {
                    throw AssetSyncError.backupFailed(file: itemTargetURL, underlying: error)
                }
                
                // Eliminar archivo anterior para sobreescribir
                try fileManager.removeItem(at: itemTargetURL)
            }
            
            // Copiar nuevo archivo
            do {
                try fileManager.copyItem(at: itemSourceURL, to: itemTargetURL)
            } catch {
                throw AssetSyncError.copyFailed(file: itemTargetURL, underlying: error)
            }
            
            // Actualizar métricas
            let attrs = try fileManager.attributesOfItem(atPath: itemTargetURL.path)
            let itemSize = attrs[.size] as? Int64 ?? 0
            bytesTransferred += itemSize
            filesProcessed += 1
            
            let currentProg = SyncProgress(
                currentFile: relativePath,
                filesProcessed: filesProcessed,
                totalFiles: totalFiles,
                bytesTransferred: bytesTransferred,
                totalBytes: totalBytes
            )
            progress?(currentProg)
        }
        
        return SyncResult(
            copiedFilesCount: filesProcessed,
            backedUpFilesCount: backedUpCount,
            totalBytesCopied: bytesTransferred,
            timestamp: Date()
        )
    }
    
    // MARK: - 4. Método de Reversión y Restauración (Restore to Original)
    
    /// Restaura todos los archivos `.bak` presentes en el directorio de destino a su estado original,
    /// eliminando las versiones modificadas instaladas por la sincronización.
    public func restoreFromBackup(in destinationDirectory: URL) async throws -> RestoreResult {
        guard fileManager.fileExists(atPath: destinationDirectory.path) else {
            throw AssetSyncError.sourceNotFound(destinationDirectory)
        }
        
        guard let enumerator = fileManager.enumerator(at: destinationDirectory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            throw AssetSyncError.fileOperationFailed(description: "No se pudo explorar el directorio de destino para restauración", underlying: nil)
        }
        
        var backupFiles: [URL] = []
        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == backupExtension {
                backupFiles.append(fileURL)
            }
        }
        
        guard !backupFiles.isEmpty else {
            throw AssetSyncError.noBackupFound(destinationDirectory)
        }
        
        var restoredCount = 0
        
        for backupURL in backupFiles {
            // El archivo original sin la extensión .bak
            let originalTargetURL = backupURL.deletingPathExtension()
            
            do {
                // Eliminar el archivo modificado actual si existe
                if fileManager.fileExists(atPath: originalTargetURL.path) {
                    try fileManager.removeItem(at: originalTargetURL)
                }
                
                // Mover el archivo .bak de vuelta a su nombre original
                try fileManager.moveItem(at: backupURL, to: originalTargetURL)
                restoredCount += 1
            } catch {
                throw AssetSyncError.restoreFailed(file: originalTargetURL, underlying: error)
            }
        }
        
        return RestoreResult(
            restoredFilesCount: restoredCount,
            removedNewFilesCount: restoredCount,
            timestamp: Date()
        )
    }
    
    // MARK: - 5. Lanzador de Aplicación Externa vía URL Scheme
    
    /// Abre de forma segura una aplicación externa en iOS utilizando su URL Scheme registrado.
    /// - Parameters:
    ///   - urlScheme: Esquema o URL completa (ej: `myexternalapp://open?action=sync`).
    ///   - parameters: Diccionario opcional de parámetros que serán añadidos como query parameters.
    @MainActor
    public func openExternalApp(urlScheme: String, parameters: [String: String]? = nil) async throws {
        guard var components = URLComponents(string: urlScheme) else {
            throw AssetSyncError.invalidURLScheme(urlScheme)
        }
        
        if let params = parameters, !params.isEmpty {
            var items = components.queryItems ?? []
            for (k, v) in params {
                items.append(URLQueryItem(name: k, value: v))
            }
            components.queryItems = items
        }
        
        guard let finalURL = components.url else {
            throw AssetSyncError.invalidURLScheme(urlScheme)
        }
        
        guard UIApplication.shared.canOpenURL(finalURL) else {
            throw AssetSyncError.cannotOpenExternalApp(finalURL)
        }
        
        let success = await withCheckedContinuation { continuation in
            UIApplication.shared.open(finalURL, options: [:]) { opened in
                continuation.resume(returning: opened)
            }
        }
        
        if !success {
            throw AssetSyncError.cannotOpenExternalApp(finalURL)
        }
    }
    
    // MARK: - 6. Resolución Segura de Rutas de Sandbox y App Groups
    
    /// Resuelve de forma segura y prepara una URL dentro de los límites del Sandbox de iOS o App Groups.
    public func resolveDestinationURL(for location: SandboxLocation) throws -> URL {
        let baseURL: URL
        let subpath: String
        
        switch location {
        case .documents(let path):
            baseURL = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            subpath = path
            
        case .applicationSupport(let path):
            baseURL = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            subpath = path
            
        case .caches(let path):
            baseURL = try fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            subpath = path
            
        case .temporary(let path):
            baseURL = fileManager.temporaryDirectory
            subpath = path
            
        case .appGroup(let groupIdentifier, let path):
            guard let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier) else {
                throw AssetSyncError.destinationNotWritable(
                    URL(fileURLWithPath: "group://\(groupIdentifier)")
                )
            }
            baseURL = groupURL
            subpath = path
            
        case .custom(let url):
            return url
        }
        
        let targetURL = subpath.isEmpty ? baseURL : baseURL.appendingPathComponent(subpath)
        if !fileManager.fileExists(atPath: targetURL.path) {
            try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true)
        }
        return targetURL
    }
}

// Helper interno para compatibilidad de firma con ObjCBool
private extension FileManager {
    func fileExists(atPath path: String, thumbIsDir isDirectory: inout ObjCBool) -> Bool {
        return self.fileExists(atPath: path, isDirectory: &isDirectory)
    }
}
