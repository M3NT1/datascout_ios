import SwiftUI

/// A mélyreható hálózati forgalom-, domain- és reklámelemző felület.
/// Teljes transzparenciával különíti el a hardveres mérést a heurisztikus becslésektől.
public struct DeepInspectorView: View {
    @ObservedObject var vm: AppViewModel
    @State private var selectedCategoryFilter: ContentCategory? = nil

    private var filteredRecords: [DomainTrafficRecord] {
        if let cat = selectedCategoryFilter {
            return vm.domainRecords.filter { $0.category == cat }
        }
        return vm.domainRecords
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 0. Élő hardveres státusz jelző
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Élő hardveres forgalomelemzés • Darwin kernel 64-bit aktív")
                            .font(.caption2.bold())
                            .foregroundColor(.green)
                        Spacer()
                    }
                    .padding(.horizontal)

                    // 1. Élő Adatfolyam és Részecske-áramlás Hálózat
                    LiveTrafficStreamView(vm: vm)

                    // 2. Transzparencia & Adatvédelmi Nyilatkozat
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "hand.raised.shield.fill")
                                .foregroundColor(.blue)
                            Text("Hálózati Transzparencia & Módszertan")
                                .font(.subheadline.bold())
                        }
                        Text("Az Apple iOS adatvédelmi Sandbox védelme miatt egyetlen app sem olvashatja más appok belső folyamatait. A DataScout a Darwin kernelből 100%-os hardveres bájt-pontossággal mér, az élő nézetben pedig az univerzális iOS rendszer- és webes kiszolgálók (Apple CDN, WebKit, iCloud, DNS) forgalmi megoszlása látható.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(14)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    // 2. Reklám- és Követőforgalom Elemzés (Ad & Tracker Analytics)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "shield.slash.fill")
                                .foregroundColor(.red)
                            Text("Reklámok & Követők Elemzése")
                                .font(.headline)
                        }

                        HStack(spacing: 16) {
                            adKpi(
                                title: "Reklámkérések aránya",
                                value: String(format: "%.1f%%", vm.adTrackerStats.adTrackerRatio * 100.0),
                                subtitle: "\(vm.adTrackerStats.adTrackerRequests) / \(vm.adTrackerStats.totalRequests) kérés",
                                color: .red
                            )

                            adKpi(
                                title: "Becsült reklámforgalom",
                                value: ByteFormatter.format(vm.adTrackerStats.estimatedAdBytes),
                                subtitle: "Társított hálózati adat",
                                color: .orange
                            )
                        }

                        Text(vm.adTrackerStats.explanation)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    .padding(16)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)

                    // 3. Tartalomtípusok Megoszlása (Kategóriaszűrő)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tartalomtípusok megoszlása")
                            .font(.headline)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                Button {
                                    selectedCategoryFilter = nil
                                } label: {
                                    Text("Összes")
                                        .font(.caption.bold())
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(selectedCategoryFilter == nil ? Color.blue : Color(uiColor: .secondarySystemBackground))
                                        .foregroundColor(selectedCategoryFilter == nil ? .white : .primary)
                                        .clipShape(Capsule())
                                }

                                ForEach(ContentCategory.allCases, id: \.self) { cat in
                                    Button {
                                        selectedCategoryFilter = cat
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: cat.iconName)
                                            Text(cat.displayName)
                                        }
                                        .font(.caption.bold())
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(selectedCategoryFilter == cat ? Color.blue : Color(uiColor: .secondarySystemBackground))
                                        .foregroundColor(selectedCategoryFilter == cat ? .white : .primary)
                                        .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // 4. Azonosított Domainek & Szolgáltatások Listája
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Top célállomások és szolgáltatások")
                                .font(.headline)
                            Spacer()
                            Text("\(filteredRecords.count) tétel")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)

                        if filteredRecords.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "waveform.path.ecg")
                                    .font(.system(size: 32))
                                    .foregroundColor(.secondary)
                                Text("Nincs megjeleníthető forgalmi tétel")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(24)
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(filteredRecords) { rec in
                                    domainRow(rec)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 80)

                }
                .padding(.top, 10)
            }
            .navigationTitle("Forgalom & Domainek")
        }
    }

    private func adKpi(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2.bold())
                .foregroundColor(color)
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func domainRow(_ rec: DomainTrafficRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: rec.category.iconName)
                    .foregroundColor(rec.isAdOrTracker ? .red : .blue)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(rec.serviceName)
                        .font(.subheadline.bold())
                    Text(rec.domain)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(ByteFormatter.format(rec.estimatedBytes))
                        .font(.subheadline.bold())
                    Text("\(rec.requestCount) kérés")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                Text(rec.confidence.badgeText)
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .foregroundColor(.secondary)
                    .clipShape(Capsule())

                if rec.isAdOrTracker {
                    Text("REKLÁM / KÖVETŐ")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .clipShape(Capsule())
                }
                Spacer()
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
