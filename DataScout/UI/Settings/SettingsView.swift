import SwiftUI

/// Beállítások, demó mód váltó, adatmegőrzési szabályok,
/// CSV export és teljes adatbázis-törlés.
public struct SettingsView: View {
    @ObservedObject var vm: AppViewModel
    @ObservedObject private var liveManager = LiveActivityManager.shared
    @State private var showingWipeAlert = false
    @State private var showingExportSheet = false
    @State private var exportedCSVText = ""
    @AppStorage("datascout_retention_days") private var retentionDays: Int = 30

    public var body: some View {
        NavigationStack {
            Form {
                // Dynamic Island & Élő Követés Szekció
                Section(
                    header: Text("Élő Követés & Dynamic Island"),
                    footer: Text("Valós időben kivetíti a mobil adatforgalmi egyenleget és sebességet az iPhone Dynamic Island szigetére és a zárolási képernyőre (Live Activity).")
                ) {
                    Toggle(isOn: Binding(
                        get: { liveManager.isActivityRunning },
                        set: { newValue in
                            if newValue {
                                vm.startLiveActivity()
                            } else {
                                vm.stopLiveActivity()
                            }
                        }
                    )) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(liveManager.isActivityRunning ? Color(red: 0.0, green: 0.85, blue: 0.5).opacity(0.18) : Color.secondary.opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "dot.radiowaves.left.and.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(liveManager.isActivityRunning ? Color(red: 0.0, green: 0.85, blue: 0.5) : .secondary)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text("Dynamic Island & Élő Nézet")
                                        .font(.body)
                                    if liveManager.isActivityRunning {
                                        Text("ÉLŐ")
                                            .font(.system(size: 8.5, weight: .black, design: .rounded))
                                            .foregroundColor(Color(red: 0.0, green: 0.85, blue: 0.5))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1.5)
                                            .background(Color(red: 0.0, green: 0.85, blue: 0.5).opacity(0.15))
                                            .clipShape(Capsule())
                                    }
                                }
                                Text(liveManager.isActivityRunning ? "Aktív a szigeten és a zárolási képernyőn" : "Kikapcsolva")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Adatkezelés és Megőrzés
                Section(header: Text("Adatvédelem és Tárolás")) {
                    Picker("Adatok megőrzési ideje", selection: $retentionDays) {
                        Text("7 nap").tag(7)
                        Text("30 nap").tag(30)
                        Text("90 nap").tag(90)
                        Text("Korlátlan").tag(0)
                    }

                    Button {
                        Task {
                            exportedCSVText = await vm.exportCSV()
                            showingExportSheet = true
                        }
                    } label: {
                        Label("Adatok exportálása (CSV)", systemImage: "square.and.arrow.up")
                    }

                    Button(role: .destructive) {
                        showingWipeAlert = true
                    } label: {
                        Label("Mérési előzmények törlése", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }

                // Technikai Információk és Névjegy
                Section(header: Text("Rendszer és Architektúra")) {
                    HStack {
                        Text("Mérési motor")
                        Spacer()
                        Text("Darwin sysctl 64-bit").foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Túlcsordulás-védelem")
                        Spacer()
                        Text("Aktív (64-bit if_data64)").foregroundColor(.green)
                    }

                    HStack {
                        Text("Adattárolás")
                        Spacer()
                        Text("100% lokális eszközön").foregroundColor(.secondary)
                    }

                    HStack {
                        Text("iOS Kompatibilitás")
                        Spacer()
                        Text("iOS 17.0 - iOS 27+").foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Verzió")
                        Spacer()
                        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
                        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
                        Text("DataScout v\(appVersion) (Build \(buildNumber))").foregroundColor(.secondary)
                    }
                }

                // Módszertani Nyilatkozat
                Section(header: Text("Felelős Adatkezelési Nyilatkozat")) {
                    Text("A DataScout az Apple iOS hivatalos adatvédelmi irányelvei szerint működik. Lakossági eszközökön a rendszer nem teszi elérhetővé az idegen appok csomagszintű forgalmát. A hardveres összegzett mérések 100%-osak, a domain-hozzárendelések heurisztikusak.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Alsó térköz a lebegő menüsávhoz
                Section {
                    Color.clear
                        .frame(height: 70)
                        .listRowBackground(Color.clear)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 40)
            }
            .navigationTitle("Beállítások")
            .confirmationDialog("Biztosan törölni szeretnéd az összes rögzített adatot?", isPresented: $showingWipeAlert, titleVisibility: .visible) {
                Button("Minden előzmény törlése", role: .destructive) {
                    Task { await vm.wipeAllData() }
                }
                Button("Mégse", role: .cancel) {}
            }
            .sheet(isPresented: $showingExportSheet) {
                ShareSheet(items: [exportedCSVText])
            }
            .onChange(of: retentionDays) { _, newVal in
                vm.updateRetentionDays(newVal)
            }
        }
    }
}

/// Egyszerű megosztó nézet (UIActivityViewController wrapper)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
