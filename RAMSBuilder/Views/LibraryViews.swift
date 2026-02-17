import SwiftUI

private enum LibraryTab: String, CaseIterable, Identifiable {
    case hazards = "Hazards"
    case clients = "Clients"
    case projects = "Projects"
    case masterDocuments = "Master Docs"
    case ramsDocuments = "RAMS Docs"
    case liftPlans = "Lift Plans"

    var id: String { rawValue }
}

struct LibrariesHomeView: View {
    @EnvironmentObject private var libraryViewModel: LibraryViewModel
    @State private var selectedTab: LibraryTab = .hazards
    @State private var activeSheet: ActiveLibrarySheet?
    @State private var searchText = ""

    private enum ActiveLibrarySheet: Identifiable {
        case newHazard
        case newClient
        case editClient(ClientRecord)
        case newProject
        case editProject(ProjectRecord)

        var id: String {
            switch self {
            case .newHazard:
                return "newHazard"
            case .newClient:
                return "newClient"
            case .editClient(let client):
                return "editClient-\(client.id.uuidString)"
            case .newProject:
                return "newProject"
            case .editProject(let project):
                return "editProject-\(project.id.uuidString)"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                tabPicker
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Libraries")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search \(selectedTab.rawValue)"
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    addButton
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .newHazard:
                    HazardTemplateEditorSheet { hazard in
                        libraryViewModel.saveHazardTemplate(hazard)
                    }
                case .newClient:
                    LibraryClientEditorSheet(existing: nil) { client in
                        libraryViewModel.saveClient(client)
                    }
                case .editClient(let client):
                    LibraryClientEditorSheet(existing: client) { updated in
                        libraryViewModel.saveClient(updated)
                    }
                case .newProject:
                    LibraryProjectEditorSheet(
                        existing: nil,
                        clients: sortedClients
                    ) { project in
                        libraryViewModel.saveProject(project)
                    }
                case .editProject(let project):
                    LibraryProjectEditorSheet(
                        existing: project,
                        clients: sortedClients
                    ) { updated in
                        libraryViewModel.saveProject(updated)
                    }
                }
            }
        }
    }

    private var tabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LibraryTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Text(tab.rawValue)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedTab == tab ? Color.proYellow : Color.secondary.opacity(0.12))
                            .foregroundStyle(selectedTab == tab ? Color.proSlate900 : Color.primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .hazards:
            hazardLibraryList
        case .clients:
            clientLibraryList
        case .projects:
            projectLibraryList
        case .masterDocuments:
            masterDocumentList
        case .ramsDocuments:
            ramsDocumentList
        case .liftPlans:
            liftPlanList
        }
    }

    private var addButton: some View {
        Button {
            switch selectedTab {
            case .hazards:
                activeSheet = .newHazard
            case .clients:
                activeSheet = .newClient
            case .projects:
                activeSheet = .newProject
            case .masterDocuments, .ramsDocuments, .liftPlans:
                break
            }
        } label: {
            Label(addButtonTitle, systemImage: "plus")
        }
        .disabled(!canAddInSelectedTab)
    }

    private var addButtonTitle: String {
        switch selectedTab {
        case .hazards:
            return "New Hazard"
        case .clients:
            return "New Client"
        case .projects:
            return "New Project"
        case .masterDocuments, .ramsDocuments, .liftPlans:
            return "Add"
        }
    }

    private var canAddInSelectedTab: Bool {
        switch selectedTab {
        case .hazards, .clients, .projects:
            return true
        case .masterDocuments, .ramsDocuments, .liftPlans:
            return false
        }
    }

    private var sortedClients: [ClientRecord] {
        libraryViewModel.library.clients.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var filteredClients: [ClientRecord] {
        sortedClients.filter { client in
            matchesSearch([
                client.name,
                client.contactName,
                client.contactEmail,
                client.contactPhone
            ])
        }
    }

    private var sortedProjects: [ProjectRecord] {
        libraryViewModel.library.projects.sorted {
            $0.updatedAt > $1.updatedAt
        }
    }

    private var filteredProjects: [ProjectRecord] {
        sortedProjects.filter { project in
            matchesSearch([
                project.name,
                project.siteAddress,
                project.principalContractor,
                project.referenceCode,
                projectClientName(project).ifEmpty("Unassigned")
            ])
        }
    }

    private func matchesSearch(_ fields: [String]) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return fields.joined(separator: " ").localizedCaseInsensitiveContains(query)
    }

    private func projectClientName(_ project: ProjectRecord) -> String {
        guard let clientID = project.clientID,
              let client = libraryViewModel.library.clients.first(where: { $0.id == clientID }) else {
            return ""
        }
        return client.name
    }

    private func deleteClients(at offsets: IndexSet) {
        let ids = offsets.map { filteredClients[$0].id }
        ids.forEach { libraryViewModel.deleteClient(id: $0) }
    }

    private func deleteProjects(at offsets: IndexSet) {
        let ids = offsets.map { filteredProjects[$0].id }
        ids.forEach { libraryViewModel.deleteProject(id: $0) }
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

    private var clientLibraryList: some View {
        List {
            if filteredClients.isEmpty {
                Text(searchText.isEmpty ? "No clients saved." : "No clients found.")
                    .foregroundStyle(.secondary)
            }

            ForEach(filteredClients) { client in
                Button {
                    activeSheet = .editClient(client)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(client.name.ifEmpty("Unnamed client"))
                                .font(.headline)
                            Spacer()
                            let linkedProjects = libraryViewModel.library.projects.filter { $0.clientID == client.id }.count
                            Text("\(linkedProjects) projects")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        if !client.contactName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Contact: \(client.contactName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        let hasEmail = !client.contactEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        let hasPhone = !client.contactPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        if hasEmail || hasPhone {
                            Text(
                                [hasEmail ? client.contactEmail : nil, hasPhone ? client.contactPhone : nil]
                                    .compactMap { $0 }
                                    .joined(separator: " • ")
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        libraryViewModel.deleteClient(id: client.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }

                    Button {
                        activeSheet = .editClient(client)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.orange)
                }
            }
            .onDelete(perform: deleteClients)
        }
        .listStyle(.insetGrouped)
    }

    private var projectLibraryList: some View {
        List {
            if filteredProjects.isEmpty {
                Text(searchText.isEmpty ? "No projects saved." : "No projects found.")
                    .foregroundStyle(.secondary)
            }

            ForEach(filteredProjects) { project in
                Button {
                    activeSheet = .editProject(project)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(project.name.ifEmpty("Untitled project"))
                                .font(.headline)
                            Spacer()
                            Text(projectClientName(project).ifEmpty("Unassigned"))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        Text(project.siteAddress.ifEmpty("No site address"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack {
                            Text("Principal contractor: \(project.principalContractor.ifEmpty("-"))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Ref: \(project.referenceCode.ifEmpty("-"))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        libraryViewModel.deleteProject(id: project.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }

                    Button {
                        activeSheet = .editProject(project)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.orange)
                }
            }
            .onDelete(perform: deleteProjects)
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
                    Text("Client: \(master.clientName.ifEmpty("-"))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Hospital: \(master.nearestHospitalName.ifEmpty("-"))")
                        .font(.caption2)
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

private struct LibraryClientEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var contactName = ""
    @State private var contactEmail = ""
    @State private var contactPhone = ""

    let existing: ClientRecord?
    let onSave: (ClientRecord) -> Void

    init(existing: ClientRecord?, onSave: @escaping (ClientRecord) -> Void) {
        self.existing = existing
        self.onSave = onSave
        _name = State(initialValue: existing?.name ?? "")
        _contactName = State(initialValue: existing?.contactName ?? "")
        _contactEmail = State(initialValue: existing?.contactEmail ?? "")
        _contactPhone = State(initialValue: existing?.contactPhone ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Client details") {
                    TextField("Client name", text: $name)
                    TextField("Contact name", text: $contactName)
                    TextField("Contact email", text: $contactEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                    TextField("Contact phone", text: $contactPhone)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle(existing == nil ? "New Client" : "Edit Client")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let now = Date()
                        let record = ClientRecord(
                            id: existing?.id ?? UUID(),
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            contactName: contactName.trimmingCharacters(in: .whitespacesAndNewlines),
                            contactEmail: contactEmail.trimmingCharacters(in: .whitespacesAndNewlines),
                            contactPhone: contactPhone.trimmingCharacters(in: .whitespacesAndNewlines),
                            createdAt: existing?.createdAt ?? now,
                            updatedAt: now
                        )
                        onSave(record)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct LibraryProjectEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedClientID: UUID?
    @State private var name = ""
    @State private var siteAddress = ""
    @State private var principalContractor = ""
    @State private var referenceCode = ""

    let existing: ProjectRecord?
    let clients: [ClientRecord]
    let onSave: (ProjectRecord) -> Void

    init(
        existing: ProjectRecord?,
        clients: [ClientRecord],
        onSave: @escaping (ProjectRecord) -> Void
    ) {
        self.existing = existing
        self.clients = clients
        self.onSave = onSave
        _selectedClientID = State(initialValue: existing?.clientID)
        _name = State(initialValue: existing?.name ?? "")
        _siteAddress = State(initialValue: existing?.siteAddress ?? "")
        _principalContractor = State(initialValue: existing?.principalContractor ?? "")
        _referenceCode = State(initialValue: existing?.referenceCode ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Project details") {
                    Picker("Client", selection: $selectedClientID) {
                        Text("Unassigned").tag(nil as UUID?)
                        ForEach(clients) { client in
                            Text(client.name).tag(client.id as UUID?)
                        }
                    }

                    TextField("Project name", text: $name)
                    TextField("Site address", text: $siteAddress, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Principal contractor", text: $principalContractor)
                    TextField("Reference code", text: $referenceCode)
                }
            }
            .navigationTitle(existing == nil ? "New Project" : "Edit Project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let now = Date()
                        let project = ProjectRecord(
                            id: existing?.id ?? UUID(),
                            clientID: selectedClientID,
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            siteAddress: siteAddress.trimmingCharacters(in: .whitespacesAndNewlines),
                            principalContractor: principalContractor.trimmingCharacters(in: .whitespacesAndNewlines),
                            referenceCode: referenceCode.trimmingCharacters(in: .whitespacesAndNewlines),
                            emergencyContactName: existing?.emergencyContactName ?? "",
                            emergencyContactPhone: existing?.emergencyContactPhone ?? "",
                            nearestHospitalName: existing?.nearestHospitalName ?? "",
                            nearestHospitalAddress: existing?.nearestHospitalAddress ?? "",
                            hospitalDirections: existing?.hospitalDirections ?? "",
                            keyContacts: existing?.keyContacts ?? [],
                            mapImageData: existing?.mapImageData,
                            createdAt: existing?.createdAt ?? now,
                            updatedAt: now
                        )
                        onSave(project)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : self
    }
}
