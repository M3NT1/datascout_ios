import SwiftUI

/// A felhasználó által használt aktív alkalmazások és szolgáltatások konfigurációs lapja.
/// Csak a bejelölt alkalmazások jelenhetnek meg a mélyreható hálózatelemzésben.
public struct ActiveServicesSheet: View {
    @ObservedObject var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedCategory: ContentCategory? = nil

    private var filteredServices: [ServiceDefinition] {
        ServiceCatalog.allServices.filter { service in
            let matchesCategory = (selectedCategory == nil) || (service.category == selectedCategory)
            let matchesSearch = searchText.isEmpty ||
                service.name.localizedCaseInsensitiveContains(searchText) ||
                service.description.localizedCaseInsensitiveContains(searchText) ||
                service.domains.contains { $0.localizedCaseInsensitiveContains(searchText) }
            return matchesCategory && matchesSearch
        }
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Fejléc információs kártya
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                        Text("Személyre szabott hálózatfigyelés")
                            .font(.headline)
                    }
                    Text("Jelöld be azokat az alkalmazásokat és oldalakat, amelyeket használsz ezen az iPhone-on. A DataScout kizárólag a bejelölt szolgáltatásokhoz rendel forgalmat, a kikapcsolt appok soha nem jelennek meg.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))

                // Kategóriaszűrő kapszulák
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterButton(title: "Összes (\(ServiceCatalog.allServices.count))", category: nil)

                        ForEach(ContentCategory.allCases, id: \.self) { cat in
                            let count = ServiceCatalog.allServices.filter { $0.category == cat }.count
                            if count > 0 {
                                filterButton(title: "\(cat.displayName) (\(count))", category: cat)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }

                Divider()

                // Szolgáltatások listája
                List {
                    Section {
                        ForEach(filteredServices) { service in
                            let isActive = vm.isServiceActive(id: service.id)
                            Button {
                                withAnimation(.spring(response: 0.25)) {
                                    vm.toggleActiveService(id: service.id)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: service.icon)
                                        .font(.system(size: 18))
                                        .foregroundColor(isActive ? .blue : .secondary)
                                        .frame(width: 32, height: 32)
                                        .background(isActive ? Color.blue.opacity(0.15) : Color.secondary.opacity(0.1))
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(service.name)
                                            .font(.subheadline.bold())
                                            .foregroundColor(.primary)

                                        Text(service.description)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(isActive ? .blue : .secondary.opacity(0.4))
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        HStack {
                            Text("\(filteredServices.count) szolgáltatás")
                            Spacer()
                            Text("\(vm.activeServiceIds.count) aktív")
                                .font(.caption.bold())
                                .foregroundColor(.blue)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .searchable(text: $searchText, prompt: "Keresés név vagy domain alapján...")
            }
            .navigationTitle("Saját Alkalmazásaim")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Menu {
                        Button("Összes bekapcsolása") {
                            vm.enableAllServices()
                        }
                        Button("Alapértelmezett visszaállítása") {
                            vm.resetServicesToDefault()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Kész") {
                        dismiss()
                    }
                    .font(.body.bold())
                }
            }
        }
    }

    private func filterButton(title: String, category: ContentCategory?) -> some View {
        Button {
            selectedCategory = category
        } label: {
            Text(title)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selectedCategory == category ? Color.blue : Color(uiColor: .tertiarySystemFill))
                .foregroundColor(selectedCategory == category ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
