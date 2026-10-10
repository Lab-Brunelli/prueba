import Foundation
import Security
import UIKit

/// Gestor seguro de Keychain para persistencia de identificadores de hardware (HWID)
/// y credenciales de sesión en iOS.
public final class KeychainManager {
    
    public static let shared = KeychainManager()
    
    private let serviceIdentifier = "com.license.nodelock.service"
    private let hwidAccountKey = "hardware_identifier_vendor_uuid"
    private let sessionTokenAccountKey = "license_session_jwt_token"
    private let storedKeyAccountKey = "last_activated_license_key"
    
    private init() {}
    
    // MARK: - Hardware ID (Device UUID)
    
    /// Obtiene el HWID persistente del dispositivo.
    /// Si no existe previamente en Keychain, toma `UIDevice.current.identifierForVendor`
    /// (o genera un UUID criptográfico de respaldo) y lo almacena de forma inmutable
    /// con protección `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
    ///
    /// Esto garantiza que el identificador sobreviva desinstalaciones y reinstalaciones
    /// sin transferirse a otros dispositivos mediante copias de seguridad de iCloud.
    public func getOrCreateHardwareIdentifier() -> String {
        if let existingHwid = get(account: hwidAccountKey) {
            return existingHwid
        }
        
        let newIdentifier = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let success = save(account: hwidAccountKey, value: newIdentifier, thisDeviceOnly: true)
        
        if !success {
            NSLog("⚠️ [KeychainManager] Error al guardar HWID en Keychain, usando valor volátil.")
        }
        
        return newIdentifier
    }
    
    // MARK: - Session Token & Stored Key
    
    public func saveSessionToken(_ token: String) -> Bool {
        return save(account: sessionTokenAccountKey, value: token, thisDeviceOnly: true)
    }
    
    public func getSessionToken() -> String? {
        return get(account: sessionTokenAccountKey)
    }
    
    public func deleteSessionToken() -> Bool {
        return delete(account: sessionTokenAccountKey)
    }
    
    public func saveLastLicenseKey(_ key: String) -> Bool {
        return save(account: storedKeyAccountKey, value: key, thisDeviceOnly: true)
    }
    
    public func getLastLicenseKey() -> String? {
        return get(account: storedKeyAccountKey)
    }
    
    // MARK: - Generic Keychain Operations
    
    @discardableResult
    public func save(account: String, value: String, thisDeviceOnly: Bool = true) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        
        // Atributo de accesibilidad: no se exporta en backups ni se sincroniza por iCloud
        let accessibility = thisDeviceOnly
            ? kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            : kSecAttrAccessibleAfterFirstUnlock
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility
        ]
        
        // Eliminar versión previa si existe
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    public func get(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess, let data = dataTypeRef as? Data else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    @discardableResult
    public func delete(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
