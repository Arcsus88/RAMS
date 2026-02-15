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

    func register(
        firstName: String,
        lastName: String,
        email: String,
        password: String,
        confirmPassword: String
    ) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard password == confirmPassword else {
            errorMessage = "Password and confirm password must match."
            return
        }

        do {
            currentUser = try await authService.register(
                firstName: firstName,
                lastName: lastName,
                email: email,
                password: password
            )
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

    func saveProject(_ project: SavedProject) {
        upsert(project, in: &library.projects)
        persist()
    }

    func saveContact(_ contact: SavedContact) {
        let trimmedName = contact.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPhone = contact.phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedEmail = contact.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !trimmedName.isEmpty else { return }

        if let existingIndex = library.contacts.firstIndex(where: { existing in
            let existingName = existing.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
            let existingPhone = existing.phone.trimmingCharacters(in: .whitespacesAndNewlines)
            let existingEmail = existing.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return existingName.caseInsensitiveCompare(trimmedName) == .orderedSame
                && (existingPhone == trimmedPhone || (!normalizedEmail.isEmpty && existingEmail == normalizedEmail))
        }) {
            library.contacts[existingIndex] = contact
        } else {
            library.contacts.insert(contact, at: 0)
        }
        persist()
    }

    func saveContacts(_ contacts: [SavedContact]) {
        for contact in contacts {
            saveContact(contact)
        }
    }

    var contactNameOptions: [String] {
        deduplicatedNonEmpty(library.contacts.map(\.fullName))
    }

    var companyNameOptions: [String] {
        deduplicatedNonEmpty(library.projects.flatMap { [$0.clientName, $0.principalContractor] })
    }

    var projectNameOptions: [String] {
        deduplicatedNonEmpty(library.projects.map(\.name))
    }

    var contactRoleOptions: [String] {
        let defaults = [
            "Site Manager",
            "Project Manager",
            "Principal Contractor",
            "Client Representative",
            "Safety Officer",
            "Appointed Person",
            "Emergency Contact"
        ]
        return deduplicatedNonEmpty(defaults + library.contacts.map(\.role))
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

    private func deduplicatedNonEmpty(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for raw in values {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            if seen.insert(key).inserted {
                ordered.append(trimmed)
            }
        }
        return ordered
    }
}

enum WizardStep: String, CaseIterable, Identifiable {
    case masterDocument = "Master Document"
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
    private let userProvider: () -> AuthUser?

    init(
        libraryViewModel: LibraryViewModel,
        publicLinkService: PublicLinkService = PublicLinkService(),
        pdfExportService: PDFExportService = PDFExportService(),
        userProvider: @escaping () -> AuthUser? = { nil }
    ) {
        self.libraryViewModel = libraryViewModel
        self.publicLinkService = publicLinkService
        self.pdfExportService = pdfExportService
        self.userProvider = userProvider

        self.masterDocument = MasterDocument.draft()
        self.ramsDocument = RamsDocument.draft()
        self.liftPlan = LiftPlan.draft()
        self.ramsDocument.referenceCode = Self.makeReferenceCode()
        applyCurrentUserDefaults(force: true)
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

    func addBlankRisk() {
        ramsDocument.riskAssessments.append(RiskAssessment())
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

        let project = SavedProject(
            id: masterDocument.id,
            name: masterDocument.projectName.trimmingCharacters(in: .whitespacesAndNewlines),
            siteAddress: masterDocument.siteAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            clientName: masterDocument.clientName.trimmingCharacters(in: .whitespacesAndNewlines),
            principalContractor: masterDocument.principalContractor.trimmingCharacters(in: .whitespacesAndNewlines),
            referenceCode: ramsDocument.referenceCode.trimmingCharacters(in: .whitespacesAndNewlines),
            lastUpdatedAt: now
        )
        if !project.name.isEmpty {
            libraryViewModel.saveProject(project)
        }

        libraryViewModel.saveContacts(extractContacts(referenceDate: now))
        statusMessage = "Saved RAMS package, project profile, and contacts to local libraries."
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
        applyCurrentUserDefaults(force: true)
    }

    func applySavedProject(_ project: SavedProject) {
        masterDocument.projectName = project.name
        masterDocument.siteAddress = project.siteAddress
        masterDocument.clientName = project.clientName
        masterDocument.principalContractor = project.principalContractor
        if ramsDocument.referenceCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ramsDocument.referenceCode = project.referenceCode
        }
    }

    func applyCurrentUserDefaults(force: Bool = false) {
        guard let user = userProvider() else { return }
        let fullName = user.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fullName.isEmpty else { return }

        if force || masterDocument.emergencyContactName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            masterDocument.emergencyContactName = fullName
        }
        if masterDocument.keyContacts.isEmpty {
            masterDocument.keyContacts = [KeyContact()]
        }
        if force || masterDocument.keyContacts[0].name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            masterDocument.keyContacts[0].name = fullName
        }
        if force || masterDocument.keyContacts[0].role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            masterDocument.keyContacts[0].role = "Safety Officer"
        }

        if force || ramsDocument.preparedBy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ramsDocument.preparedBy = fullName
        }
        if force || ramsDocument.approvedBy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ramsDocument.approvedBy = fullName
        }
        if force || ramsDocument.emergencyContact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ramsDocument.emergencyContact = fullName
        }

        if force || liftPlan.appointedPerson.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            liftPlan.appointedPerson = fullName
        }
        if force || liftPlan.craneSupervisor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            liftPlan.craneSupervisor = fullName
        }
    }

    private func extractContacts(referenceDate: Date) -> [SavedContact] {
        var contacts: [SavedContact] = []

        for keyContact in masterDocument.keyContacts {
            let trimmedName = keyContact.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if let contact = makeContact(
                fullName: trimmedName,
                role: keyContact.role,
                phone: keyContact.phone,
                email: ""
            ) {
                contacts.append(contact.withDate(referenceDate))
            }
        }

        let automaticCandidates: [(name: String, role: String, phone: String, email: String)] = [
            (masterDocument.emergencyContactName, "Emergency Contact", masterDocument.emergencyContactPhone, ""),
            (ramsDocument.preparedBy, "Prepared By", "", userProvider()?.email ?? ""),
            (ramsDocument.approvedBy, "Approved By", "", ""),
            (liftPlan.appointedPerson, "Appointed Person", "", ""),
            (liftPlan.craneSupervisor, "Crane Supervisor", "", ""),
            (liftPlan.liftOperator, "Lift Operator", "", ""),
            (liftPlan.slingerSignaller, "Slinger / Signaller", "", "")
        ]

        for candidate in automaticCandidates {
            if let contact = makeContact(
                fullName: candidate.name,
                role: candidate.role,
                phone: candidate.phone,
                email: candidate.email
            ) {
                contacts.append(contact.withDate(referenceDate))
            }
        }

        return contacts
    }

    private func makeContact(fullName: String, role: String, phone: String, email: String) -> SavedContact? {
        let cleanName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return nil }
        let parts = cleanName.split(separator: " ").map(String.init)
        let firstName = parts.first ?? cleanName
        let lastName = parts.dropFirst().joined(separator: " ")
        return SavedContact(
            id: UUID(),
            firstName: firstName,
            lastName: lastName,
            role: role.trimmingCharacters(in: .whitespacesAndNewlines),
            phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            lastUsedAt: Date()
        )
    }

    private func validateCurrentStep() -> Bool {
        switch currentStep {
        case .masterDocument:
            let required = [
                masterDocument.projectName,
                masterDocument.siteAddress,
                masterDocument.nearestHospitalName,
                masterDocument.hospitalDirections
            ]
            if required.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                errorMessage = "Complete project, site, and hospital details before continuing."
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
}

private extension SavedContact {
    func withDate(_ date: Date) -> SavedContact {
        var copy = self
        copy.lastUsedAt = date
        return copy
    }
}
