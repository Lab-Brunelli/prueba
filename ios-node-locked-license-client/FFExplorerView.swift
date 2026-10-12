import SwiftUI

/// Explorador de diagnóstico: se conecta al contenedor de Free Fire vía
/// MobileHouseArrest y muestra su estructura REAL para saber dónde van los mods.
struct FFExplorerView: View {

    @State private var rootURL: URL?
    @State private var relativePath: String = ""
    @State private var entries: [Entry] = []
    @State private var status: String = "Tocá CONECTAR para acceder al contenedor de Free Fire."
    @State private var isBusy: Bool = false
    @State private var isConnected: Bool = false

    private let fm = FileManager.default

    struct Entry: Identifiable {
        let id = UUID()
        let name: String
        let isDir: Bool
        let size: Int64
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                Card {
                    HStack(spacing: 10) {
                        Image(systemName: isConnected ? "checkmark.seal.fill" : "bolt.horizontal.circle")
                            .foregroundStyle(isConnected ? Theme.safeGreen : Theme.textSecondary)
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                }

                if isConnected {
                    Card {
                        HStack(spacing: 8) {
                            Image(systemName: "folder.fill").foregroundStyle(Theme.safeGreen)
                            Text("/" + relativePath)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button { UIPasteboard.general.string = fullPath } label: {
                                Image(systemName: "doc.on.doc").font(.caption)
                            }
                            .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        connect()
                    } label: {
                        Label(isConnected ? "Reconectar" : "Conectar", systemImage: "link")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Theme.safeGreen).foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if isConnected && !relativePath.isEmpty {
                        Button {
                            goUp()
                        } label: {
                            Label("Subir", systemImage: "arrow.up")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Theme.card).foregroundStyle(Theme.textPrimary)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardStroke, lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }

                if isBusy {
                    ProgressView().tint(Theme.safeGreen)
                }

                if isConnected && entries.isEmpty && !isBusy {
                    Card {
                        Text("Carpeta vacía.")
                            .font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                }

                ForEach(entries) { e in
                    Button {
                        if e.isDir { enter(e.name) }
                    } label: {
                        Card {
                            HStack(spacing: 12) {
                                IconBox(system: e.isDir ? "folder.fill" : "doc.fill")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(e.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Theme.textPrimary)
                                        .lineLimit(1)
                                    Text(e.isDir ? "Carpeta" : humanSize(e.size))
                                        .font(.caption2).foregroundStyle(Theme.textSecondary)
                                }
                                Spacer()
                                if e.isDir {
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
    }

    private var fullPath: String {
        guard let root = rootURL else { return "" }
        return root.appendingPathComponent(relativePath).path
    }

    private func connect() {
        isBusy = true
        status = "Conectando con Free Fire…"
        DispatchQueue.global(qos: .userInitiated).async {
            let url = HouseArrestManager.shared.containerURL(forBundleID: HouseArrestManager.freeFireBundleID)
            DispatchQueue.main.async {
                isBusy = false
                guard let url = url else {
                    isConnected = false
                    status = "❌ No se pudo acceder.\n• ¿Free Fire está instalado?\n• ¿El certificado soporta MobileHouseArrest?"
                    return
                }
                rootURL = url
                isConnected = true
                relativePath = ""
                status = "Conectado ✅\n" + url.path
                load()
            }
        }
    }

    private func enter(_ name: String) {
        relativePath = relativePath.isEmpty ? name : relativePath + "/" + name
        load()
    }

    private func goUp() {
        var parts = relativePath.split(separator: "/").map(String.init)
        _ = parts.popLast()
        relativePath = parts.joined(separator: "/")
        load()
    }

    private func load() {
        guard let root = rootURL else { return }
        let target = root.appendingPathComponent(relativePath)
        isBusy = true
        DispatchQueue.global(qos: .userInitiated).async {
            let keys: Set<URLResourceKey> = [.isDirectoryKey, .fileSizeKey]
            let urls = (try? fm.contentsOfDirectory(at: target,
                                                    includingPropertiesForKeys: Array(keys),
                                                    options: [])) ?? []
            let list: [Entry] = urls.map { u in
                let rv = try? u.resourceValues(forKeys: keys)
                return Entry(name: u.lastPathComponent,
                             isDir: rv?.isDirectory ?? false,
                             size: Int64(rv?.fileSize ?? 0))
            }.sorted { a, b in
                if a.isDir != b.isDir { return a.isDir }
                return a.name.lowercased() < b.name.lowercased()
            }
            DispatchQueue.main.async {
                isBusy = false
                entries = list
            }
        }
    }

    private func humanSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
