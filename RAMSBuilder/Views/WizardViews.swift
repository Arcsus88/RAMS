import SwiftUI

struct WizardFlowView: View {
    @ObservedObject var viewModel: WizardViewModel
    @EnvironmentObject private var libraryViewModel: LibraryViewModel
    @State private var showingHazardPicker = false

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
                            showHazardPicker: $showingHazardPicker
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
                    onSelect: { template in
                        viewModel.addRisk(from: template)
                        showingHazardPicker = false
                    }
                )
            }
        }
    }
}

private struct MasterDocumentStepView: View {
    @ObservedObject var viewModel: WizardViewModel
    @EnvironmentObject private var libraryViewModel: LibraryViewModel

    var body: some View {
        Form {
            Section("Project info") {
                if !libraryViewModel.library.projects.isEmpty {
                    Menu {
                        ForEach(libraryViewModel.library.projects) { project in
                            Button(project.name.ifEmpty("Untitled project")) {
                                viewModel.applySavedProject(project)
                            }
                        }
                    } label: {
                        Label("Use saved project profile", systemImage: "tray.full")
                    }
                }

                TextField("Project name", text: $viewModel.masterDocument.projectName)
                AddressAutocompleteField(
                    title: "Site address",
                    placeholder: "Start typing site address...",
                    text: $viewModel.masterDocument.siteAddress
                )
                DropdownTextField(
                    title: "Client",
                    placeholder: "Client name",
                    text: $viewModel.masterDocument.clientName,
                    options: libraryViewModel.companyNameOptions
                )
                DropdownTextField(
                    title: "Principal contractor",
                    placeholder: "Principal contractor",
                    text: $viewModel.masterDocument.principalContractor,
                    options: libraryViewModel.companyNameOptions
                )
            }

            Section("Emergency details") {
                DropdownTextField(
                    title: "Emergency contact name",
                    placeholder: "Emergency contact",
                    text: $viewModel.masterDocument.emergencyContactName,
                    options: libraryViewModel.contactNameOptions
                )
                TextField("Emergency contact phone", text: $viewModel.masterDocument.emergencyContactPhone)
                TextField("Nearest hospital", text: $viewModel.masterDocument.nearestHospitalName)
                AddressAutocompleteField(
                    title: "Hospital address",
                    placeholder: "Start typing hospital address...",
                    text: $viewModel.masterDocument.nearestHospitalAddress
                )
                TextField("Directions to hospital", text: $viewModel.masterDocument.hospitalDirections, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section("Key contacts") {
                ForEach($viewModel.masterDocument.keyContacts) { $contact in
                    VStack(alignment: .leading, spacing: 8) {
                        DropdownTextField(
                            title: "Name",
                            placeholder: "Contact name",
                            text: $contact.name,
                            options: libraryViewModel.contactNameOptions
                        )
                        DropdownTextField(
                            title: "Role",
                            placeholder: "Contact role",
                            text: $contact.role,
                            options: libraryViewModel.contactRoleOptions
                        )
                        TextField("Phone", text: $contact.phone)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { offsets in
                    viewModel.masterDocument.keyContacts.remove(atOffsets: offsets)
                }

                Button {
                    viewModel.masterDocument.keyContacts.append(KeyContact())
                } label: {
                    Label("Add contact", systemImage: "plus.circle")
                }
            }

            Section("Map") {
                MapImagePickerView(imageData: $viewModel.masterDocument.mapImageData)
            }
        }
        .onAppear {
            viewModel.applyCurrentUserDefaults()
        }
    }
}

private struct RamsDocumentStepView: View {
    @ObservedObject var viewModel: WizardViewModel
    @Binding var showHazardPicker: Bool
    @EnvironmentObject private var libraryViewModel: LibraryViewModel

    private let emergencyAidOptions = [
        "Main site office",
        "Gatehouse first aid station",
        "Welfare cabin"
    ]

    private let assemblyPointOptions = [
        "Main Gate",
        "North car park",
        "Site welfare area"
    ]

    var body: some View {
        Form {
            Section("RAMS details") {
                TextField("RAMS title", text: $viewModel.ramsDocument.title)
                TextField("Reference code", text: $viewModel.ramsDocument.referenceCode)
                DropdownTextField(
                    title: "Prepared by",
                    placeholder: "Prepared by",
                    text: $viewModel.ramsDocument.preparedBy,
                    options: libraryViewModel.contactNameOptions
                )
                DropdownTextField(
                    title: "Approved by",
                    placeholder: "Approved by",
                    text: $viewModel.ramsDocument.approvedBy,
                    options: libraryViewModel.contactNameOptions
                )
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
                                Picker("Initial L", selection: $risk.initialLikelihood) {
                                    ForEach(1...5, id: \.self) { value in
                                        Text("\(value)").tag(value)
                                    }
                                }
                                .pickerStyle(.menu)
                                Text("\(risk.initialLikelihood)")
                            }
                            GridRow {
                                Text("Initial S")
                                Picker("Initial S", selection: $risk.initialSeverity) {
                                    ForEach(1...5, id: \.self) { value in
                                        Text("\(value)").tag(value)
                                    }
                                }
                                .pickerStyle(.menu)
                                Text("\(risk.initialSeverity)")
                            }
                            GridRow {
                                Text("Residual L")
                                Picker("Residual L", selection: $risk.residualLikelihood) {
                                    ForEach(1...5, id: \.self) { value in
                                        Text("\(value)").tag(value)
                                    }
                                }
                                .pickerStyle(.menu)
                                Text("\(risk.residualLikelihood)")
                            }
                            GridRow {
                                Text("Residual S")
                                Picker("Residual S", selection: $risk.residualSeverity) {
                                    ForEach(1...5, id: \.self) { value in
                                        Text("\(value)").tag(value)
                                    }
                                }
                                .pickerStyle(.menu)
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
                DropdownTextField(
                    title: "First aid station",
                    placeholder: "First aid station",
                    text: $viewModel.ramsDocument.emergencyFirstAidStation,
                    options: emergencyAidOptions
                )
                DropdownTextField(
                    title: "Fire assembly point",
                    placeholder: "Assembly point",
                    text: $viewModel.ramsDocument.emergencyAssemblyPoint,
                    options: assemblyPointOptions
                )
                DropdownTextField(
                    title: "Emergency contact",
                    placeholder: "Emergency contact",
                    text: $viewModel.ramsDocument.emergencyContact,
                    options: libraryViewModel.contactNameOptions
                )
            }
        }
    }
}

private struct LiftPlanStepView: View {
    @ObservedObject var viewModel: WizardViewModel
    @EnvironmentObject private var libraryViewModel: LibraryViewModel

    private let communicationOptions = [
        "Two-way radios",
        "Standard hand signals",
        "Radio + hand signals"
    ]

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
                DropdownTextField(
                    title: "Appointed person",
                    placeholder: "Appointed person",
                    text: $viewModel.liftPlan.appointedPerson,
                    options: libraryViewModel.contactNameOptions
                )
                DropdownTextField(
                    title: "Crane supervisor",
                    placeholder: "Crane supervisor",
                    text: $viewModel.liftPlan.craneSupervisor,
                    options: libraryViewModel.contactNameOptions
                )
                DropdownTextField(
                    title: "Lift operator",
                    placeholder: "Lift operator",
                    text: $viewModel.liftPlan.liftOperator,
                    options: libraryViewModel.contactNameOptions
                )
                DropdownTextField(
                    title: "Slinger / signaller",
                    placeholder: "Slinger / signaller",
                    text: $viewModel.liftPlan.slingerSignaller,
                    options: libraryViewModel.contactNameOptions
                )
                DropdownTextField(
                    title: "Communication method",
                    placeholder: "Communication method",
                    text: $viewModel.liftPlan.communicationMethod,
                    options: communicationOptions
                )
            }

            Section("Locations and controls") {
                AddressAutocompleteField(
                    title: "Setup location",
                    placeholder: "Start typing setup location...",
                    text: $viewModel.liftPlan.setupLocation
                )
                AddressAutocompleteField(
                    title: "Landing location",
                    placeholder: "Start typing landing location...",
                    text: $viewModel.liftPlan.landingLocation
                )
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
    @EnvironmentObject private var sessionViewModel: SessionViewModel
    @EnvironmentObject private var libraryViewModel: LibraryViewModel
    @State private var signerName = ""
    @State private var signerRole = ""
    @State private var signatureData: Data?

    private var signerRoleOptions: [String] {
        let defaults = ["Safety Officer", "Site Manager", "Project Manager", "Supervisor"]
        return Array(Set(defaults + libraryViewModel.contactRoleOptions)).sorted()
    }

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
                LabeledContent("Saved projects", value: "\(libraryViewModel.library.projects.count)")
                LabeledContent("Saved contacts", value: "\(libraryViewModel.library.contacts.count)")
            }

            Section("Digital signatures") {
                TextField("Signer name", text: $signerName)
                DropdownTextField(
                    title: "Role",
                    placeholder: "Select role",
                    text: $signerRole,
                    options: signerRoleOptions
                )
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
                    Label("Save project, contacts, master, RAMS and lift plan", systemImage: "tray.and.arrow.down")
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
        .onAppear {
            if signerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                signerName = sessionViewModel.currentUser?.displayName ?? ""
            }
            if signerRole.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                signerRole = "Safety Officer"
            }
        }
    }
}

private struct HazardLibraryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let templates: [HazardTemplate]
    let onSelect: (HazardTemplate) -> Void

    var body: some View {
        NavigationStack {
            List(templates) { template in
                Button {
                    onSelect(template)
                    dismiss()
                } label: {
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
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Hazard Library")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
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
