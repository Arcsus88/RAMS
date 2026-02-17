import Foundation
import Combine

@MainActor
final class SessionViewModel: ObservableObject {
    @Published private(set) var currentUser: AuthUser?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authService: AuthServiceProviding

    init(authService: AuthServiceProviding) {
        self.authService = authService
    }

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            currentUser = try await authService.login(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logout() {
        authService.logout()
        currentUser = nil
    }
}

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published private(set) var library: LibraryBundle = .seeded
    @Published var errorMessage: String?
    @Published private(set) var hasLoaded = false

    private let store: LibraryStore

    init(store: LibraryStore) {
        self.store = store
    }

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        loadLibrary()
    }

    func loadLibrary() {
        do {
            library = try store.loadLibrary()
            if library.hazards.isEmpty {
                library.hazards = LibraryBundle.seeded.hazards
            }
            try store.saveLibrary(library)
            hasLoaded = true
        } catch {
            errorMessage = "Failed to load local libraries: \(error.localizedDescription)"
            library = .seeded
            hasLoaded = true
        }
    }

    func saveHazardTemplate(_ hazard: HazardTemplate) {
        upsert(hazard, in: &library.hazards)
        persist()
    }

    func saveMasterDocument(_ master: MasterDocument) {
        upsert(master, in: &library.masterDocuments)
        persist()
    }

    func saveRamsDocument(_ rams: RamsDocument) {
        upsert(rams, in: &library.ramsDocuments)
        persist()
    }

    func saveLiftPlan(_ liftPlan: LiftPlan) {
        upsert(liftPlan, in: &library.liftPlans)
        persist()
    }

    func saveClient(_ client: ClientRecord) {
        upsert(client, in: &library.clients)
        persist()
    }

    func saveProject(_ project: ProjectRecord) {
        upsert(project, in: &library.projects)
        persist()
    }

    func deleteClient(id: UUID) {
        guard let clientIndex = library.clients.firstIndex(where: { $0.id == id }) else { return }
        library.clients.remove(at: clientIndex)

        for index in library.projects.indices where library.projects[index].clientID == id {
            library.projects[index].clientID = nil
            library.projects[index].updatedAt = Date()
        }

        for index in library.masterDocuments.indices where library.masterDocuments[index].clientID == id {
            library.masterDocuments[index].clientID = nil
        }

        persist()
    }

    func deleteProject(id: UUID) {
        guard let projectIndex = library.projects.firstIndex(where: { $0.id == id }) else { return }
        library.projects.remove(at: projectIndex)

        for index in library.masterDocuments.indices where library.masterDocuments[index].projectID == id {
            library.masterDocuments[index].projectID = nil
        }

        persist()
    }

    private func persist() {
        do {
            try store.saveLibrary(library)
        } catch {
            errorMessage = "Failed to save local libraries: \(error.localizedDescription)"
        }
    }

    private func upsert<T: Identifiable>(_ element: T, in array: inout [T]) where T.ID: Equatable {
        if let existingIndex = array.firstIndex(where: { $0.id == element.id }) {
            array[existingIndex] = element
        } else {
            array.insert(element, at: 0)
        }
    }
}

enum WizardStep: String, CaseIterable, Identifiable {
    case masterDocument = "Project & Site Setup"
    case ramsDocument = "RAMS & Method Statement"
    case liftPlan = "Lift Plan"
    case review = "Review & Export"

    var id: String { rawValue }
}

@MainActor
final class WizardViewModel: ObservableObject {
    @Published var masterDocument: MasterDocument
    @Published var ramsDocument: RamsDocument
    @Published var liftPlan: LiftPlan
    @Published var includeLiftPlan = false
    @Published var currentStep: WizardStep = .masterDocument
    @Published var generatedPublicLink: PublicShareLink?
    @Published var exportedPDFURL: URL?
    @Published var statusMessage: String?
    @Published var errorMessage: String?
    @Published var isProcessing = false

    private let libraryViewModel: LibraryViewModel
    private let publicLinkService: PublicLinkService
    private let pdfExportService: PDFExportService

    init(
        libraryViewModel: LibraryViewModel,
        publicLinkService: PublicLinkService = PublicLinkService(),
        pdfExportService: PDFExportService = PDFExportService()
    ) {
        self.libraryViewModel = libraryViewModel
        self.publicLinkService = publicLinkService
        self.pdfExportService = pdfExportService

        self.masterDocument = MasterDocument.draft()
        self.ramsDocument = RamsDocument.draft()
        self.liftPlan = LiftPlan.draft()
        self.ramsDocument.referenceCode = Self.makeReferenceCode()
    }

    var orderedSteps: [WizardStep] {
        includeLiftPlan
            ? [.masterDocument, .ramsDocument, .liftPlan, .review]
            : [.masterDocument, .ramsDocument, .review]
    }

    var stepIndex: Int {
        orderedSteps.firstIndex(of: currentStep) ?? 0
    }

    var progressValue: Double {
        guard orderedSteps.count > 1 else { return 0 }
        return Double(stepIndex) / Double(orderedSteps.count - 1)
    }

    var availableClients: [ClientRecord] {
        libraryViewModel.library.clients.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var availableProjects: [ProjectRecord] {
        libraryViewModel.library.projects.sorted {
            $0.updatedAt > $1.updatedAt
        }
    }

    var availableProjectsForSelectedClient: [ProjectRecord] {
        guard let clientID = masterDocument.clientID else { return [] }
        return availableProjects.filter { $0.clientID == clientID }
    }

    var selectedClient: ClientRecord? {
        guard let clientID = masterDocument.clientID else { return nil }
        return libraryViewModel.library.clients.first(where: { $0.id == clientID })
    }

    var selectedProject: ProjectRecord? {
        guard let projectID = masterDocument.projectID else { return nil }
        return libraryViewModel.library.projects.first(where: { $0.id == projectID })
    }

    var canGoBack: Bool {
        stepIndex > 0
    }

    var isFinalStep: Bool {
        currentStep == orderedSteps.last
    }

    func goBack() {
        errorMessage = nil
        guard stepIndex > 0 else {
            return
        }
        currentStep = orderedSteps[stepIndex - 1]
    }

    func goNext() {
        errorMessage = nil
        guard validateCurrentStep() else { return }

        if currentStep == .masterDocument {
            ensureProjectContextForWizard()
        }

        guard stepIndex + 1 < orderedSteps.count else {
            return
        }
        currentStep = orderedSteps[stepIndex + 1]
    }

    func addMethodStatement() {
        let nextSequence = (ramsDocument.methodStatements.map(\.sequence).max() ?? 0) + 1
        ramsDocument.methodStatements.append(MethodStatementStep(sequence: nextSequence, title: "", details: ""))
    }

    func removeMethodStatements(at offsets: IndexSet) {
        ramsDocument.methodStatements.remove(atOffsets: offsets)
        for index in ramsDocument.methodStatements.indices {
            ramsDocument.methodStatements[index].sequence = index + 1
        }
    }

    func addRisk(from template: HazardTemplate) {
        ramsDocument.riskAssessments.append(template.makeAssessment())
    }

    func addRisks(from templates: [HazardTemplate]) {
        ramsDocument.riskAssessments.append(contentsOf: templates.map { $0.makeAssessment() })
    }

    func addBlankRisk() {
        ramsDocument.riskAssessments.append(RiskAssessment())
    }

    func populatePreparedByIfNeeded(with userName: String) {
        let cleanUserName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUserName.isEmpty else { return }
        guard ramsDocument.preparedBy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        ramsDocument.preparedBy = cleanUserName
    }

    func quickAddApprovedByForSamePerson(loggedInUserName: String) {
        let preparedBy = ramsDocument.preparedBy.trimmingCharacters(in: .whitespacesAndNewlines)
        if !preparedBy.isEmpty {
            ramsDocument.approvedBy = preparedBy
            return
        }

        let cleanUserName = loggedInUserName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUserName.isEmpty else { return }
        ramsDocument.preparedBy = cleanUserName
        ramsDocument.approvedBy = cleanUserName
    }

    func removeRisks(at offsets: IndexSet) {
        ramsDocument.riskAssessments.remove(atOffsets: offsets)
    }

    func togglePPE(_ item: PPEItemID) {
        if ramsDocument.requiredPPE.contains(item) {
            ramsDocument.requiredPPE.removeAll(where: { $0 == item })
        } else {
            ramsDocument.requiredPPE.append(item)
        }
    }

    func addSignature(name: String, role: String, signatureImageData: Data) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanRole = role.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, !cleanRole.isEmpty else {
            errorMessage = "Signer name and role are required."
            return
        }
        let record = SignatureRecord(
            signerName: cleanName,
            signerRole: cleanRole,
            signatureImageData: signatureImageData
        )
        ramsDocument.signatureTable.append(record)
    }

    func selectClient(id: UUID?) {
        errorMessage = nil
        masterDocument.clientID = id
        if let id, let client = libraryViewModel.library.clients.first(where: { $0.id == id }) {
            masterDocument.clientName = client.name
        } else if id == nil {
            masterDocument.clientName = ""
            masterDocument.projectID = nil
        }

        if let selectedProjectID = masterDocument.projectID,
           let selectedProject = libraryViewModel.library.projects.first(where: { $0.id == selectedProjectID }),
           let projectClientID = selectedProject.clientID,
           let selectedClientID = id,
           projectClientID != selectedClientID {
            masterDocument.projectID = nil
        }
    }

    func selectProject(id: UUID?) {
        errorMessage = nil
        masterDocument.projectID = id
        guard let id,
              let project = libraryViewModel.library.projects.first(where: { $0.id == id }) else {
            return
        }

        masterDocument.projectName = project.name
        masterDocument.siteAddress = project.siteAddress
        if !project.principalContractor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            masterDocument.principalContractor = project.principalContractor
        }
        if !project.emergencyContactName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            masterDocument.emergencyContactName = project.emergencyContactName
        }
        if !project.emergencyContactPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            masterDocument.emergencyContactPhone = project.emergencyContactPhone
        }
        if !project.nearestHospitalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            masterDocument.nearestHospitalName = project.nearestHospitalName
        }
        if !project.nearestHospitalAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            masterDocument.nearestHospitalAddress = project.nearestHospitalAddress
        }
        if !project.hospitalDirections.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            masterDocument.hospitalDirections = project.hospitalDirections
        }
        masterDocument.keyContacts = project.keyContacts.isEmpty ? [KeyContact(name: "", role: "", phone: "")] : project.keyContacts
        masterDocument.mapImageData = project.mapImageData

        if !project.referenceCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ramsDocument.referenceCode = project.referenceCode
        }

        if let linkedClientID = project.clientID {
            masterDocument.clientID = linkedClientID
            if let client = libraryViewModel.library.clients.first(where: { $0.id == linkedClientID }) {
                masterDocument.clientName = client.name
            }
        }
    }

    @discardableResult
    func createClient(
        name: String,
        contactName: String,
        contactEmail: String,
        contactPhone: String
    ) -> Bool {
        errorMessage = nil
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            errorMessage = "Client name is required."
            return false
        }

        let now = Date()
        if let existing = libraryViewModel.library.clients.first(where: {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveCompare(cleanName) == .orderedSame
        }) {
            let updated = ClientRecord(
                id: existing.id,
                name: cleanName,
                contactName: contactName.trimmingCharacters(in: .whitespacesAndNewlines),
                contactEmail: contactEmail.trimmingCharacters(in: .whitespacesAndNewlines),
                contactPhone: contactPhone.trimmingCharacters(in: .whitespacesAndNewlines),
                createdAt: existing.createdAt,
                updatedAt: now
            )
            libraryViewModel.saveClient(updated)
            selectClient(id: updated.id)
            statusMessage = "Client updated and selected."
            return true
        }

        let newClient = ClientRecord(
            name: cleanName,
            contactName: contactName.trimmingCharacters(in: .whitespacesAndNewlines),
            contactEmail: contactEmail.trimmingCharacters(in: .whitespacesAndNewlines),
            contactPhone: contactPhone.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: now,
            updatedAt: now
        )
        libraryViewModel.saveClient(newClient)
        selectClient(id: newClient.id)
        statusMessage = "Client saved and selected."
        return true
    }

    @discardableResult
    func createProject(
        projectID: UUID? = nil,
        projectCreatedAt: Date? = nil,
        name: String,
        siteAddress: String,
        principalContractor: String,
        referenceCode: String,
        emergencyContactName: String,
        emergencyContactPhone: String,
        nearestHospitalName: String,
        nearestHospitalAddress: String,
        hospitalDirections: String,
        keyContacts: [KeyContact],
        mapImageData: Data?,
        clientID: UUID?
    ) -> Bool {
        errorMessage = nil
        guard let clientID else {
            errorMessage = "Select a client before creating a project."
            return false
        }

        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            errorMessage = "Project name is required."
            return false
        }

        let now = Date()
        let newProject = ProjectRecord(
            id: projectID ?? UUID(),
            clientID: clientID,
            name: cleanName,
            siteAddress: siteAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            principalContractor: principalContractor.trimmingCharacters(in: .whitespacesAndNewlines),
            referenceCode: referenceCode.trimmingCharacters(in: .whitespacesAndNewlines),
            emergencyContactName: emergencyContactName.trimmingCharacters(in: .whitespacesAndNewlines),
            emergencyContactPhone: emergencyContactPhone.trimmingCharacters(in: .whitespacesAndNewlines),
            nearestHospitalName: nearestHospitalName.trimmingCharacters(in: .whitespacesAndNewlines),
            nearestHospitalAddress: nearestHospitalAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            hospitalDirections: hospitalDirections.trimmingCharacters(in: .whitespacesAndNewlines),
            keyContacts: normalizedKeyContacts(keyContacts),
            mapImageData: mapImageData,
            createdAt: projectCreatedAt ?? now,
            updatedAt: now
        )
        libraryViewModel.saveProject(newProject)
        selectProject(id: newProject.id)
        statusMessage = projectID == nil ? "Project saved and selected." : "Project updated."
        return true
    }

    func saveToLibraries() {
        isProcessing = true
        defer { isProcessing = false }
        errorMessage = nil
        statusMessage = nil

        let now = Date()

        masterDocument.updatedAt = now
        if masterDocument.createdAt > now {
            masterDocument.createdAt = now
        }
        libraryViewModel.saveMasterDocument(masterDocument)

        ramsDocument.updatedAt = now
        ramsDocument.requiresLiftingPlan = includeLiftPlan
        libraryViewModel.saveRamsDocument(ramsDocument)

        if includeLiftPlan {
            liftPlan.updatedAt = now
            liftPlan.ramsDocumentID = ramsDocument.id
            libraryViewModel.saveLiftPlan(liftPlan)
        }

        statusMessage = "Saved to local libraries."
    }

    func generatePublicLink() {
        generatedPublicLink = publicLinkService.generatePublicLink(for: ramsDocument)
        statusMessage = "Generated local placeholder public link."
    }

    func exportPDF() {
        isProcessing = true
        defer { isProcessing = false }

        do {
            exportedPDFURL = try pdfExportService.exportPDF(
                master: masterDocument,
                rams: ramsDocument,
                liftPlan: includeLiftPlan ? liftPlan : nil,
                signatures: ramsDocument.signatureTable
            )
            statusMessage = "PDF exported with paginated A4 layout."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startNewWizard() {
        masterDocument = .draft()
        ramsDocument = .draft()
        ramsDocument.referenceCode = Self.makeReferenceCode()
        liftPlan = .draft()
        includeLiftPlan = false
        currentStep = .masterDocument
        generatedPublicLink = nil
        exportedPDFURL = nil
        statusMessage = nil
        errorMessage = nil
    }

    private func validateCurrentStep() -> Bool {
        switch currentStep {
        case .masterDocument:
            guard masterDocument.clientID != nil else {
                errorMessage = "Select or create a client first."
                return false
            }
            guard masterDocument.projectID != nil else {
                errorMessage = "Select or create a project first."
                return false
            }
            let required = [
                masterDocument.projectName,
                masterDocument.siteAddress,
                masterDocument.emergencyContactName,
                masterDocument.emergencyContactPhone,
                masterDocument.nearestHospitalName,
                masterDocument.nearestHospitalAddress,
                masterDocument.hospitalDirections
            ]
            if required.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                errorMessage = "Complete all project, emergency, and hospital fields before continuing."
                return false
            }
            if masterDocument.mapImageData == nil {
                errorMessage = "Add a project map image before continuing."
                return false
            }
            if normalizedKeyContacts(masterDocument.keyContacts).isEmpty {
                errorMessage = "Add at least one key contact before continuing."
                return false
            }
        case .ramsDocument:
            let required = [
                ramsDocument.title,
                ramsDocument.scopeOfWorks,
                ramsDocument.preparedBy
            ]
            if required.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                errorMessage = "RAMS title, scope, and prepared by are required."
                return false
            }
            if ramsDocument.riskAssessments.isEmpty {
                errorMessage = "Add at least one hazard/risk assessment."
                return false
            }
            let emergencyRequired = [
                ramsDocument.emergencyFirstAidStation,
                ramsDocument.emergencyAssemblyPoint
            ]
            if emergencyRequired.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                errorMessage = "Add first aid station and assembly point in Emergency Procedures."
                return false
            }
        case .liftPlan:
            if includeLiftPlan {
                let required = [
                    liftPlan.title,
                    liftPlan.craneOrPlant,
                    liftPlan.loadDescription,
                    liftPlan.appointedPerson
                ]
                if required.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                    errorMessage = "Lift plan details are incomplete."
                    return false
                }
            }
        case .review:
            break
        }

        return true
    }

    private static func makeReferenceCode() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return "RAMS-\(formatter.string(from: Date()))"
    }

    private func ensureProjectContextForWizard() {
        guard let projectID = masterDocument.projectID else { return }
        let now = Date()
        guard let existingProject = libraryViewModel.library.projects.first(where: { $0.id == projectID }) else { return }

        let project = ProjectRecord(
            id: existingProject.id,
            clientID: masterDocument.clientID,
            name: masterDocument.projectName.trimmingCharacters(in: .whitespacesAndNewlines),
            siteAddress: masterDocument.siteAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            principalContractor: masterDocument.principalContractor.trimmingCharacters(in: .whitespacesAndNewlines),
            referenceCode: ramsDocument.referenceCode.trimmingCharacters(in: .whitespacesAndNewlines),
            emergencyContactName: masterDocument.emergencyContactName.trimmingCharacters(in: .whitespacesAndNewlines),
            emergencyContactPhone: masterDocument.emergencyContactPhone.trimmingCharacters(in: .whitespacesAndNewlines),
            nearestHospitalName: masterDocument.nearestHospitalName.trimmingCharacters(in: .whitespacesAndNewlines),
            nearestHospitalAddress: masterDocument.nearestHospitalAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            hospitalDirections: masterDocument.hospitalDirections.trimmingCharacters(in: .whitespacesAndNewlines),
            keyContacts: normalizedKeyContacts(masterDocument.keyContacts),
            mapImageData: masterDocument.mapImageData,
            createdAt: existingProject.createdAt,
            updatedAt: now
        )

        libraryViewModel.saveProject(project)
        masterDocument.projectID = project.id
    }

    private func normalizedKeyContacts(_ contacts: [KeyContact]) -> [KeyContact] {
        contacts.filter { contact in
            !contact.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !contact.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}
