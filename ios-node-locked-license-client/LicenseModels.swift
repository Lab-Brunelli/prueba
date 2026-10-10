import Foundation

// MARK: - Network Request Payloads

public struct AuthRequest: Codable {
    public let license_key: String
    public let hwid: String
    
    public init(licenseKey: String, hwid: String) {
        self.license_key = licenseKey
        self.hwid = hwid
    }
}

// MARK: - Server Response Payloads

public struct BaseResponse<T: Codable>: Codable {
    public let success: Bool
    public let message: String?
    public let data: T?
    public let error: ServerErrorDetail?
}

public struct ServerErrorDetail: Codable {
    public let name: String?
    public let message: String?
}

public struct AuthPayload: Codable {
    public let token: String
    public let license: LicenseInfo
}

public struct LicenseInfo: Codable, Identifiable {
    public let id: String
    public let license_key: String
    public let role: String
    public let hwid: String
    public let expires_at: String?
    public let duration_hours: Int?
    public let is_lifetime: Bool
    
    public var formattedExpiration: String {
        guard let expiresAt = expires_at else { return "Vitalicia (Sin límite)" }
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var date = isoFormatter.date(from: expiresAt)
        if date == nil {
            isoFormatter.formatOptions = [.withInternetDateTime]
            date = isoFormatter.date(from: expiresAt)
        }
        
        guard let validDate = date else { return expiresAt }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        displayFormatter.locale = Locale(identifier: "es_ES")
        return displayFormatter.string(from: validDate)
    }
}

public struct HeartbeatPayload: Codable {
    public let status: String
    public let license_key: String
    public let expires_at: String?
    public let remaining_seconds: Int?
    public let last_checked_at: String
    
    public var formattedRemainingTime: String {
        guard let seconds = remaining_seconds else { return "Ilimitado" }
        if seconds <= 0 { return "Expirada" }
        
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 24 {
            let days = hours / 24
            return "\(days) días restantes"
        } else {
            return String(format: "%02dh %02dm %02ds", hours, minutes, secs)
        }
    }
}

// MARK: - Custom Client Errors

public enum AuthError: LocalizedError {
    case invalidCredentials(String)
    case hwidMismatch(String)
    case licenseExpired(String)
    case licenseBanned(String)
    case networkError(String)
    case decodingError
    case unauthorized
    case serverError(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidCredentials(let msg):
            return "Clave de licencia no válida: \(msg)"
        case .hwidMismatch(let msg):
            return "Dispositivo no autorizado: \(msg)"
        case .licenseExpired(let msg):
            return "Licencia expirada: \(msg)"
        case .licenseBanned(let msg):
            return "Licencia inhabilitada: \(msg)"
        case .networkError(let msg):
            return "Error de conexión: \(msg)"
        case .decodingError:
            return "Error al procesar la respuesta del servidor."
        case .unauthorized:
            return "Sesión revocada o no autorizada."
        case .serverError(let msg):
            return "Error del servidor: \(msg)"
        }
    }
}

// MARK: - Dashboard Local Settings Models

public struct ConfigCategory: Identifiable {
    public let id = UUID()
    public let title: String
    public let icon: String
    public var items: [ConfigItem]
    
    public init(title: String, icon: String, items: [ConfigItem]) {
        self.title = title
        self.icon = icon
        self.items = items
    }
}

public struct ConfigItem: Identifiable {
    public let id: String
    public let title: String
    public let subtitle: String
    public var isEnabled: Bool
    
    public init(id: String, title: String, subtitle: String, isEnabled: Bool = false) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.isEnabled = isEnabled
    }
}
