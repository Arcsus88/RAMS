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
            statusMessage = "PDF exported to temporary storage."
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
