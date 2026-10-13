import Foundation
import Darwin
import XPC

/// Acceso a contenedores de otras apps via el permiso privado MobileHouseArrest.
/// REQUISITO: el Bundle ID de esta app debe ser exactamente
/// "com.apple.mobile.MobileHouseArrest".
///
/// Verificado contra el PoC real 0xjohnnydev/MobileHouseArrest-PoC:
/// class 2, xpc_string_create directo, flags 0x900000000, activate(object,false).
final class HouseArrestManager {

    static let shared = HouseArrestManager()

    /// Bundle ID del juego objetivo. Free Fire = com.dts.freefireth (MAX = com.dts.freefiremax)
    static let freeFireBundleID = "com.dts.freefireth"

    private let libPath = "/usr/lib/system/libsystem_containermanager.dylib"
    private var lib: UnsafeMutableRawPointer?

    private var liveQueries: [UnsafeMutableRawPointer] = []
    private var liveObjects: [UnsafeMutableRawPointer] = []

    /// Caché del contenedor para no re-consultar en cada llamada.
    private var cachedContainer: URL?

    private var pQueryCreate: (@convention(c) () -> UnsafeMutableRawPointer?)?
    private var pQuerySetClass: (@convention(c) (UnsafeMutableRawPointer?, UInt64) -> Void)?
    private var pQuerySetIds: (@convention(c) (UnsafeMutableRawPointer?, xpc_object_t) -> Void)?
    private var pQuerySetFlags: (@convention(c) (UnsafeMutableRawPointer?, UInt64) -> Void)?
    private var pQuerySetPart: (@convention(c) (UnsafeMutableRawPointer?, UInt64) -> Void)?
    private var pQueryResult: (@convention(c) (UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?)?
    private var pObjectCopy: (@convention(c) (UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?)?
    private var pObjectPath: (@convention(c) (UnsafeMutableRawPointer?) -> UnsafePointer<CChar>?)?
    private var pActivate: (@convention(c) (UnsafeMutableRawPointer?, Bool) -> Bool)?

    private init() {}

    private func loadIfNeeded() -> Bool {
        if lib != nil { return true }
        guard let h = dlopen(libPath, RTLD_NOW | RTLD_LOCAL) else { return false }
        lib = h
        pQueryCreate = sym(h, "container_query_create")
        pQuerySetClass = sym(h, "container_query_set_class")
        pQuerySetIds = sym(h, "container_query_set_identifiers")
        pQuerySetFlags = sym(h, "container_query_operation_set_flags")
        pQuerySetPart = sym(h, "container_query_operation_set_part")
        pQueryResult = sym(h, "container_query_get_single_result")
        pObjectCopy = sym(h, "container_object_copy")
        pObjectPath = sym(h, "container_object_get_path")
        pActivate = sym(h, "container_object_sandbox_extension_activate")
        return pQueryCreate != nil && pQueryResult != nil && pObjectPath != nil && pActivate != nil
    }

    private func sym<T>(_ h: UnsafeMutableRawPointer, _ name: String) -> T? {
        guard let s = dlsym(h, name) else { return nil }
        return unsafeBitCast(s, to: T.self)
    }

    /// Devuelve la URL del contenedor de datos de otra app y ACTIVA el acceso de lectura/escritura.
    /// Usa caché: si ya lo tenemos, no vuelve a consultar.
    func containerURL(forBundleID bundleID: String) -> URL? {
        if let c = cachedContainer { return c }

        guard loadIfNeeded(),
              let queryCreate = pQueryCreate,
              let querySetClass = pQuerySetClass,
              let querySetIds = pQuerySetIds,
              let querySetFlags = pQuerySetFlags,
              let queryResult = pQueryResult,
              let objectCopy = pObjectCopy,
              let objectPath = pObjectPath,
              let activate = pActivate else { return nil }

        guard let query = queryCreate() else { return nil }
        querySetClass(query, 2)
        let ident = xpc_string_create(bundleID)
        querySetIds(query, ident)
        querySetFlags(query, UInt64(0x900000000))
        pQuerySetPart?(query, 0)

        guard let borrowed = queryResult(query) else {
            liveQueries.append(query)
            return nil
        }
        guard let object = objectCopy(borrowed), let cPath = objectPath(object) else {
            liveQueries.append(query)
            return nil
        }

        _ = activate(object, false)
        let path = String(cString: cPath)

        liveQueries.append(query)
        liveObjects.append(object)

        let url = URL(fileURLWithPath: path)
        cachedContainer = url
        return url
    }

    /// Re-pide y re-activa el contenedor. Llamar cuando la app vuelve a primer plano:
    /// así DESACTIVAR sigue funcionando aunque iOS haya soltado la extensión de sandbox.
    @discardableResult
    func reattach() -> Bool {
        cachedContainer = nil
        return containerURL(forBundleID: Self.freeFireBundleID) != nil
    }
}
