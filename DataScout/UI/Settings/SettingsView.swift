import SwiftUI

/// Beállítások, demó mód váltó, adatmegőrzési szabályok,
/// CSV export és teljes adatbázis-törlés.
public struct SettingsView: View {
    @ObservedObject var vm: AppViewModel
    @State private var showingWipeAlert = false
    @State private var showingExportSheet = false
    @State private var exportedCSVText = ""
    @State private var retentionDays = 30

    public var body: some View {
        NavigationStack {
            Form {
                // Demó Mód Szekció
                Section(header: Text("Tesztelés és Előnézet"), footer: Text("A demó mód 28 napos minta előzményeket, szimulált csúcsidőszakokat, anomáliát és domaineket tölt be a funkciók kipróbálásához.")) {
                    Toggle("Demó üzemmód (Mintaadatok)", isOn: $vm.isDemoMode)
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
                        Text("DataScout v1.0.0 (Build 26.5)").foregroundColor(.secondary)
                    }
                }

                // Módszertani Nyilatkozat
                Section(header: Text("Felelős Adatkezelési Nyilatkozat")) {
                    Text("A DataScout az Apple iOS hivatalos adatvédelmi irányelvei szerint működik. Lakossági eszközökön a rendszer nem teszi elérhetővé az idegen appok csomagszintű forgalmát. A hardveres összegzett mérések 100%-osak, a domain-hozzárendelések heurisztikusak.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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
