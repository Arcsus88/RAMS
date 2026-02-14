import Foundation

protocol SchemaValidatable {
    func validate() throws
}

enum SchemaValidationError: Error, Equatable, LocalizedError {
    case requiredFieldMissing(String)
    case stringTooShort(field: String, minimum: Int)
    case stringTooLong(field: String, maximum: Int)
    case arrayTooLarge(field: String, maximum: Int)
    case invalidURL(field: String)
    case integerOutOfRange(field: String, minimum: Int, maximum: Int)
    case integerTooSmall(field: String, minimum: Int)

    var errorDescription: String? {
        switch self {
        case let .requiredFieldMissing(field):
            return "\(field) is required."
        case let .stringTooShort(field, minimum):
            return "\(field) must be at least \(minimum) character(s)."
        case let .stringTooLong(field, maximum):
            return "\(field) must be at most \(maximum) character(s)."
        case let .arrayTooLarge(field, maximum):
            return "\(field) must contain at most \(maximum) item(s)."
        case let .invalidURL(field):
            return "\(field) must be a valid URL."
        case let .integerOutOfRange(field, minimum, maximum):
            return "\(field) must be between \(minimum) and \(maximum)."
        case let .integerTooSmall(field, minimum):
            return "\(field) must be at least \(minimum)."
        }
    }
}

private enum SchemaValidation {
    static func requiredString(_ value: String, field: String, min: Int = 1, max: Int) throws {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty {
            throw SchemaValidationError.requiredFieldMissing(field)
        }
        if cleaned.count < min {
            throw SchemaValidationError.stringTooShort(field: field, minimum: min)
        }
        if cleaned.count > max {
            throw SchemaValidationError.stringTooLong(field: field, maximum: max)
        }
    }

    static func optionalString(_ value: String?, field: String, minWhenPresent: Int = 1, max: Int) throws {
        guard let value else { return }
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count < minWhenPresent {
            throw SchemaValidationError.stringTooShort(field: field, minimum: minWhenPresent)
        }
        if cleaned.count > max {
            throw SchemaValidationError.stringTooLong(field: field, maximum: max)
        }
    }

    static func arrayCount<T>(_ value: [T], field: String, max: Int) throws {
        if value.count > max {
            throw SchemaValidationError.arrayTooLarge(field: field, maximum: max)
        }
    }

    static func requiredStringArray(
        _ value: [String],
        field: String,
        maxCount: Int,
        itemMax: Int? = nil
    ) throws {
        try arrayCount(value, field: field, max: maxCount)
        for (index, item) in value.enumerated() {
            let itemField = "\(field)[\(index)]"
            let cleaned = item.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.isEmpty {
                throw SchemaValidationError.requiredFieldMissing(itemField)
            }
            if let itemMax, cleaned.count > itemMax {
                throw SchemaValidationError.stringTooLong(field: itemField, maximum: itemMax)
            }
        }
    }

    static func optionalStringArray(
        _ value: [String]?,
        field: String,
        maxCount: Int,
        itemMax: Int? = nil
    ) throws {
        guard let value else { return }
        try requiredStringArray(value, field: field, maxCount: maxCount, itemMax: itemMax)
    }

    static func boundedInteger(_ value: Int, field: String, min: Int, max: Int) throws {
        if value < min || value > max {
            throw SchemaValidationError.integerOutOfRange(field: field, minimum: min, maximum: max)
        }
    }

    static func optionalMinimumInteger(_ value: Int?, field: String, minimum: Int) throws {
        guard let value else { return }
        if value < minimum {
            throw SchemaValidationError.integerTooSmall(field: field, minimum: minimum)
        }
    }
}

enum DocumentAndRAMSSchema {
    enum MasterDocumentStatus: String, Codable, CaseIterable {
        case draft = "Draft"
        case issued = "Issued"
        case closed = "Closed"
        case archived = "Archived"
    }

    struct MasterDocumentCreatePayload: Codable, Hashable, SchemaValidatable {
        var projectId: UUID
        var title: String?
        var documentReference: String?

        func validate() throws {
            try SchemaValidation.optionalString(title, field: "MasterDocument.title", minWhenPresent: 1, max: 200)
            try SchemaValidation.optionalString(
                documentReference,
                field: "MasterDocument.documentReference",
                minWhenPresent: 1,
                max: 120
            )
        }
    }

    struct MasterDocumentUpdatePayload: Codable, Hashable, SchemaValidatable {
        var title: String?
        var documentReference: String?
        var status: MasterDocumentStatus?

        func validate() throws {
            try SchemaValidation.optionalString(title, field: "MasterDocument.title", minWhenPresent: 1, max: 200)
            try SchemaValidation.optionalString(
                documentReference,
                field: "MasterDocument.documentReference",
                minWhenPresent: 1,
                max: 120
            )
        }
    }

    struct MasterCoverConfig: Codable, Hashable, SchemaValidatable {
        struct DocumentAppendix: Codable, Hashable, SchemaValidatable {
            var id: String
            var name: String
            var mimeType: String
            var publicUrl: String
            var storagePath: String
            var size: Int
            var uploadedAt: String
            var caption: String?

            func validate() throws {
                try SchemaValidation.requiredString(id, field: "MasterCoverConfig.documentAppendix.id", max: 120)
                try SchemaValidation.requiredString(name, field: "MasterCoverConfig.documentAppendix.name", max: 260)
                try SchemaValidation.requiredString(
                    mimeType,
                    field: "MasterCoverConfig.documentAppendix.mimeType",
                    max: 120
                )
                try SchemaValidation.requiredString(
                    publicUrl,
                    field: "MasterCoverConfig.documentAppendix.publicUrl",
                    max: 4_000
                )
                guard let url = URL(string: publicUrl), url.scheme != nil else {
                    throw SchemaValidationError.invalidURL(field: "MasterCoverConfig.documentAppendix.publicUrl")
                }
                try SchemaValidation.requiredString(
                    storagePath,
                    field: "MasterCoverConfig.documentAppendix.storagePath",
                    max: 2_000
                )
                try SchemaValidation.boundedInteger(
                    size,
                    field: "MasterCoverConfig.documentAppendix.size",
                    min: 0,
                    max: 21_000_000
                )
                try SchemaValidation.requiredString(
                    uploadedAt,
                    field: "MasterCoverConfig.documentAppendix.uploadedAt",
                    max: 80
                )
                try SchemaValidation.optionalString(caption, field: "MasterCoverConfig.documentAppendix.caption", max: 300)
            }
        }

        var projectName: String?
        var projectReference: String?
        var projectSiteAddress: String?
        var projectScopeOfWorks: String?
        var dateOfIssue: String?
        var plannedStartDate: String?
        var plannedStartTime: String?
        var expectedDuration: String?
        var exactLocation: String?
        var attachmentPlan: String?
        var locationPlanAppendices: [DocumentAppendix]?
        var documentPreparedByUserId: String?
        var riskAssessmentsCompletedByUserId: String?
        var personnelUserIds: [String]?
        var siteSupervisorUserId: String?
        var communicationBriefedByUserId: String?
        var communicationRecipientUserIds: [String]?
        var communicationEscalationUserId: String?
        var communicationDeliveryMethods: [String]?
        var plantEquipmentToolsItems: [String]?
        var materialsHazardousSubstancesItems: [String]?
        var attachmentPlanAssetUrl: String?
        var attachmentPlanAssetName: String?
        var attachmentPlanAssetType: String?
        var documentPreparedBy: String?
        var riskAssessmentsCompleted: String?
        var accessEgressRequirements: String?
        var personnelJobTitles: String?
        var siteSupervisor: String?
        var plantEquipmentTools: String?
        var materialsHazardousSubstances: String?
        var drawingsTechnicalInfo: String?
        var wasteRemoval: String?
        var housekeepingStorage: String?
        var permitsRequired: String?
        var permitType: String?
        var permitIssuedBy: String?
        var mandatorySitePpe: String?
        var taskSpecificPpe: String?
        var nearestHospital: String?
        var nearestHospitalMapImage: String?
        var emergencyRescue: String?
        var emergencyRescueFromHeight: String?
        var emergencyFirstAidPoint: String?
        var emergencyQualifiedFirstAiders: String?
        var emergencyFireSafetyArrangements: String?
        var emergencyAssemblyPoints: String?
        var awarenessCommunication: String?
        var monitoringResponsiblePerson: String?
        var havNoiseResponsiblePerson: String?
        var amendmentsAuthorisedBy: String?
        var issuedToReviewedBy: String?
        var emergencyArrangements: String?
        var responsibilities: String?
        var monitoringCompliance: String?
        var keyRiskKeywords: String?
        var minimumRiskAssessments: String?
        var additionalNotes: String?

        func validate() throws {
            try SchemaValidation.optionalString(projectName, field: "MasterCoverConfig.projectName", max: 240)
            try SchemaValidation.optionalString(projectReference, field: "MasterCoverConfig.projectReference", max: 120)
            try SchemaValidation.optionalString(projectSiteAddress, field: "MasterCoverConfig.projectSiteAddress", max: 1_500)
            try SchemaValidation.optionalString(projectScopeOfWorks, field: "MasterCoverConfig.projectScopeOfWorks", max: 20_000)
            try SchemaValidation.optionalString(dateOfIssue, field: "MasterCoverConfig.dateOfIssue", max: 40)
            try SchemaValidation.optionalString(plannedStartDate, field: "MasterCoverConfig.plannedStartDate", max: 40)
            try SchemaValidation.optionalString(plannedStartTime, field: "MasterCoverConfig.plannedStartTime", max: 40)
            try SchemaValidation.optionalString(expectedDuration, field: "MasterCoverConfig.expectedDuration", max: 255)
            try SchemaValidation.optionalString(exactLocation, field: "MasterCoverConfig.exactLocation", max: 3_000)
            try SchemaValidation.optionalString(attachmentPlan, field: "MasterCoverConfig.attachmentPlan", max: 3_000)

            if let locationPlanAppendices {
                try SchemaValidation.arrayCount(
                    locationPlanAppendices,
                    field: "MasterCoverConfig.locationPlanAppendices",
                    max: 50
                )
                try locationPlanAppendices.forEach { try $0.validate() }
            }

            try SchemaValidation.optionalString(
                documentPreparedByUserId,
                field: "MasterCoverConfig.documentPreparedByUserId",
                max: 80
            )
            try SchemaValidation.optionalString(
                riskAssessmentsCompletedByUserId,
                field: "MasterCoverConfig.riskAssessmentsCompletedByUserId",
                max: 80
            )
            try SchemaValidation.optionalStringArray(
                personnelUserIds,
                field: "MasterCoverConfig.personnelUserIds",
                maxCount: 200,
                itemMax: 80
            )
            try SchemaValidation.optionalString(siteSupervisorUserId, field: "MasterCoverConfig.siteSupervisorUserId", max: 80)
            try SchemaValidation.optionalString(
                communicationBriefedByUserId,
                field: "MasterCoverConfig.communicationBriefedByUserId",
                max: 80
            )
            try SchemaValidation.optionalStringArray(
                communicationRecipientUserIds,
                field: "MasterCoverConfig.communicationRecipientUserIds",
                maxCount: 200,
                itemMax: 80
            )
            try SchemaValidation.optionalString(
                communicationEscalationUserId,
                field: "MasterCoverConfig.communicationEscalationUserId",
                max: 80
            )
            try SchemaValidation.optionalStringArray(
                communicationDeliveryMethods,
                field: "MasterCoverConfig.communicationDeliveryMethods",
                maxCount: 40
            )
            try SchemaValidation.optionalStringArray(
                plantEquipmentToolsItems,
                field: "MasterCoverConfig.plantEquipmentToolsItems",
                maxCount: 160
            )
            try SchemaValidation.optionalStringArray(
                materialsHazardousSubstancesItems,
                field: "MasterCoverConfig.materialsHazardousSubstancesItems",
                maxCount: 160
            )

            try SchemaValidation.optionalString(attachmentPlanAssetUrl, field: "MasterCoverConfig.attachmentPlanAssetUrl", max: 4_000)
            try SchemaValidation.optionalString(attachmentPlanAssetName, field: "MasterCoverConfig.attachmentPlanAssetName", max: 255)
            try SchemaValidation.optionalString(attachmentPlanAssetType, field: "MasterCoverConfig.attachmentPlanAssetType", max: 120)
            try SchemaValidation.optionalString(documentPreparedBy, field: "MasterCoverConfig.documentPreparedBy", max: 500)
            try SchemaValidation.optionalString(riskAssessmentsCompleted, field: "MasterCoverConfig.riskAssessmentsCompleted", max: 500)

            try SchemaValidation.optionalString(
                accessEgressRequirements,
                field: "MasterCoverConfig.accessEgressRequirements",
                max: 12_000
            )
            try SchemaValidation.optionalString(personnelJobTitles, field: "MasterCoverConfig.personnelJobTitles", max: 6_000)
            try SchemaValidation.optionalString(siteSupervisor, field: "MasterCoverConfig.siteSupervisor", max: 6_000)
            try SchemaValidation.optionalString(plantEquipmentTools, field: "MasterCoverConfig.plantEquipmentTools", max: 12_000)
            try SchemaValidation.optionalString(
                materialsHazardousSubstances,
                field: "MasterCoverConfig.materialsHazardousSubstances",
                max: 12_000
            )
            try SchemaValidation.optionalString(drawingsTechnicalInfo, field: "MasterCoverConfig.drawingsTechnicalInfo", max: 12_000)
            try SchemaValidation.optionalString(wasteRemoval, field: "MasterCoverConfig.wasteRemoval", max: 12_000)
            try SchemaValidation.optionalString(housekeepingStorage, field: "MasterCoverConfig.housekeepingStorage", max: 12_000)
            try SchemaValidation.optionalString(permitsRequired, field: "MasterCoverConfig.permitsRequired", max: 4_000)
            try SchemaValidation.optionalString(permitType, field: "MasterCoverConfig.permitType", max: 6_000)
            try SchemaValidation.optionalString(permitIssuedBy, field: "MasterCoverConfig.permitIssuedBy", max: 6_000)
            try SchemaValidation.optionalString(mandatorySitePpe, field: "MasterCoverConfig.mandatorySitePpe", max: 12_000)
            try SchemaValidation.optionalString(taskSpecificPpe, field: "MasterCoverConfig.taskSpecificPpe", max: 12_000)
            try SchemaValidation.optionalString(nearestHospital, field: "MasterCoverConfig.nearestHospital", max: 1_200)
            try SchemaValidation.optionalString(
                nearestHospitalMapImage,
                field: "MasterCoverConfig.nearestHospitalMapImage",
                max: 4_000_000
            )

            try SchemaValidation.optionalString(emergencyRescue, field: "MasterCoverConfig.emergencyRescue", max: 12_000)
            try SchemaValidation.optionalString(
                emergencyRescueFromHeight,
                field: "MasterCoverConfig.emergencyRescueFromHeight",
                max: 12_000
            )
            try SchemaValidation.optionalString(emergencyFirstAidPoint, field: "MasterCoverConfig.emergencyFirstAidPoint", max: 12_000)
            try SchemaValidation.optionalString(
                emergencyQualifiedFirstAiders,
                field: "MasterCoverConfig.emergencyQualifiedFirstAiders",
                max: 12_000
            )
            try SchemaValidation.optionalString(
                emergencyFireSafetyArrangements,
                field: "MasterCoverConfig.emergencyFireSafetyArrangements",
                max: 12_000
            )
            try SchemaValidation.optionalString(emergencyAssemblyPoints, field: "MasterCoverConfig.emergencyAssemblyPoints", max: 12_000)
            try SchemaValidation.optionalString(awarenessCommunication, field: "MasterCoverConfig.awarenessCommunication", max: 12_000)
            try SchemaValidation.optionalString(
                monitoringResponsiblePerson,
                field: "MasterCoverConfig.monitoringResponsiblePerson",
                max: 12_000
            )
            try SchemaValidation.optionalString(
                havNoiseResponsiblePerson,
                field: "MasterCoverConfig.havNoiseResponsiblePerson",
                max: 12_000
            )
            try SchemaValidation.optionalString(
                amendmentsAuthorisedBy,
                field: "MasterCoverConfig.amendmentsAuthorisedBy",
                max: 12_000
            )
            try SchemaValidation.optionalString(issuedToReviewedBy, field: "MasterCoverConfig.issuedToReviewedBy", max: 12_000)
            try SchemaValidation.optionalString(emergencyArrangements, field: "MasterCoverConfig.emergencyArrangements", max: 12_000)
            try SchemaValidation.optionalString(responsibilities, field: "MasterCoverConfig.responsibilities", max: 12_000)
            try SchemaValidation.optionalString(monitoringCompliance, field: "MasterCoverConfig.monitoringCompliance", max: 12_000)
            try SchemaValidation.optionalString(keyRiskKeywords, field: "MasterCoverConfig.keyRiskKeywords", max: 4_000)
            try SchemaValidation.optionalString(minimumRiskAssessments, field: "MasterCoverConfig.minimumRiskAssessments", max: 12_000)
            try SchemaValidation.optionalString(additionalNotes, field: "MasterCoverConfig.additionalNotes", max: 12_000)
        }
    }

    enum MasterTemplateStatus: String, Codable, CaseIterable {
        case active = "Active"
        case archived = "Archived"
    }

    enum JSONValue: Codable, Hashable {
        case string(String)
        case number(Double)
        case bool(Bool)
        case object([String: JSONValue])
        case array([JSONValue])
        case null

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()

            if container.decodeNil() {
                self = .null
            } else if let value = try? container.decode(Bool.self) {
                self = .bool(value)
            } else if let value = try? container.decode(Double.self) {
                self = .number(value)
            } else if let value = try? container.decode(String.self) {
                self = .string(value)
            } else if let value = try? container.decode([String: JSONValue].self) {
                self = .object(value)
            } else if let value = try? container.decode([JSONValue].self) {
                self = .array(value)
            } else {
                throw DecodingError.typeMismatch(
                    JSONValue.self,
                    .init(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON value")
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case let .string(value):
                try container.encode(value)
            case let .number(value):
                try container.encode(value)
            case let .bool(value):
                try container.encode(value)
            case let .object(value):
                try container.encode(value)
            case let .array(value):
                try container.encode(value)
            case .null:
                try container.encodeNil()
            }
        }
    }

    struct MasterTemplateSection: Codable, Hashable, SchemaValidatable {
        var sourceRamsLibraryId: UUID?
        var sectionTitle: String
        var sectionReference: String?
        var displayOrder: Int?
        var active: Bool?
        var preStartCritical: Bool?
        var requiresLiftingPlan: Bool?
        var notes: String?
        var liftingPlan: [String: JSONValue]?

        func validate() throws {
            try SchemaValidation.requiredString(sectionTitle, field: "MasterTemplate.sections.sectionTitle", min: 1, max: 200)
            try SchemaValidation.optionalString(sectionReference, field: "MasterTemplate.sections.sectionReference", max: 120)
            try SchemaValidation.optionalMinimumInteger(displayOrder, field: "MasterTemplate.sections.displayOrder", minimum: 0)
            try SchemaValidation.optionalString(notes, field: "MasterTemplate.sections.notes", max: 4_000)
        }
    }

    struct MasterTemplateCreatePayload: Codable, Hashable, SchemaValidatable {
        var title: String
        var description: String?
        var coverConfig: MasterCoverConfig
        var sections: [MasterTemplateSection]

        func validate() throws {
            try SchemaValidation.requiredString(title, field: "MasterTemplate.title", min: 1, max: 200)
            try SchemaValidation.optionalString(description, field: "MasterTemplate.description", max: 2_000)
            try coverConfig.validate()
            try sections.forEach { try $0.validate() }
        }
    }

    struct MasterTemplateUpdatePayload: Codable, Hashable, SchemaValidatable {
        var title: String?
        var description: String?
        var status: MasterTemplateStatus?
        var coverConfig: MasterCoverConfig?
        var sections: [MasterTemplateSection]?

        func validate() throws {
            try SchemaValidation.optionalString(title, field: "MasterTemplate.title", minWhenPresent: 1, max: 200)
            try SchemaValidation.optionalString(description, field: "MasterTemplate.description", max: 2_000)
            try coverConfig?.validate()
            if let sections {
                try sections.forEach { try $0.validate() }
            }
        }
    }

    struct RAMS: Codable, Hashable, SchemaValidatable {
        struct ProjectDetails: Codable, Hashable, SchemaValidatable {
            var projectName: String
            var projectTitle: String
            var reference: String
            var date: String
            var siteAddress: String
            var assessor: String
            var supervisor: String
            var description: String

            func validate() throws {
                try SchemaValidation.requiredString(projectName, field: "RAMS.projectDetails.projectName", min: 1, max: 200)
                try SchemaValidation.requiredString(projectTitle, field: "RAMS.projectDetails.projectTitle", max: 200)
                try SchemaValidation.requiredString(reference, field: "RAMS.projectDetails.reference", max: 120)
                try SchemaValidation.requiredString(date, field: "RAMS.projectDetails.date", max: 30)
                try SchemaValidation.requiredString(siteAddress, field: "RAMS.projectDetails.siteAddress", max: 500)
                try SchemaValidation.requiredString(assessor, field: "RAMS.projectDetails.assessor", max: 200)
                try SchemaValidation.requiredString(supervisor, field: "RAMS.projectDetails.supervisor", max: 200)
                try SchemaValidation.requiredString(description, field: "RAMS.projectDetails.description", max: 4_000)
            }
        }

        struct WorkingAtHeightEquipmentDetail: Codable, Hashable, SchemaValidatable {
            var equipment: String
            var makeModelType: String?
            var qualificationsNeeded: String?

            func validate() throws {
                try SchemaValidation.requiredString(
                    equipment,
                    field: "RAMS.workingAtHeightEquipmentDetails.equipment",
                    min: 1,
                    max: 120
                )
                try SchemaValidation.optionalString(
                    makeModelType,
                    field: "RAMS.workingAtHeightEquipmentDetails.makeModelType",
                    max: 240
                )
                try SchemaValidation.optionalString(
                    qualificationsNeeded,
                    field: "RAMS.workingAtHeightEquipmentDetails.qualificationsNeeded",
                    max: 240
                )
            }
        }

        struct MethodStatement: Codable, Hashable, SchemaValidatable {
            var sequence: String?
            var emergencyProcedures: String?
            var firstAid: String?

            func validate() throws {
                try SchemaValidation.optionalString(sequence, field: "RAMS.methodStatement.sequence", max: 10_000)
                try SchemaValidation.optionalString(
                    emergencyProcedures,
                    field: "RAMS.methodStatement.emergencyProcedures",
                    max: 6_000
                )
                try SchemaValidation.optionalString(firstAid, field: "RAMS.methodStatement.firstAid", max: 6_000)
            }
        }

        var projectDetails: ProjectDetails
        var selectedPPE: [String]
        var plantEquipmentAccess: [String]
        var workingAtHeightEquipmentDetails: [WorkingAtHeightEquipmentDetail]
        var specialistTools: [String]
        var consumables: [String]
        var materials: [String]
        var hazards: [Hazard]
        var methodStatement: MethodStatement
        var category: String?
        var tags: [String]?

        func validate() throws {
            try projectDetails.validate()
            try SchemaValidation.requiredStringArray(selectedPPE, field: "RAMS.selectedPPE", maxCount: 50)
            try SchemaValidation.requiredStringArray(plantEquipmentAccess, field: "RAMS.plantEquipmentAccess", maxCount: 100)

            try SchemaValidation.arrayCount(
                workingAtHeightEquipmentDetails,
                field: "RAMS.workingAtHeightEquipmentDetails",
                max: 100
            )
            try workingAtHeightEquipmentDetails.forEach { try $0.validate() }

            try SchemaValidation.requiredStringArray(specialistTools, field: "RAMS.specialistTools", maxCount: 100)
            try SchemaValidation.requiredStringArray(consumables, field: "RAMS.consumables", maxCount: 100)
            try SchemaValidation.requiredStringArray(materials, field: "RAMS.materials", maxCount: 100)

            try SchemaValidation.arrayCount(hazards, field: "RAMS.hazards", max: 250)
            try hazards.forEach { try $0.validate() }

            try methodStatement.validate()
            try SchemaValidation.optionalString(category, field: "RAMS.category", max: 120)
            try SchemaValidation.optionalStringArray(tags, field: "RAMS.tags", maxCount: 25, itemMax: 50)
        }
    }

    struct Hazard: Codable, Hashable, SchemaValidatable {
        var id: Int?
        var activity: String
        var hazard: String
        var personsAtRisk: String
        var initL: Int
        var initS: Int
        var controls: String
        var resL: Int
        var resS: Int

        func validate() throws {
            try SchemaValidation.requiredString(activity, field: "Hazard.activity", max: 500)
            try SchemaValidation.requiredString(hazard, field: "Hazard.hazard", max: 2_000)
            try SchemaValidation.requiredString(personsAtRisk, field: "Hazard.personsAtRisk", max: 500)
            try SchemaValidation.boundedInteger(initL, field: "Hazard.initL", min: 1, max: 5)
            try SchemaValidation.boundedInteger(initS, field: "Hazard.initS", min: 1, max: 5)
            try SchemaValidation.requiredString(controls, field: "Hazard.controls", max: 4_000)
            try SchemaValidation.boundedInteger(resL, field: "Hazard.resL", min: 1, max: 5)
            try SchemaValidation.boundedInteger(resS, field: "Hazard.resS", min: 1, max: 5)
        }
    }
}
