import SwiftUI

struct WizardFlowView: View {
    @ObservedObject var viewModel: WizardViewModel
    @EnvironmentObject private var libraryViewModel: LibraryViewModel
    @State private var showingHazardPicker = false
    let currentUserDisplayName: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 9)
                            .fill(Color.proYellow)
                            .frame(width: 34, height: 34)
                            .overlay {
                                Image(systemName: "shield.fill")
                                    .foregroundStyle(Color.proSlate900)
                                    .font(.subheadline.weight(.bold))
                            }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ProRAMS Builder")
                                .font(.headline.weight(.heavy))
                            Text("Construction RAMS Workflow")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        Spacer()
                        if viewModel.currentStep == .review {
                            Label("Finish & Preview", systemImage: "doc.richtext")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.proSlate900)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.proYellow)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(14)
                    .background(Color.proSlate900)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    ProStepTrackerView(
                        steps: viewModel.orderedSteps,
                        currentStep: viewModel.currentStep
                    )

                    Text("Step \(viewModel.stepIndex + 1) of \(viewModel.orderedSteps.count): \(viewModel.currentStep.rawValue)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding([.horizontal, .top])

                Divider()

                Group {
                    switch viewModel.currentStep {
                    case .masterDocument:
                        MasterDocumentStepView(viewModel: viewModel)
                    case .ramsDocument:
                        RamsDocumentStepView(
                            viewModel: viewModel,
                            showHazardPicker: $showingHazardPicker,
                            currentUserDisplayName: currentUserDisplayName
                        )
                    case .liftPlan:
                        LiftPlanStepView(viewModel: viewModel)
                    case .review:
                        ReviewExportStepView(viewModel: viewModel)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                VStack(spacing: 8) {
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let statusMessage = viewModel.statusMessage {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack {
                        Button("Back") {
                            viewModel.goBack()
                        }
                        .buttonStyle(.plain)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .disabled(!viewModel.canGoBack)

                        Spacer()

                        if !viewModel.isFinalStep {
                            Button("Continue") {
                                viewModel.goNext()
                            }
                            .buttonStyle(.plain)
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(Color.proSlate900)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.proYellow)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding()
            }
            .background(Color(red: 248 / 255, green: 250 / 255, blue: 252 / 255))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingHazardPicker) {
                HazardLibraryPickerSheet(
                    templates: libraryViewModel.library.hazards,
                    onAddSelected: { templates in
                        viewModel.addRisks(from: templates)
                        showingHazardPicker = false
                    }
                )
            }
        }
    }
}

private struct MasterDocumentStepView: View {
    @ObservedObject var viewModel: WizardViewModel
    @State private var showingAddClientSheet = false
    @State private var projectEditorContext: ProjectEditorContext?

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Set up project context first")
                        .font(.headline)
                    Text("Start by selecting or creating a client, then create/select a project with emergency contacts, hospital details, key contacts, and map.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("1. Client") {
                Picker(
                    "Selected client",
                    selection: Binding(
                        get: { viewModel.masterDocument.clientID },
                        set: { viewModel.selectClient(id: $0) }
                    )
                ) {
                    Text("Select client").tag(nil as UUID?)
                    ForEach(viewModel.availableClients) { client in
                        Text(client.name).tag(client.id as UUID?)
                    }
                }

                Button {
                    showingAddClientSheet = true
                } label: {
                    Label("Create client", systemImage: "plus.circle")
                }

                if let selectedClient = viewModel.selectedClient {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedClient.name)
                            .font(.subheadline.weight(.semibold))
                        let contactSummary = [
                            selectedClient.contactName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : selectedClient.contactName,
                            selectedClient.contactPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : selectedClient.contactPhone
                        ]
                            .compactMap { $0 }
                            .joined(separator: " • ")
                        if !contactSummary.isEmpty {
                            Text(contactSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("2. Project") {
                if viewModel.selectedClient == nil {
                    Label("Select a client first to unlock projects.", systemImage: "arrow.up")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Picker(
                        "Selected project",
                        selection: Binding(
                            get: { viewModel.masterDocument.projectID },
                            set: { viewModel.selectProject(id: $0) }
                        )
                    ) {
                        Text("Select project").tag(nil as UUID?)
                        ForEach(viewModel.availableProjectsForSelectedClient) { project in
                            Text(project.name).tag(project.id as UUID?)
                        }
                    }

                    HStack {
                        Button {
                            guard let client = viewModel.selectedClient else { return }
                            projectEditorContext = ProjectEditorContext(
                                client: client,
                                existing: nil,
                                draft: viewModel.masterDocument
                            )
                        } label: {
                            Label("Create project", systemImage: "plus.circle")
                        }

                        Spacer()

                        Button {
                            guard let client = viewModel.selectedClient,
                                  let project = viewModel.selectedProject else { return }
                            projectEditorContext = ProjectEditorContext(
                                client: client,
                                existing: project,
                                draft: viewModel.masterDocument
                            )
                        } label: {
                            Label("Edit project", systemImage: "pencil")
                        }
                        .disabled(viewModel.selectedProject == nil)
                    }

                    if let selectedProject = viewModel.selectedProject {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedProject.name)
                                .font(.subheadline.weight(.semibold))
                            Text(selectedProject.siteAddress.ifEmpty("No site address"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !selectedProject.referenceCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Reference: \(selectedProject.referenceCode)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Project readiness") {
                readinessRow(
                    "Emergency contact",
                    isComplete: !viewModel.masterDocument.emergencyContactName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                        !viewModel.masterDocument.emergencyContactPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
                readinessRow(
                    "Nearest hospital",
                    isComplete: !viewModel.masterDocument.nearestHospitalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                        !viewModel.masterDocument.nearestHospitalAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                        !viewModel.masterDocument.hospitalDirections.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
                readinessRow(
                    "Key contacts",
                    isComplete: viewModel.masterDocument.keyContacts.contains(where: {
                        !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                            !$0.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    })
                )
                readinessRow(
                    "Map image",
                    isComplete: viewModel.masterDocument.mapImageData != nil
                )
            }
        }
        .sheet(isPresented: $showingAddClientSheet) {
            ClientEditorSheet { name, contactName, contactEmail, contactPhone in
                viewModel.createClient(
                    name: name,
                    contactName: contactName,
                    contactEmail: contactEmail,
                    contactPhone: contactPhone
                )
            }
        }
        .sheet(item: $projectEditorContext) { context in
            ProjectEditorSheet(
                client: context.client,
                existing: context.existing,
                draft: context.draft
            ) {
                name,
                siteAddress,
                principalContractor,
                referenceCode,
                emergencyContactName,
                emergencyContactPhone,
                nearestHospitalName,
                nearestHospitalAddress,
                hospitalDirections,
                keyContacts,
                mapImageData in
                viewModel.createProject(
                    projectID: context.existing?.id,
                    projectCreatedAt: context.existing?.createdAt,
                    name: name,
                    siteAddress: siteAddress,
                    principalContractor: principalContractor,
                    referenceCode: referenceCode,
                    emergencyContactName: emergencyContactName,
                    emergencyContactPhone: emergencyContactPhone,
                    nearestHospitalName: nearestHospitalName,
                    nearestHospitalAddress: nearestHospitalAddress,
                    hospitalDirections: hospitalDirections,
                    keyContacts: keyContacts,
                    mapImageData: mapImageData,
                    clientID: context.client.id
                )
            }
        }
    }

    @ViewBuilder
    private func readinessRow(_ title: String, isComplete: Bool) -> some View {
        HStack {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(isComplete ? Color.green : Color.orange)
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(isComplete ? "Ready" : "Missing")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isComplete ? Color.green : Color.orange)
        }
    }
}

private struct ProjectEditorContext: Identifiable {
    let id = UUID()
    let client: ClientRecord
    let existing: ProjectRecord?
    let draft: MasterDocument
}

private struct RamsDocumentStepView: View {
    @ObservedObject var viewModel: WizardViewModel
    @Binding var showHazardPicker: Bool
    let currentUserDisplayName: String

    var body: some View {
        Form {
            Section("RAMS details") {
                TextField("RAMS title", text: $viewModel.ramsDocument.title)
                TextField("Reference code", text: $viewModel.ramsDocument.referenceCode)
                TextField("Prepared by", text: $viewModel.ramsDocument.preparedBy)
                TextField("Approved by", text: $viewModel.ramsDocument.approvedBy)
                Button {
                    viewModel.quickAddApprovedByForSamePerson(loggedInUserName: currentUserDisplayName)
                } label: {
                    Label("Same as prepared / logged-in user", systemImage: "person.badge.plus")
                }
                .buttonStyle(.bordered)
                TextField("Scope of works", text: $viewModel.ramsDocument.scopeOfWorks, axis: .vertical)
                    .lineLimit(3...6)

                Toggle("This RAMS includes lifting operations", isOn: $viewModel.includeLiftPlan)
            }

            Section("Method statement") {
                ForEach($viewModel.ramsDocument.methodStatements) { $statement in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Step \(statement.sequence)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField("Step title", text: $statement.title)
                        TextField("Step details", text: $statement.details, axis: .vertical)
                            .lineLimit(2...4)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: viewModel.removeMethodStatements)

                Button {
                    viewModel.addMethodStatement()
                } label: {
                    Label("Add method step", systemImage: "plus.circle")
                }
            }

            Section("Required PPE") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                    ForEach(PPEItemID.allCases) { item in
                        let selected = viewModel.ramsDocument.requiredPPE.contains(item)
                        Button {
                            viewModel.togglePPE(item)
                        } label: {
                            VStack(spacing: 6) {
                                Text(item.emoji)
                                    .font(.title3)
                                Text(item.title)
                                    .font(.caption2.weight(.semibold))
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(selected ? .yellow : .primary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 72)
                            .padding(8)
                            .background(selected ? Color.yellow.opacity(0.18) : Color.secondary.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selected ? Color.yellow : Color.secondary.opacity(0.2), lineWidth: selected ? 2 : 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section {
                HStack {
                    Text("Risk assessments")
                        .font(.headline)
                    Spacer()
                    RiskReviewBadge(review: viewModel.ramsDocument.overallRiskReview)
                }

                HStack {
                    Button {
                        showHazardPicker = true
                    } label: {
                        Label("Add from hazard library", systemImage: "books.vertical")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        viewModel.addBlankRisk()
                    } label: {
                        Label("Add blank", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                }

                if viewModel.ramsDocument.riskAssessments.isEmpty {
                    Text("No risks added yet.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Hazard list") {
                ForEach($viewModel.ramsDocument.riskAssessments) { $risk in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Hazard", text: $risk.hazardTitle)
                        TextField("Risk to", text: $risk.riskTo)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Control measures (one per line)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextEditor(
                                text: Binding(
                                    get: { risk.controlMeasures.joined(separator: "\n") },
                                    set: { newValue in
                                        $risk.controlMeasures.wrappedValue = newValue
                                            .split(separator: "\n")
                                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                            .filter { !$0.isEmpty }
                                    }
                                )
                            )
                            .frame(minHeight: 70)
                        }

                        Grid(horizontalSpacing: 10, verticalSpacing: 8) {
                            GridRow {
                                Text("Initial L")
                                Stepper("", value: $risk.initialLikelihood, in: 1...5)
                                    .labelsHidden()
                                Text("\(risk.initialLikelihood)")
                            }
                            GridRow {
                                Text("Initial S")
                                Stepper("", value: $risk.initialSeverity, in: 1...5)
                                    .labelsHidden()
                                Text("\(risk.initialSeverity)")
                            }
                            GridRow {
                                Text("Residual L")
                                Stepper("", value: $risk.residualLikelihood, in: 1...5)
                                    .labelsHidden()
                                Text("\(risk.residualLikelihood)")
                            }
                            GridRow {
                                Text("Residual S")
                                Stepper("", value: $risk.residualSeverity, in: 1...5)
                                    .labelsHidden()
                                Text("\(risk.residualSeverity)")
                            }
                        }

                        HStack {
                            Text("Initial score: \(risk.initialScore)")
                            Text("Residual score: \(risk.residualScore)")
                            Spacer()
                            RiskReviewBadge(review: risk.overallReview)
                        }
                        .font(.caption)
                    }
                    .padding(.vertical, 6)
                }
                .onDelete(perform: viewModel.removeRisks)
            }

            Section("Emergency procedures") {
                TextField("First aid station", text: $viewModel.ramsDocument.emergencyFirstAidStation)
                TextField("Fire assembly point", text: $viewModel.ramsDocument.emergencyAssemblyPoint)
                TextField("Emergency contact", text: $viewModel.ramsDocument.emergencyContact)
            }
        }
        .onAppear {
            viewModel.populatePreparedByIfNeeded(with: currentUserDisplayName)
        }
    }
}

private struct LiftPlanStepView: View {
    @ObservedObject var viewModel: WizardViewModel

    var body: some View {
        Form {
            Section("Lift summary") {
                TextField("Lift plan title", text: $viewModel.liftPlan.title)
                Picker("Category", selection: $viewModel.liftPlan.category) {
                    ForEach(LiftCategory.allCases) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                TextField("Crane / plant", text: $viewModel.liftPlan.craneOrPlant)
                TextField("Load description", text: $viewModel.liftPlan.loadDescription)
                TextField("Load weight (kg)", value: $viewModel.liftPlan.loadWeightKg, format: .number)
                    .keyboardType(.decimalPad)
                TextField("Lift radius (m)", value: $viewModel.liftPlan.liftRadiusMeters, format: .number)
                    .keyboardType(.decimalPad)
                TextField("Boom length (m)", value: $viewModel.liftPlan.boomLengthMeters, format: .number)
                    .keyboardType(.decimalPad)
            }

            Section("People and communication") {
                TextField("Appointed person", text: $viewModel.liftPlan.appointedPerson)
                TextField("Crane supervisor", text: $viewModel.liftPlan.craneSupervisor)
                TextField("Lift operator", text: $viewModel.liftPlan.liftOperator)
                TextField("Slinger / signaller", text: $viewModel.liftPlan.slingerSignaller)
                TextField("Communication method", text: $viewModel.liftPlan.communicationMethod)
            }

            Section("Locations and controls") {
                TextField("Setup location", text: $viewModel.liftPlan.setupLocation)
                TextField("Landing location", text: $viewModel.liftPlan.landingLocation)
                TextField("Ground bearing capacity", text: $viewModel.liftPlan.groundBearingCapacity)
                TextField("Wind/weather limit", text: $viewModel.liftPlan.windLimit)
                TextField("Exclusion zone details", text: $viewModel.liftPlan.exclusionZoneDetails, axis: .vertical)
                    .lineLimit(2...4)
                TextField("Emergency rescue plan", text: $viewModel.liftPlan.emergencyRescuePlan, axis: .vertical)
                    .lineLimit(2...4)
                TextField("Permit references", text: $viewModel.liftPlan.permitReferences, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section("Accessories") {
                TextEditor(
                    text: Binding(
                        get: { viewModel.liftPlan.liftingAccessories.joined(separator: "\n") },
                        set: { newValue in
                            viewModel.liftPlan.liftingAccessories = newValue
                                .split(separator: "\n")
                                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                .filter { !$0.isEmpty }
                        }
                    )
                )
                .frame(minHeight: 80)
            }

            Section("Lift sequence") {
                ForEach(viewModel.liftPlan.methodSequence.indices, id: \.self) { index in
                    TextField(
                        "Step \(index + 1)",
                        text: Binding(
                            get: { viewModel.liftPlan.methodSequence[index] },
                            set: { viewModel.liftPlan.methodSequence[index] = $0 }
                        )
                    )
                }
                .onDelete { offsets in
                    viewModel.liftPlan.methodSequence.remove(atOffsets: offsets)
                }
                Button {
                    viewModel.liftPlan.methodSequence.append("")
                } label: {
                    Label("Add lift sequence step", systemImage: "plus.circle")
                }
            }

            Section("Drawing") {
                MapImagePickerView(imageData: $viewModel.liftPlan.drawingImageData)
            }
        }
    }
}

private struct ReviewExportStepView: View {
    @ObservedObject var viewModel: WizardViewModel
    @State private var signerName = ""
    @State private var signerRole = ""
    @State private var signatureData: Data?

    var body: some View {
        Form {
            Section("Summary") {
                LabeledContent("Project", value: viewModel.masterDocument.projectName.ifEmpty("-"))
                LabeledContent("RAMS title", value: viewModel.ramsDocument.title.ifEmpty("-"))
                LabeledContent("Reference", value: viewModel.ramsDocument.referenceCode.ifEmpty("-"))
                LabeledContent("Hazards", value: "\(viewModel.ramsDocument.riskAssessments.count)")
                LabeledContent("Required PPE", value: "\(viewModel.ramsDocument.requiredPPE.count)")
                HStack {
                    Text("Overall risk review")
                    Spacer()
                    RiskReviewBadge(review: viewModel.ramsDocument.overallRiskReview)
                }
                LabeledContent("Lift plan included", value: viewModel.includeLiftPlan ? "Yes" : "No")
                LabeledContent("Emergency contact", value: viewModel.ramsDocument.emergencyContact.ifEmpty("-"))
            }

            Section("Digital signatures") {
                TextField("Signer name", text: $signerName)
                TextField("Role", text: $signerRole)
                SignaturePadView(signatureImageData: $signatureData)

                Button {
                    guard let signatureData else { return }
                    viewModel.addSignature(name: signerName, role: signerRole, signatureImageData: signatureData)
                    signerName = ""
                    signerRole = ""
                    self.signatureData = nil
                } label: {
                    Label("Add signature to table", systemImage: "signature")
                }
                .buttonStyle(.borderedProminent)
                .disabled(signatureData == nil)

                if viewModel.ramsDocument.signatureTable.isEmpty {
                    Text("No signatures yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.ramsDocument.signatureTable) { signature in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(signature.signerName)
                                .font(.subheadline.weight(.semibold))
                            Text(signature.signerRole)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(DateFormatter.shortDateTime.string(from: signature.signedAt))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Actions") {
                Button {
                    viewModel.saveToLibraries()
                } label: {
                    Label("Save master, RAMS and lift plan to libraries", systemImage: "tray.and.arrow.down")
                }

                Button {
                    viewModel.generatePublicLink()
                } label: {
                    Label("Generate public link (placeholder)", systemImage: "link")
                }

                if let link = viewModel.generatedPublicLink {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(link.url.absoluteString)
                            .font(.footnote)
                            .textSelection(.enabled)
                        Text("Expires: \(DateFormatter.shortDateTime.string(from: link.expiresAt))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    viewModel.exportPDF()
                } label: {
                    Label("Export RAMS + signatures to PDF", systemImage: "doc.richtext")
                }

                if let exportedURL = viewModel.exportedPDFURL {
                    ShareLink(item: exportedURL) {
                        Label("Share exported PDF", systemImage: "square.and.arrow.up")
                    }
                }

                Button("Start new wizard") {
                    viewModel.startNewWizard()
                }
                .foregroundStyle(.orange)
            }
        }
    }
}

private struct HazardLibraryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let templates: [HazardTemplate]
    let onAddSelected: ([HazardTemplate]) -> Void
    @State private var selectedTemplateIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List(templates) { template in
                Button {
                    toggleSelection(for: template.id)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(template.title)
                                .font(.headline)
                            Text(template.category)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(template.riskToDefault)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: selectedTemplateIDs.contains(template.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedTemplateIDs.contains(template.id) ? Color.proTeal : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
            .navigationTitle("Hazard Library")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(addButtonTitle) {
                        let selectedTemplates = templates.filter { selectedTemplateIDs.contains($0.id) }
                        onAddSelected(selectedTemplates)
                        dismiss()
                    }
                    .disabled(selectedTemplateIDs.isEmpty)
                }
            }
        }
    }

    private var addButtonTitle: String {
        selectedTemplateIDs.count == 1 ? "Add 1" : "Add \(selectedTemplateIDs.count)"
    }

    private func toggleSelection(for id: UUID) {
        if selectedTemplateIDs.contains(id) {
            selectedTemplateIDs.remove(id)
        } else {
            selectedTemplateIDs.insert(id)
        }
    }
}

private struct ClientEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var contactName = ""
    @State private var contactEmail = ""
    @State private var contactPhone = ""

    let onSave: (_ name: String, _ contactName: String, _ contactEmail: String, _ contactPhone: String) -> Bool

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
            .navigationTitle("New Client")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if onSave(name, contactName, contactEmail, contactPhone) {
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct ProjectEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var siteAddress = ""
    @State private var principalContractor = ""
    @State private var referenceCode = ""
    @State private var emergencyContactName = ""
    @State private var emergencyContactPhone = ""
    @State private var nearestHospitalName = ""
    @State private var nearestHospitalAddress = ""
    @State private var hospitalDirections = ""
    @State private var keyContacts: [KeyContact] = [KeyContact()]
    @State private var mapImageData: Data?

    let client: ClientRecord
    let existing: ProjectRecord?
    let onSave: (
        _ name: String,
        _ siteAddress: String,
        _ principalContractor: String,
        _ referenceCode: String,
        _ emergencyContactName: String,
        _ emergencyContactPhone: String,
        _ nearestHospitalName: String,
        _ nearestHospitalAddress: String,
        _ hospitalDirections: String,
        _ keyContacts: [KeyContact],
        _ mapImageData: Data?
    ) -> Bool

    init(
        client: ClientRecord,
        existing: ProjectRecord?,
        draft: MasterDocument,
        onSave: @escaping (
            _ name: String,
            _ siteAddress: String,
            _ principalContractor: String,
            _ referenceCode: String,
            _ emergencyContactName: String,
            _ emergencyContactPhone: String,
            _ nearestHospitalName: String,
            _ nearestHospitalAddress: String,
            _ hospitalDirections: String,
            _ keyContacts: [KeyContact],
            _ mapImageData: Data?
        ) -> Bool
    ) {
        self.client = client
        self.existing = existing
        self.onSave = onSave
        _name = State(initialValue: existing?.name ?? draft.projectName)
        _siteAddress = State(initialValue: existing?.siteAddress ?? draft.siteAddress)
        _principalContractor = State(initialValue: existing?.principalContractor ?? draft.principalContractor)
        _referenceCode = State(initialValue: existing?.referenceCode ?? "")
        _emergencyContactName = State(initialValue: existing?.emergencyContactName ?? draft.emergencyContactName)
        _emergencyContactPhone = State(initialValue: existing?.emergencyContactPhone ?? draft.emergencyContactPhone)
        _nearestHospitalName = State(initialValue: existing?.nearestHospitalName ?? draft.nearestHospitalName)
        _nearestHospitalAddress = State(initialValue: existing?.nearestHospitalAddress ?? draft.nearestHospitalAddress)
        _hospitalDirections = State(initialValue: existing?.hospitalDirections ?? draft.hospitalDirections)
        let existingContacts = existing?.keyContacts ?? draft.keyContacts
        _keyContacts = State(initialValue: existingContacts.isEmpty ? [KeyContact()] : existingContacts)
        _mapImageData = State(initialValue: existing?.mapImageData ?? draft.mapImageData)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Client") {
                    Text(client.name)
                        .font(.subheadline.weight(.semibold))
                }

                Section("Project details") {
                    TextField("Project name", text: $name)
                    TextField("Site address", text: $siteAddress, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Principal contractor", text: $principalContractor)
                    TextField("Reference code", text: $referenceCode)
                }

                Section("Emergency and hospital") {
                    TextField("Emergency contact name", text: $emergencyContactName)
                    TextField("Emergency contact phone", text: $emergencyContactPhone)
                        .keyboardType(.phonePad)
                    TextField("Nearest hospital", text: $nearestHospitalName)
                    TextField("Hospital address", text: $nearestHospitalAddress, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Directions to hospital", text: $hospitalDirections, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Key contacts") {
                    ForEach($keyContacts) { $contact in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Name", text: $contact.name)
                            TextField("Role", text: $contact.role)
                            TextField("Phone", text: $contact.phone)
                                .keyboardType(.phonePad)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { offsets in
                        keyContacts.remove(atOffsets: offsets)
                        if keyContacts.isEmpty {
                            keyContacts = [KeyContact()]
                        }
                    }

                    Button {
                        keyContacts.append(KeyContact())
                    } label: {
                        Label("Add contact", systemImage: "plus.circle")
                    }
                }

                Section("Map") {
                    MapImagePickerView(imageData: $mapImageData)
                }
            }
            .navigationTitle(existing == nil ? "New Project" : "Edit Project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if onSave(
                            name,
                            siteAddress,
                            principalContractor,
                            referenceCode,
                            emergencyContactName,
                            emergencyContactPhone,
                            nearestHospitalName,
                            nearestHospitalAddress,
                            hospitalDirections,
                            keyContacts,
                            mapImageData
                        ) {
                            dismiss()
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var hasAtLeastOneContact: Bool {
        keyContacts.contains { contact in
            !contact.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !contact.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !siteAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !emergencyContactName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !emergencyContactPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !nearestHospitalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !nearestHospitalAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !hospitalDirections.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            hasAtLeastOneContact &&
            mapImageData != nil
    }
}

private struct ProStepTrackerView: View {
    let steps: [WizardStep]
    let currentStep: WizardStep

    private var currentIndex: Int {
        steps.firstIndex(of: currentStep) ?? 0
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, _ in
                HStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(index <= currentIndex ? Color.proYellow : Color.proSlate100)
                            .frame(width: 30, height: 30)
                        if index < currentIndex {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.proSlate900)
                        } else {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(index <= currentIndex ? Color.proSlate900 : .secondary)
                        }
                    }

                    if index < steps.count - 1 {
                        Rectangle()
                            .fill(index < currentIndex ? Color.proYellow : Color.proSlate100)
                            .frame(width: 34, height: 4)
                            .padding(.horizontal, 8)
                    }
                }
            }
        }
        .padding(12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.proSlate100, lineWidth: 1)
        )
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : self
    }
}
