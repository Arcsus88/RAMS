import SwiftUI

private enum LibraryTab: String, CaseIterable, Identifiable {
    case hazards = "Hazards"
    case masterDocuments = "Master Docs"
    case ramsDocuments = "RAMS Docs"
    case liftPlans = "Lift Plans"

    var id: String { rawValue }
}

struct LibrariesHomeView: View {
    @EnvironmentObject private var libraryViewModel: LibraryViewModel
    @State private var selectedTab: LibraryTab = .hazards
    @State private var showingAddHazardSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("Library Type", selection: $selectedTab) {
                    ForEach(LibraryTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Group {
                    switch selectedTab {
                    case .hazards:
                        hazardLibraryList
                    case .masterDocuments:
                        masterDocumentList
                    case .ramsDocuments:
                        ramsDocumentList
                    case .liftPlans:
                        liftPlanList
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Libraries")
            .toolbar {
                if selectedTab == .hazards {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingAddHazardSheet = true
                        } label: {
                            Label("New Hazard", systemImage: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddHazardSheet) {
                HazardTemplateEditorSheet { hazard in
                    libraryViewModel.saveHazardTemplate(hazard)
                }
            }
        }
    }

    private var hazardLibraryList: some View {
        List {
            if libraryViewModel.library.hazards.isEmpty {
                Text("No hazard templates yet.")
                    .foregroundStyle(.secondary)
            }

            ForEach(libraryViewModel.library.hazards) { hazard in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(hazard.title)
                            .font(.headline)
                        Spacer()
                        Text(hazard.category)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    Text("Risk to: \(hazard.riskToDefault)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if !hazard.controlMeasuresDefault.isEmpty {
                        Text(hazard.controlMeasuresDefault.joined(separator: " • "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    let residual = hazard.defaultResidualLikelihood * hazard.defaultResidualSeverity
                    HStack {
                        Text("Initial: \(hazard.defaultInitialLikelihood * hazard.defaultInitialSeverity)")
                            .font(.caption2)
                        Text("Residual: \(residual)")
                            .font(.caption2)
                        Spacer()
                        RiskReviewBadge(review: RiskScoreMatrix.review(for: residual))
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.insetGrouped)
    }

    private var masterDocumentList: some View {
        List {
            if libraryViewModel.library.masterDocuments.isEmpty {
                Text("No master documents saved.")
                    .foregroundStyle(.secondary)
            }

            ForEach(libraryViewModel.library.masterDocuments) { master in
                VStack(alignment: .leading, spacing: 6) {
                    Text(master.projectName.ifEmpty("Untitled project"))
                        .font(.headline)
                    Text(master.siteAddress.ifEmpty("No site address"))
                        .font(.subheadline)
                    Text("Hospital: \(master.nearestHospitalName.ifEmpty("-"))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Updated: \(DateFormatter.shortDateTime.string(from: master.updatedAt))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.insetGrouped)
    }

    private var ramsDocumentList: some View {
        List {
            if libraryViewModel.library.ramsDocuments.isEmpty {
                Text("No RAMS documents saved.")
                    .foregroundStyle(.secondary)
            }

            ForEach(libraryViewModel.library.ramsDocuments) { rams in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(rams.title.ifEmpty("Untitled RAMS"))
                            .font(.headline)
                        Spacer()
                        RiskReviewBadge(review: rams.overallRiskReview)
                    }
                    Text(rams.referenceCode.ifEmpty("-"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Hazards: \(rams.riskAssessments.count) • Method steps: \(rams.methodStatements.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("PPE items: \(rams.requiredPPE.count) • Assembly: \(rams.emergencyAssemblyPoint.ifEmpty("-"))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Signatures: \(rams.signatureTable.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.insetGrouped)
    }

    private var liftPlanList: some View {
        List {
            if libraryViewModel.library.liftPlans.isEmpty {
                Text("No lift plans saved.")
                    .foregroundStyle(.secondary)
            }

            ForEach(libraryViewModel.library.liftPlans) { liftPlan in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(liftPlan.title.ifEmpty("Untitled lift plan"))
                            .font(.headline)
                        Spacer()
                        Text(liftPlan.category.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    Text("Plant: \(liftPlan.craneOrPlant.ifEmpty("-"))")
                        .font(.subheadline)
                    Text("Load: \(liftPlan.loadDescription.ifEmpty("-"))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Weight: \(liftPlan.loadWeightKg, specifier: "%.1f") kg • Radius: \(liftPlan.liftRadiusMeters, specifier: "%.1f") m")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.insetGrouped)
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : self
    }
}
