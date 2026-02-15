import SwiftUI
import UIKit

/// Pagination notes for future PDF export:
/// - Render this view in page-sized slices using a fixed A4 content width.
/// - Keep table headers and section title bars as "keep-with-next" blocks.
/// - Split large risk tables across pages with repeated column headers.
/// - Honor explicit page break hints before major sections (for example, Contents).
/// - Pre-measure section heights so long groups can start on a fresh page.
struct RAMSPDFLayoutView: View {
    let document: RAMSPDFLayoutDocument
    var showPageBreakHints: Bool = true

    private var activeSections: [RAMSPDFLayoutDocument.AssignedSection] {
        document.assignedSections.filter(\.isActive)
    }

    private var contentsEntries: [RAMSPDFLayoutDocument.ContentsEntry] {
        if !document.contentsEntries.isEmpty {
            let sorted = document.contentsEntries.sorted(by: { $0.number < $1.number })
            guard !document.appendices.isEmpty else { return sorted }
            if sorted.contains(where: { $0.section.lowercased() == "appendices" }) {
                return sorted
            }
            let nextNumber = (sorted.last?.number ?? 0) + 1
            return sorted + [
                RAMSPDFLayoutDocument.ContentsEntry(number: nextNumber, section: "Appendices")
            ]
        }

        var number = 1
        var entries: [RAMSPDFLayoutDocument.ContentsEntry] = activeSections.map { section in
            defer { number += 1 }
            return RAMSPDFLayoutDocument.ContentsEntry(
                number: number,
                section: section.title,
                reference: section.reference,
                preStartCritical: section.preStartCritical,
                notes: section.notes
            )
        }

        if !document.appendices.isEmpty {
            entries.append(
                RAMSPDFLayoutDocument.ContentsEntry(
                    number: number,
                    section: "Appendices",
                    reference: nil,
                    preStartCritical: nil,
                    notes: nil
                )
            )
        }
        return entries
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 16) {
                    RAMSDocumentHeaderView(header: document.header)
                    RAMSMetadataGridView(metadata: document.metadata)
                    RAMSScopeOfWorksPanel(items: document.scopeOfWorks)

                    if !document.coverDetailCards.isEmpty || document.nearestHospitalMapImageData != nil {
                        RAMSCoverDetailCardsPanel(
                            cards: document.coverDetailCards,
                            mapImageData: document.nearestHospitalMapImageData
                        )
                    }

                    if !document.riskKeywords.isEmpty {
                        RAMSRiskKeywordsPanel(keywords: document.riskKeywords)
                    }

                    if let notes = document.additionalNotes, !notes.rams_isBlank {
                        RAMSAdditionalNotesPanel(notes: notes)
                    }

                    if showPageBreakHints {
                        RAMSPageBreakHintView(title: "Contents")
                    }

                    RAMSContentsTablePanel(entries: contentsEntries)

                    if !activeSections.isEmpty {
                        RAMSAssignedSectionsPanel(sections: activeSections)
                    }

                    if !document.appendices.isEmpty {
                        RAMSAppendicesPanel(appendices: document.appendices)
                    }

                    RAMSSignOffPanel(signOff: document.signOff)
                }
                .padding(28)
                .frame(maxWidth: RAMSPDFLayoutStyle.a4CardWidth, alignment: .leading)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
            .padding(.vertical, 22)
        }
        .background(Color(uiColor: .systemGray6))
    }
}

private enum RAMSPDFLayoutStyle {
    static let a4CardWidth: CGFloat = 794
    static let panelCornerRadius: CGFloat = 10
}

private struct RAMSDocumentHeaderView: View {
    let header: RAMSPDFLayoutDocument.Header

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(header.brandTitle)
                        .font(.system(size: 27, weight: .bold, design: .serif))
                        .foregroundStyle(Color.proSlate900)
                    Text(header.subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.secondary)
                }

                Spacer(minLength: 10)

                VStack(alignment: .trailing, spacing: 6) {
                    RAMSHeaderMetaLine(label: "Document Ref", value: header.documentReference)
                    RAMSHeaderMetaLine(label: "Date of Issue", value: header.dateOfIssue)

                    if let revisionLabel = header.revisionLabel, !revisionLabel.rams_isBlank {
                        Text(revisionLabel)
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.proSlate900.opacity(0.06))
                            .clipShape(Capsule())
                    }
                }
            }

            Divider()
        }
    }
}

private struct RAMSHeaderMetaLine: View {
    let label: String
    let value: String?

    var body: some View {
        HStack(spacing: 6) {
            Text(label + ":")
                .foregroundStyle(.secondary)
            Text(value.rams_displayValue)
                .foregroundStyle(.primary)
        }
        .font(.system(size: 12, weight: .medium))
    }
}

private struct RAMSMetadataGridView: View {
    let metadata: RAMSPDFLayoutDocument.Metadata

    var body: some View {
        VStack(spacing: 0) {
            RAMSDualMetadataRow(
                left: ("RAMS Document", metadata.ramsDocument),
                right: ("Project", metadata.project)
            )
            Divider()
            RAMSDualMetadataRow(
                left: ("Project Reference", metadata.projectReference),
                right: ("Expected Duration", metadata.expectedDuration)
            )
            Divider()
            RAMSDualMetadataRow(
                left: ("Planned Start Date", metadata.plannedStartDate),
                right: ("Planned Start Time", metadata.plannedStartTime)
            )
            Divider()
            RAMSSingleMetadataRow(
                title: "Project/Site Address",
                value: metadata.projectSiteAddress
            )
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: RAMSPDFLayoutStyle.panelCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RAMSPDFLayoutStyle.panelCornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct RAMSDualMetadataRow: View {
    let left: (String, String?)
    let right: (String, String?)

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            RAMSMetadataCell(title: left.0, value: left.1)
            Divider()
            RAMSMetadataCell(title: right.0, value: right.1)
        }
    }
}

private struct RAMSSingleMetadataRow: View {
    let title: String
    let value: String?

    var body: some View {
        RAMSMetadataCell(title: title, value: value)
    }
}

private struct RAMSMetadataCell: View {
    let title: String
    let value: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.secondary)
            Text(value.rams_displayValue)
                .font(.system(size: 13, weight: .regular))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

private struct RAMSScopeOfWorksPanel: View {
    let items: [String]

    private var cleanedItems: [String] {
        items
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        RAMSBorderedPanel(title: "Scope of Works") {
            if cleanedItems.isEmpty {
                Text("No scope defined.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(Array(cleanedItems.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\u{2022}")
                                .font(.system(size: 13, weight: .bold))
                                .padding(.top, 1)
                            Text(item)
                                .font(.system(size: 13))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }
}

private struct RAMSCoverDetailCardsPanel: View {
    let cards: [RAMSPDFLayoutDocument.CoverDetailCard]
    let mapImageData: Data?

    private var columns: [GridItem] {
        [
            GridItem(.flexible(minimum: 220), spacing: 12, alignment: .top),
            GridItem(.flexible(minimum: 220), spacing: 12, alignment: .top)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cover Details")
                .font(.system(size: 15, weight: .semibold))

            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(cards) { card in
                    RAMSCoverInfoCard(card: card)
                }

                if mapImageData != nil {
                    RAMSNearestHospitalMapCard(imageData: mapImageData)
                }
            }
        }
    }
}

private struct RAMSCoverInfoCard: View {
    let card: RAMSPDFLayoutDocument.CoverDetailCard

    var body: some View {
        RAMSBorderedPanel(title: card.title, compact: true) {
            if card.fields.isEmpty {
                Text("-")
                    .font(.system(size: 13))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(card.fields) { field in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(field.key)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text(field.value.rams_displayValue)
                                .font(.system(size: 13))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }
}

private struct RAMSNearestHospitalMapCard: View {
    let imageData: Data?

    var body: some View {
        RAMSBorderedPanel(title: "Nearest Hospital Map", compact: true) {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 180)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
                    .frame(height: 120)
                    .overlay {
                        Text("-")
                            .foregroundStyle(.secondary)
                    }
            }
        }
    }
}

private struct RAMSRiskKeywordsPanel: View {
    let keywords: [String]

    var body: some View {
        RAMSBorderedPanel(
            title: "Risk Keywords",
            panelColor: Color.orange.opacity(0.12),
            borderColor: Color.orange.opacity(0.35)
        ) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(keywords, id: \.self) { keyword in
                    Text(keyword)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.18))
                        .clipShape(Capsule())
                }
            }
        }
    }
}

private struct RAMSAdditionalNotesPanel: View {
    let notes: String

    var body: some View {
        RAMSBorderedPanel(title: "Additional Notes") {
            Text(notes.rams_displayValue)
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct RAMSPageBreakHintView: View {
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color.secondary.opacity(0.35))
                .frame(height: 1)
            Text("Page break before \(title)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Rectangle()
                .fill(Color.secondary.opacity(0.35))
                .frame(height: 1)
        }
    }
}

private struct RAMSContentsTablePanel: View {
    let entries: [RAMSPDFLayoutDocument.ContentsEntry]

    var body: some View {
        RAMSSectionHeading(title: "Contents")

        VStack(spacing: 0) {
            RAMSContentsHeaderRow()
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(Color(uiColor: .secondarySystemBackground))

            Divider()

            if entries.isEmpty {
                HStack {
                    Text("-")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(10)
            } else {
                ForEach(entries) { entry in
                    RAMSContentsDataRow(entry: entry)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                    if entry.id != entries.last?.id {
                        Divider()
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: RAMSPDFLayoutStyle.panelCornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: RAMSPDFLayoutStyle.panelCornerRadius, style: .continuous))
    }
}

private struct RAMSContentsHeaderRow: View {
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            RAMSTableHeaderCell("#", width: 40)
            RAMSTableHeaderCell("Section", width: 170)
            RAMSTableHeaderCell("Reference", width: 120)
            RAMSTableHeaderCell("Pre-start Critical", width: 120)
            RAMSTableHeaderCell("Notes", width: nil)
        }
    }
}

private struct RAMSContentsDataRow: View {
    let entry: RAMSPDFLayoutDocument.ContentsEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            RAMSTableBodyCell("\(entry.number)", width: 40)
            RAMSTableBodyCell(entry.section, width: 170)
            RAMSTableBodyCell(entry.reference.rams_displayValue, width: 120)
            RAMSTableBodyCell(entry.preStartCritical.rams_yesNoOrDash, width: 120)
            RAMSTableBodyCell(entry.notes.rams_displayValue, width: nil)
        }
    }
}

private struct RAMSAssignedSectionsPanel: View {
    let sections: [RAMSPDFLayoutDocument.AssignedSection]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RAMSSectionHeading(title: "Assigned Sections")

            ForEach(sections) { section in
                RAMSAssignedSectionBlock(section: section)
            }
        }
    }
}

private struct RAMSAssignedSectionBlock: View {
    let section: RAMSPDFLayoutDocument.AssignedSection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.title.rams_displayValue)
                        .font(.system(size: 15, weight: .semibold))
                    Text("Reference: \(section.reference.rams_displayValue)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("Pre-start Critical: \(section.preStartCritical ? "Yes" : "No")")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(section.preStartCritical ? Color.red.opacity(0.16) : Color.green.opacity(0.16))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.proSlate900.opacity(0.05))

            if let notes = section.notes, !notes.rams_isBlank {
                RAMSBorderedPanel(title: "Section Notes", compact: true) {
                    Text(notes)
                        .font(.system(size: 13))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let liftingPlanPreview = section.liftingPlanPreview {
                RAMSLiftingPlanPreviewPanel(preview: liftingPlanPreview)
            }

            RAMSEmbeddedSectionBodyView(bodyModel: section.body)
        }
        .padding(12)
        .overlay(
            RoundedRectangle(cornerRadius: RAMSPDFLayoutStyle.panelCornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: RAMSPDFLayoutStyle.panelCornerRadius, style: .continuous))
    }
}

private struct RAMSLiftingPlanPreviewPanel: View {
    let preview: RAMSPDFLayoutDocument.LiftingPlanPreview

    var body: some View {
        RAMSBorderedPanel(title: "Lifting Plan Preview", compact: true) {
            VStack(alignment: .leading, spacing: 8) {
                RAMSInlineFieldRow(title: "Title", value: preview.title)
                RAMSInlineFieldRow(title: "Category", value: preview.category)
                RAMSInlineFieldRow(title: "Crane / Plant", value: preview.craneOrPlant)
                RAMSInlineFieldRow(title: "Load", value: preview.loadDescription)
                RAMSInlineFieldRow(title: "Load Weight", value: preview.loadWeight)
                RAMSInlineFieldRow(title: "Notes", value: preview.keyNotes)
            }
        }
    }
}

private struct RAMSEmbeddedSectionBodyView: View {
    let bodyModel: RAMSPDFLayoutDocument.EmbeddedSectionBody

    private var hasResourceContent: Bool {
        !bodyModel.plantEquipmentAccess.isEmpty ||
            !bodyModel.specialistTools.isEmpty ||
            !bodyModel.consumables.isEmpty ||
            !bodyModel.materials.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text("RAMS")
                    .font(.system(size: 20, weight: .bold, design: .serif))

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text("Reference: \(bodyModel.reference.rams_displayValue)")
                        .font(.system(size: 11))
                    Text("Date: \(bodyModel.issuedDate.rams_displayValue)")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.secondary)
            }

            RAMSProjectDetailsGrid(fields: bodyModel.projectDetails)

            if !bodyModel.mandatoryPPE.isEmpty {
                RAMSPPEPanel(items: bodyModel.mandatoryPPE)
            }

            if hasResourceContent {
                RAMSResourcesPanel(bodyModel: bodyModel)
            }

            if !bodyModel.workingAtHeightCompetencies.isEmpty {
                RAMSWorkingAtHeightTable(rows: bodyModel.workingAtHeightCompetencies)
            }

            RAMSRiskAssessmentTable(rows: bodyModel.riskAssessmentRows)
            RAMSRiskReviewBand(selectedLevel: bodyModel.riskReviewSelection)
            RAMSMethodStatementPanel(methodStatement: bodyModel.methodStatement)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct RAMSProjectDetailsGrid: View {
    let fields: [RAMSPDFLayoutDocument.KeyValueField]

    private var chunks: [[RAMSPDFLayoutDocument.KeyValueField]] {
        stride(from: 0, to: fields.count, by: 2).map { start in
            Array(fields[start..<min(start + 2, fields.count)])
        }
    }

    var body: some View {
        RAMSBorderedPanel(title: "Project Details", compact: true) {
            if fields.isEmpty {
                Text("-")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(chunks.enumerated()), id: \.offset) { _, row in
                        HStack(alignment: .top, spacing: 8) {
                            ForEach(row) { field in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(field.key)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                    Text(field.value.rams_displayValue)
                                        .font(.system(size: 12))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            if row.count == 1 {
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct RAMSPPEPanel: View {
    let items: [String]

    var body: some View {
        RAMSBorderedPanel(title: "Mandatory PPE", compact: true) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.proSlate900.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
        }
    }
}

private struct RAMSResourcesPanel: View {
    let bodyModel: RAMSPDFLayoutDocument.EmbeddedSectionBody

    private var columns: [GridItem] {
        [
            GridItem(.flexible(minimum: 220), spacing: 8, alignment: .top),
            GridItem(.flexible(minimum: 220), spacing: 8, alignment: .top)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Plant / Tools / Consumables / Materials")
                .font(.system(size: 13, weight: .semibold))

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                RAMSResourceListCard(title: "Plant & Access", items: bodyModel.plantEquipmentAccess)
                RAMSResourceListCard(title: "Specialist Tools", items: bodyModel.specialistTools)
                RAMSResourceListCard(title: "Consumables", items: bodyModel.consumables)
                RAMSResourceListCard(title: "Materials", items: bodyModel.materials)
            }
        }
    }
}

private struct RAMSResourceListCard: View {
    let title: String
    let items: [String]

    private var cleanItems: [String] {
        items
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        RAMSBorderedPanel(title: title, compact: true) {
            if cleanItems.isEmpty {
                Text("-")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(cleanItems, id: \.self) { item in
                        HStack(alignment: .top, spacing: 6) {
                            Text("\u{2022}")
                            Text(item)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .font(.system(size: 12))
                    }
                }
            }
        }
    }
}

private struct RAMSWorkingAtHeightTable: View {
    let rows: [RAMSPDFLayoutDocument.WorkingAtHeightCompetency]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Working-at-Height Competency")
                .font(.system(size: 13, weight: .semibold))

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    RAMSTableHeaderCell("Equipment", width: 180)
                    RAMSTableHeaderCell("Make / Model / Type", width: 170)
                    RAMSTableHeaderCell("Qualifications Needed", width: nil)
                }
                .padding(8)
                .background(Color(uiColor: .secondarySystemBackground))

                Divider()

                ForEach(rows) { row in
                    HStack(alignment: .top, spacing: 8) {
                        RAMSTableBodyCell(row.equipment, width: 180)
                        RAMSTableBodyCell(row.makeModelType.rams_displayValue, width: 170)
                        RAMSTableBodyCell(row.qualificationsNeeded.rams_displayValue, width: nil)
                    }
                    .padding(8)
                    if row.id != rows.last?.id {
                        Divider()
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.black.opacity(0.12), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

private struct RAMSRiskAssessmentTable: View {
    let rows: [RAMSPDFLayoutDocument.RiskAssessmentRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Risk Assessment")
                .font(.system(size: 13, weight: .semibold))

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    RAMSTableHeaderCell("Ref", width: 52)
                    RAMSTableHeaderCell("Hazard", width: 150)
                    RAMSTableHeaderCell("Risk To", width: 100)
                    RAMSTableHeaderCell("Initial Risk", width: 100)
                    RAMSTableHeaderCell("Control Measures", width: 185)
                    RAMSTableHeaderCell("Residual Risk", width: nil)
                }
                .padding(8)
                .background(Color(uiColor: .secondarySystemBackground))

                Divider()

                if rows.isEmpty {
                    HStack {
                        Text("-")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(10)
                } else {
                    ForEach(rows) { row in
                        HStack(alignment: .top, spacing: 8) {
                            RAMSTableBodyCell(row.reference.rams_displayValue, width: 52)
                            RAMSTableBodyCell(row.hazard.rams_displayValue, width: 150)
                            RAMSTableBodyCell(row.riskTo.rams_displayValue, width: 100)
                            RAMSRiskBadgeView(badge: row.initialRisk, width: 100)
                            RAMSTableBodyCell(row.controlMeasures.rams_displayValue, width: 185)
                            RAMSRiskBadgeView(badge: row.residualRisk, width: nil)
                        }
                        .padding(8)
                        if row.id != rows.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.black.opacity(0.12), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

private struct RAMSRiskBadgeView: View {
    let badge: RAMSPDFLayoutDocument.RiskBadge
    let width: CGFloat?

    var body: some View {
        HStack {
            Text(badge.scoreText)
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(badge.level.rams_backgroundColor)
                .foregroundStyle(badge.level.rams_foregroundColor)
                .clipShape(Capsule())
            Spacer(minLength: 0)
        }
        .frame(width: width, alignment: .leading)
    }
}

private struct RAMSRiskReviewBand: View {
    let selectedLevel: RAMSPDFLayoutDocument.RiskLevel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Risk Review")
                .font(.system(size: 13, weight: .semibold))

            HStack(spacing: 6) {
                ForEach(RAMSPDFLayoutDocument.RiskLevel.allCases, id: \.self) { level in
                    VStack(spacing: 4) {
                        Text(level.rawValue)
                            .font(.system(size: 10, weight: .semibold))
                        Text(level == selectedLevel ? "Selected" : " ")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundStyle(level.rams_foregroundColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(level == selectedLevel ? level.rams_backgroundColor : Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(level == selectedLevel ? level.rams_foregroundColor.opacity(0.55) : Color.black.opacity(0.1), lineWidth: 1)
                    )
                }
            }
        }
    }
}

private struct RAMSMethodStatementPanel: View {
    let methodStatement: RAMSPDFLayoutDocument.MethodStatement

    private var columns: [GridItem] {
        [
            GridItem(.flexible(minimum: 220), spacing: 8),
            GridItem(.flexible(minimum: 220), spacing: 8)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Method Statement")
                .font(.system(size: 13, weight: .semibold))

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                RAMSMethodBlockCard(title: "Sequence of Works", text: methodStatement.sequenceOfWorks)
                RAMSMethodBlockCard(title: "Emergency Procedures", text: methodStatement.emergencyProcedures)
                RAMSMethodBlockCard(title: "First Aid", text: methodStatement.firstAid)
            }
        }
    }
}

private struct RAMSMethodBlockCard: View {
    let title: String
    let text: String?

    var body: some View {
        RAMSBorderedPanel(title: title, compact: true) {
            Text(text.rams_displayValue)
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct RAMSAppendicesPanel: View {
    let appendices: [RAMSPDFLayoutDocument.Appendix]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RAMSSectionHeading(title: "Appendices")

            ForEach(appendices) { appendix in
                RAMSAppendixCard(appendix: appendix)
            }
        }
    }
}

private struct RAMSAppendixCard: View {
    let appendix: RAMSPDFLayoutDocument.Appendix

    var body: some View {
        RAMSBorderedPanel(title: appendix.title, compact: true) {
            VStack(alignment: .leading, spacing: 8) {
                if let caption = appendix.caption, !caption.rams_isBlank {
                    Text(caption)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                switch appendix.kind {
                case .image(let data):
                    RAMSAppendixImagePreview(imageData: data)
                case .pdf(let publicURL):
                    RAMSAppendixPDFRow(publicURL: publicURL)
                }
            }
        }
    }
}

private struct RAMSAppendixImagePreview: View {
    let imageData: Data?

    var body: some View {
        if let imageData, let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 210)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                )
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
                .frame(height: 120)
                .overlay {
                    Text("Image unavailable")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
        }
    }
}

private struct RAMSAppendixPDFRow: View {
    let publicURL: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PDF appendix attached")
                .font(.system(size: 12, weight: .semibold))

            if let urlString = publicURL, let url = URL(string: urlString), !urlString.rams_isBlank {
                Link(destination: url) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right.square")
                        Text("Open appendix")
                            .underline()
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.blue)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .foregroundStyle(.secondary)
                    Text("-")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct RAMSSignOffPanel: View {
    let signOff: RAMSPDFLayoutDocument.SignOff

    private var metaLine: String {
        let revision = signOff.revisionLabel.rams_displayValue
        let date = signOff.dateOfIssue.rams_displayValue
        return "Revision: \(revision)    Date: \(date)    Signatures: \(signOff.records.count)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RAMSSectionHeading(title: "Sign-off")

            Text(signOff.explanatoryCopy)
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)

            Text(metaLine)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            RAMSSignOffTable(records: signOff.records)
        }
    }
}

private struct RAMSSignOffTable: View {
    let records: [RAMSPDFLayoutDocument.SignOffRecord]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                RAMSTableHeaderCell("Name", width: 130)
                RAMSTableHeaderCell("Company", width: 130)
                RAMSTableHeaderCell("Email", width: 165)
                RAMSTableHeaderCell("Date", width: 90)
                RAMSTableHeaderCell("Signature", width: nil)
            }
            .padding(8)
            .background(Color(uiColor: .secondarySystemBackground))

            Divider()

            if records.isEmpty {
                HStack {
                    Text("No signatures captured.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(10)
            } else {
                ForEach(records) { record in
                    HStack(alignment: .top, spacing: 8) {
                        RAMSTableBodyCell(record.name.rams_displayValue, width: 130)
                        RAMSTableBodyCell(record.company.rams_displayValue, width: 130)
                        RAMSTableBodyCell(record.email.rams_displayValue, width: 165)
                        RAMSTableBodyCell(record.date.rams_displayValue, width: 90)
                        RAMSSignatureCell(imageData: record.signatureImageData, width: nil)
                    }
                    .padding(8)
                    if record.id != records.last?.id {
                        Divider()
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct RAMSSignatureCell: View {
    let imageData: Data?
    let width: CGFloat?

    var body: some View {
        HStack {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 40)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("-")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: width, alignment: .leading)
    }
}

private struct RAMSTableHeaderCell: View {
    let text: String
    let width: CGFloat?

    init(_ text: String, width: CGFloat?) {
        self.text = text
        self.width = width
    }

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: width, alignment: .leading)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }
}

private struct RAMSTableBodyCell: View {
    let text: String
    let width: CGFloat?

    init(_ text: String, width: CGFloat?) {
        self.text = text
        self.width = width
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: width, alignment: .leading)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }
}

private struct RAMSSectionHeading: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.proSlate900.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: RAMSPDFLayoutStyle.panelCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RAMSPDFLayoutStyle.panelCornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.1), lineWidth: 1)
        )
    }
}

private struct RAMSInlineFieldRow: View {
    let title: String
    let value: String?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title + ":")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 95, alignment: .leading)
            Text(value.rams_displayValue)
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}

private struct RAMSBorderedPanel<Content: View>: View {
    let title: String
    var panelColor: Color = .white
    var borderColor: Color = Color.black.opacity(0.12)
    var compact: Bool = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            Text(title)
                .font(.system(size: compact ? 12 : 13, weight: .semibold))
                .foregroundStyle(Color.proSlate900)
            content()
        }
        .padding(compact ? 10 : 12)
        .background(panelColor)
        .overlay(
            RoundedRectangle(cornerRadius: RAMSPDFLayoutStyle.panelCornerRadius, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: RAMSPDFLayoutStyle.panelCornerRadius, style: .continuous))
    }
}

private extension String {
    var rams_isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var rams_displayValue: String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "-" : trimmed
    }
}

private extension String? {
    var rams_displayValue: String {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return "-"
        }
        return value
    }
}

private extension Bool? {
    var rams_yesNoOrDash: String {
        guard let value = self else { return "-" }
        return value ? "Yes" : "No"
    }
}

private extension RAMSPDFLayoutDocument.RiskLevel {
    var rams_backgroundColor: Color {
        switch self {
        case .veryLow:
            return Color.green.opacity(0.2)
        case .low:
            return Color.mint.opacity(0.2)
        case .medium:
            return Color.yellow.opacity(0.25)
        case .high:
            return Color.orange.opacity(0.25)
        case .veryHigh:
            return Color.red.opacity(0.25)
        }
    }

    var rams_foregroundColor: Color {
        switch self {
        case .veryLow:
            return .green
        case .low:
            return .mint
        case .medium:
            return .yellow.opacity(0.8)
        case .high:
            return .orange
        case .veryHigh:
            return .red
        }
    }
}

struct RAMSPDFLayoutView_Previews: PreviewProvider {
    static var previews: some View {
        RAMSPDFLayoutView(document: mockDocument)
    }

    private static var mockDocument: RAMSPDFLayoutDocument {
        RAMSPDFLayoutDocument(
            header: .init(
                brandTitle: "RAMS Builder Pro",
                subtitle: "Project Master RAMS Document",
                documentReference: "RAMS-UK-02631",
                dateOfIssue: "15 Feb 2026",
                revisionLabel: "Revision B"
            ),
            metadata: .init(
                ramsDocument: "Facade Access & Repairs",
                project: "Camden Exchange Refurbishment",
                projectReference: "CEX-Phase-03",
                expectedDuration: "3 weeks",
                plannedStartDate: "18 Feb 2026",
                plannedStartTime: "07:30",
                projectSiteAddress: "Camden Exchange, London NW1 8AB\nRear service lane via Bay 4."
            ),
            scopeOfWorks: [
                "Establish controlled access to facade working area.",
                "Install and inspect access tower and edge protection.",
                "Carry out brickwork repairs, wash-down and sealant replacement.",
                "Complete end-of-shift housekeeping and permit hand-back."
            ],
            coverDetailCards: [
                .init(
                    title: "Site & Access Setup",
                    fields: [
                        .init(key: "Exact Location", value: "North elevation and loading bay interface."),
                        .init(key: "Access/Egress Requirements", value: "Barriered route, signed one-way pedestrian diversion."),
                        .init(key: "Permits Required", value: "Hot works, work-at-height, access lane closure.")
                    ]
                ),
                .init(
                    title: "Plant & Materials",
                    fields: [
                        .init(key: "Plant / Equipment / Tools", value: "Tower scaffold, SDS drill, breaker, M-Class extractor."),
                        .init(key: "Materials / Hazardous Substances", value: "Resin anchors, sealant, silica dust controls."),
                        .init(key: "Waste Removal", value: "Bagged debris by controlled chute to skip bay.")
                    ]
                ),
                .init(
                    title: "Emergency Fields",
                    fields: [
                        .init(key: "Emergency Rescue", value: "Site rescue team and MEWP standby."),
                        .init(key: "First Aid Point", value: "Ground floor welfare room."),
                        .init(key: "Assembly Point", value: "Car park muster point A.")
                    ]
                ),
                .init(
                    title: "Communication & Monitoring",
                    fields: [
                        .init(key: "Briefed By", value: "Project Supervisor"),
                        .init(key: "Delivery Methods", value: "Toolbox talk, digital briefing, permit induction."),
                        .init(key: "Monitoring Responsible", value: "HSE Lead / Site Manager")
                    ]
                ),
                .init(
                    title: "Legacy Fields",
                    fields: [
                        .init(key: "Amendments Authorised By", value: "Contracts Manager"),
                        .init(key: "Issued To / Reviewed By", value: "Principal Contractor team"),
                        .init(key: "Monitoring Compliance", value: "Daily inspection sheets and closeout log.")
                    ]
                )
            ],
            nearestHospitalMapImageData: sampleImageData(label: "Hospital Map"),
            riskKeywords: ["Work at Height", "Public Interface", "Silica Dust", "Manual Handling", "Traffic Movements"],
            additionalNotes: "All operatives must attend pre-start briefing.\nStop work authority applies to every trade on site.",
            assignedSections: [
                .init(
                    title: "External Repair Operations",
                    reference: "SEC-ER-01",
                    preStartCritical: true,
                    notes: "Scaffold handover certificate must be verified before any loading.",
                    liftingPlanPreview: .init(
                        title: "Panel Lift to Level 2",
                        category: "Routine",
                        craneOrPlant: "Truck-mounted HIAB",
                        loadDescription: "Prefabricated guard panel",
                        loadWeight: "220 kg",
                        keyNotes: "Exclude pedestrian lane during lifting window."
                    ),
                    body: .init(
                        reference: "RAMS-ER-01",
                        issuedDate: "15 Feb 2026",
                        projectDetails: [
                            .init(key: "Project Name", value: "Camden Exchange Refurbishment"),
                            .init(key: "Project Title", value: "Facade Repair and Access"),
                            .init(key: "Reference", value: "CEX-ER-01"),
                            .init(key: "Assessor", value: "A. Johnson"),
                            .init(key: "Supervisor", value: "K. Morgan"),
                            .init(key: "Site Address", value: "Camden Exchange, London NW1 8AB")
                        ],
                        mandatoryPPE: [
                            "Hard Hat",
                            "Safety Boots",
                            "Hi-Vis Vest",
                            "Gloves",
                            "Eye Protection",
                            "FFP3 Mask"
                        ],
                        plantEquipmentAccess: ["Tower scaffold", "Podium steps", "Debris chute"],
                        specialistTools: ["SDS drill", "Torque wrench", "Laser level"],
                        consumables: ["Dust sheets", "P3 filters", "Fixings"],
                        materials: ["Mortar repair mix", "Sealant", "Anchor resin"],
                        workingAtHeightCompetencies: [
                            .init(equipment: "Tower Scaffold", makeModelType: "Youngman Alloy", qualificationsNeeded: "PASMA"),
                            .init(equipment: "Harness & Lanyard", makeModelType: "EN361 / EN355", qualificationsNeeded: "Working at height trained")
                        ],
                        riskAssessmentRows: [
                            .init(
                                reference: "R1",
                                hazard: "Falling objects from height",
                                riskTo: "Operatives / public",
                                initialRisk: .init(scoreText: "16 (H)", level: .high),
                                controlMeasures: "Toe boards and brick guards fitted.\nExclusion zone with banksman supervision.",
                                residualRisk: .init(scoreText: "6 (L)", level: .low)
                            ),
                            .init(
                                reference: "R2",
                                hazard: "Silica dust exposure",
                                riskTo: "Operatives",
                                initialRisk: .init(scoreText: "12 (M)", level: .medium),
                                controlMeasures: "M-Class extraction and FFP3 masks.\nWet cutting where reasonably practicable.",
                                residualRisk: .init(scoreText: "4 (L)", level: .low)
                            )
                        ],
                        riskReviewSelection: .low,
                        methodStatement: .init(
                            sequenceOfWorks: "Set out work area.\nInstall protection and access.\nExecute repair and inspect.\nClear site and sign off permit.",
                            emergencyProcedures: "Raise alarm to site control. Stop works and secure area. Contact emergency services if required.",
                            firstAid: "First aid point in welfare cabin. Qualified first aiders listed on induction board."
                        )
                    )
                ),
                .init(
                    title: "Internal Fit-Out Interface",
                    reference: "SEC-IF-02",
                    preStartCritical: false,
                    notes: nil,
                    body: .init(
                        reference: "RAMS-IF-02",
                        issuedDate: "15 Feb 2026",
                        projectDetails: [
                            .init(key: "Project Name", value: "Camden Exchange Refurbishment"),
                            .init(key: "Task", value: "Internal access control and coordination"),
                            .init(key: "Assessor", value: "A. Johnson"),
                            .init(key: "Supervisor", value: "L. Singh")
                        ],
                        mandatoryPPE: ["Hard Hat", "Safety Boots", "Hi-Vis Vest"],
                        plantEquipmentAccess: ["Mobile barriers"],
                        specialistTools: [],
                        consumables: ["Signage"],
                        materials: [],
                        riskAssessmentRows: [
                            .init(
                                reference: "R3",
                                hazard: "Vehicle and pedestrian interface",
                                riskTo: "Site visitors",
                                initialRisk: .init(scoreText: "15 (H)", level: .high),
                                controlMeasures: "Dedicated marshal and timed deliveries.\nTemporary pedestrian diversion route.",
                                residualRisk: .init(scoreText: "5 (L)", level: .low)
                            )
                        ],
                        riskReviewSelection: .medium,
                        methodStatement: .init(
                            sequenceOfWorks: "Coordinate access windows with logistics team.",
                            emergencyProcedures: "Suspend deliveries and move persons to assembly point.",
                            firstAid: "Escalate via site office and first aid team."
                        )
                    )
                )
            ],
            appendices: [
                .init(
                    title: "Appendix A - Site/Hospital Route Map",
                    caption: "Primary ambulance route from site gate to hospital.",
                    kind: .image(data: sampleImageData(label: "Appendix Map"))
                ),
                .init(
                    title: "Appendix B - Manufacturer Installation Guide",
                    caption: "Reference PDF attached by design team.",
                    kind: .pdf(publicURL: "https://example.com/appendix-b.pdf")
                )
            ],
            signOff: .init(
                explanatoryCopy: "Sign-off confirms RAMS briefing has been completed and controls are understood before work starts.",
                revisionLabel: "Revision B",
                dateOfIssue: "15 Feb 2026",
                records: [
                    .init(
                        name: "Daniel Archer",
                        company: "NorthWest Contractors",
                        email: "daniel.archer@nwc.example",
                        date: "15 Feb 2026",
                        signatureImageData: sampleSignatureData()
                    ),
                    .init(
                        name: "Mia Patel",
                        company: "Camden Exchange PM",
                        email: "mia.patel@camdenx.example",
                        date: "15 Feb 2026",
                        signatureImageData: nil
                    )
                ]
            )
        )
    }

    private static func sampleImageData(label: String) -> Data? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 500, height: 320))
        let image = renderer.image { context in
            UIColor.systemGray6.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 500, height: 320))

            UIColor.systemGray4.setStroke()
            context.cgContext.setLineWidth(2)
            context.cgContext.stroke(CGRect(x: 14, y: 14, width: 472, height: 292))

            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .semibold),
                .foregroundColor: UIColor.systemGray
            ]
            let text = NSString(string: label)
            text.draw(at: CGPoint(x: 24, y: 140), withAttributes: attrs)
        }
        return image.pngData()
    }

    private static func sampleSignatureData() -> Data? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 220, height: 70))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 220, height: 70))

            UIColor.black.setStroke()
            context.cgContext.setLineWidth(2)
            context.cgContext.move(to: CGPoint(x: 8, y: 52))
            context.cgContext.addCurve(
                to: CGPoint(x: 210, y: 34),
                control1: CGPoint(x: 60, y: 18),
                control2: CGPoint(x: 150, y: 72)
            )
            context.cgContext.strokePath()
        }
        return image.pngData()
    }
}
