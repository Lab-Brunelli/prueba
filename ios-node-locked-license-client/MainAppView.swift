import SwiftUI

enum AppTab: Hashable { case home, freefire, profile, support }

public struct MainAppView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var tab: AppTab = .home
    @State private var selectedCategory: Int = 0

    public init(viewModel: AppViewModel) { self.viewModel = viewModel }

    public var body: some View {
        ZStack(alignment: .bottom) {
            Theme.bg.ignoresSafeArea()
            Group {
                switch tab {
                case .home: HomeView(viewModel: viewModel)
                case .freefire: FreeFireView(viewModel: viewModel, selected: $selectedCategory)
                case .profile: ProfileView(viewModel: viewModel)
                case .support: SupportView()
                }
            }
            .padding(.bottom, 80)
            BottomBar(tab: $tab)
        }
        .preferredColorScheme(.dark)
        .alert(viewModel.externalAppAlertTitle, isPresented: $viewModel.showExternalAppAlert) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(viewModel.externalAppAlertMessage)
        }
    }
}

struct BottomBar: View {
    @Binding var tab: AppTab
    var body: some View {
        HStack {
            item(.home, "Inicio", "house.fill")
            item(.freefire, "Free Fire", "gamecontroller.fill")
            item(.profile, "Perfil", "person.fill")
            item(.support, "Soporte", "headphones")
        }
        .padding(.horizontal, 10).padding(.vertical, 10)
        .background(Theme.card)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.cardStroke, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 12).padding(.bottom, 4)
    }
    func item(_ t: AppTab, _ label: String, _ icon: String) -> some View {
        Button { withAnimation(.spring(response: 0.3)) { tab = t } } label: {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 18))
                Text(label).font(.caption2.weight(.semibold))
            }
            .foregroundStyle(tab == t ? Theme.textPrimary : Theme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(tab == t ? Theme.pill : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

// MARK: - Inicio
struct HomeView: View {
    @ObservedObject var viewModel: AppViewModel
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Text("Inicio").font(.headline).foregroundStyle(Theme.textPrimary)
                    Spacer()
                    IconBox(system: "terminal")
                    IconBox(system: "gearshape")
                }
                Card {
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 12).fill(Theme.pill)
                            .frame(width: 48, height: 48)
                            .overlay(Image(systemName: "xmark").font(.headline).foregroundStyle(.white))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Panel").font(.headline).foregroundStyle(.white)
                            Text("Tu iPhone, listo.").font(.caption).foregroundStyle(Theme.textSecondary)
                            Text("Versión 5.0.1").font(.caption2).foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                    }
                }
                HStack {
                    Text("Estado del dispositivo").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                    Spacer()
                    HStack(spacing: 6) {
                        Circle().fill(Theme.safeGreen).frame(width: 8, height: 8)
                        Text("Activo").font(.caption).foregroundStyle(Theme.safeGreen)
                    }
                }
                Card {
                    VStack(spacing: 12) {
                        infoRow("iphone", "Modelo de hardware", deviceModel)
                        Divider().background(Theme.cardStroke)
                        infoRow("gearshape", "iOS Version", UIDevice.current.systemVersion)
                        Divider().background(Theme.cardStroke)
                        infoRow("checkmark.shield.fill", "Compatibilidad del exploit", "Compatible")
                    }
                }
            }
            .padding(16)
        }
    }
    func infoRow(_ icon: String, _ title: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            IconBox(system: icon)
            Text(title).font(.subheadline).foregroundStyle(Theme.textPrimary)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
        }
    }
    var deviceModel: String {
        var sys = utsname(); uname(&sys)
        let m = Mirror(reflecting: sys.machine)
        return m.children.reduce("") { id, e in
            guard let v = e.value as? Int8, v != 0 else { return id }
            return id + String(UnicodeScalar(UInt8(v)))
        }
    }
}

// MARK: - Free Fire
struct FreeFireView: View {
    @ObservedObject var viewModel: AppViewModel
    @Binding var selected: Int
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Card {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 12).fill(Theme.pill)
                            .frame(width: 44, height: 44)
                            .overlay(Image(systemName: "flame.fill").foregroundStyle(.orange))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Free Fire").font(.headline).foregroundStyle(.white)
                            Text("NORMAL").font(.caption2.weight(.bold)).foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        Badge(text: "Seguro")
                    }
                }

                if !viewModel.configCategories.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.configCategories.indices, id: \.self) { i in
                                Button { selected = i } label: {
                                    Text(viewModel.configCategories[i].title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(selected == i ? .black : Theme.textSecondary)
                                        .padding(.horizontal, 16).padding(.vertical, 8)
                                        .background(selected == i ? Color.white : Theme.card)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    let cat = viewModel.configCategories[min(selected, viewModel.configCategories.count - 1)]
                    ForEach(cat.items) { item in
                        ToggleRow(
                            title: item.title,
                            subtitle: item.subtitle,
                            icon: cat.icon,
                            isOn: Binding(
                                get: { item.isEnabled },
                                set: { newVal in
                                    if let ci = viewModel.configCategories.firstIndex(where: { $0.id == cat.id }),
                                       let ii = viewModel.configCategories[ci].items.firstIndex(where: { $0.id == item.id }) {
                                        viewModel.configCategories[ci].items[ii].isEnabled = newVal
                                    }
                                }
                            )
                        )
                    }
                }

                Button {
                    viewModel.applyAndLaunchExternalApp()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.up.right.square.fill")
                        Text("Aplicar y lanzar").fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(LinearGradient(colors: [Theme.safeGreen, .teal], startPoint: .leading, endPoint: .trailing))
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Perfil
struct ProfileView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var music = true
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Card {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 12).fill(Theme.pill)
                            .frame(width: 48, height: 48)
                            .overlay(Image(systemName: "person.fill").foregroundStyle(.white))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.licenseInfo?.role.uppercased() ?? "USUARIO")
                                .font(.caption).foregroundStyle(Theme.textSecondary)
                            Text("Cuenta").font(.headline).foregroundStyle(.white)
                        }
                        Spacer()
                        Badge(text: "Activo")
                    }
                }
                Card {
                    VStack(spacing: 12) {
                        row("key.fill", "Clave", viewModel.licenseInfo?.license_key ?? viewModel.licenseKeyInput)
                        Divider().background(Theme.cardStroke)
                        row("clock.fill", "Tiempo restante", viewModel.heartbeatData?.formattedRemainingTime ?? "—")
                        Divider().background(Theme.cardStroke)
                        row("number", "UDID", String(viewModel.hwid.prefix(16)) + "…")
                    }
                }
                Card {
                    HStack {
                        IconBox(system: "music.note")
                        Text("Música").font(.subheadline).foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Toggle("", isOn: $music).labelsHidden().tint(Theme.safeGreen)
                    }
                }
                Button { viewModel.logout() } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Cerrar sesión").font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(Theme.danger)
                    .frame(maxWidth: .infinity).padding(16)
                    .background(Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.cardStroke, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
            }
            .padding(16)
        }
    }
    func row(_ icon: String, _ title: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            IconBox(system: icon)
            Text(title).font(.subheadline).foregroundStyle(Theme.textPrimary)
            Spacer()
            Text(value).font(.subheadline).foregroundStyle(Theme.textSecondary).lineLimit(1)
        }
    }
}

// MARK: - Soporte
struct SupportView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                link("bubble.left.and.bubble.right.fill", "Soporte Discord", "Únete para recibir ayuda", "https://discord.gg/")
                link("megaphone.fill", "Anuncios", "Novedades y actualizaciones", "https://discord.gg/")
                link("doc.text.fill", "Términos y condiciones", "Lee antes de usar", "https://discord.gg/")
            }
            .padding(16)
        }
    }
    func link(_ icon: String, _ title: String, _ subtitle: String, _ url: String) -> some View {
        Link(destination: URL(string: url)!) {
            Card {
                HStack(spacing: 12) {
                    IconBox(system: icon)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        Text(subtitle).font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }
}
