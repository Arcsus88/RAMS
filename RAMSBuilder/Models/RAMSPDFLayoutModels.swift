import Foundation

struct RAMSPDFLayoutDocument: Identifiable, Hashable {
    struct Header: Hashable {
        var brandTitle: String
        var subtitle: String
        var documentReference: String?
        var dateOfIssue: String?
        var revisionLabel: String?
    }

    struct Metadata: Hashable {
        var ramsDocument: String?
        var project: String?
        var projectReference: String?
        var expectedDuration: String?
        var plannedStartDate: String?
        var plannedStartTime: String?
        var projectSiteAddress: String?
    }

    struct KeyValueField: Identifiable, Hashable {
        var id: UUID
        var key: String
        var value: String?

        init(id: UUID = UUID(), key: String, value: String?) {
            self.id = id
            self.key = key
            self.value = value
        }
    }

    struct CoverDetailCard: Identifiable, Hashable {
        var id: UUID
        var title: String
        var fields: [KeyValueField]

        init(id: UUID = UUID(), title: String, fields: [KeyValueField]) {
            self.id = id
            self.title = title
            self.fields = fields
        }
    }

    struct ContentsEntry: Identifiable, Hashable {
        var id: UUID
        var number: Int
        var section: String
        var reference: String?
        var preStartCritical: Bool?
        var notes: String?

        init(
            id: UUID = UUID(),
            number: Int,
            section: String,
            reference: String? = nil,
            preStartCritical: Bool? = nil,
            notes: String? = nil
        ) {
            self.id = id
            self.number = number
            self.section = section
            self.reference = reference
            self.preStartCritical = preStartCritical
            self.notes = notes
        }
    }

    struct LiftingPlanPreview: Hashable {
        var title: String?
        var category: String?
        var craneOrPlant: String?
        var loadDescription: String?
        var loadWeight: String?
        var keyNotes: String?
    }

    enum RiskLevel: String, CaseIterable, Hashable {
        case veryLow = "Very Low"
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case veryHigh = "Very High"
    }

    struct RiskBadge: Hashable {
        var scoreText: String
        var level: RiskLevel
    }

    struct WorkingAtHeightCompetency: Identifiable, Hashable {
        var id: UUID
        var equipment: String
        var makeModelType: String?
        var qualificationsNeeded: String?

        init(
            id: UUID = UUID(),
            equipment: String,
            makeModelType: String? = nil,
            qualificationsNeeded: String? = nil
        ) {
            self.id = id
            self.equipment = equipment
            self.makeModelType = makeModelType
            self.qualificationsNeeded = qualificationsNeeded
        }
    }

    struct RiskAssessmentRow: Identifiable, Hashable {
        var id: UUID
        var reference: String?
        var hazard: String?
        var riskTo: String?
        var initialRisk: RiskBadge
        var controlMeasures: String?
        var residualRisk: RiskBadge

        init(
            id: UUID = UUID(),
            reference: String? = nil,
            hazard: String? = nil,
            riskTo: String? = nil,
            initialRisk: RiskBadge,
            controlMeasures: String? = nil,
            residualRisk: RiskBadge
        ) {
            self.id = id
            self.reference = reference
            self.hazard = hazard
            self.riskTo = riskTo
            self.initialRisk = initialRisk
            self.controlMeasures = controlMeasures
            self.residualRisk = residualRisk
        }
    }

    struct MethodStatement: Hashable {
        var sequenceOfWorks: String?
        var emergencyProcedures: String?
        var firstAid: String?
    }

    struct EmbeddedSectionBody: Hashable {
        var reference: String?
        var issuedDate: String?
        var projectDetails: [KeyValueField]
        var mandatoryPPE: [String]
        var plantEquipmentAccess: [String]
        var specialistTools: [String]
        var consumables: [String]
        var materials: [String]
        var workingAtHeightCompetencies: [WorkingAtHeightCompetency]
        var riskAssessmentRows: [RiskAssessmentRow]
        var riskReviewSelection: RiskLevel
        var methodStatement: MethodStatement

        init(
            reference: String? = nil,
            issuedDate: String? = nil,
            projectDetails: [KeyValueField] = [],
            mandatoryPPE: [String] = [],
            plantEquipmentAccess: [String] = [],
            specialistTools: [String] = [],
            consumables: [String] = [],
            materials: [String] = [],
            workingAtHeightCompetencies: [WorkingAtHeightCompetency] = [],
            riskAssessmentRows: [RiskAssessmentRow] = [],
            riskReviewSelection: RiskLevel = .low,
            methodStatement: MethodStatement = .init()
        ) {
            self.reference = reference
            self.issuedDate = issuedDate
            self.projectDetails = projectDetails
            self.mandatoryPPE = mandatoryPPE
            self.plantEquipmentAccess = plantEquipmentAccess
            self.specialistTools = specialistTools
            self.consumables = consumables
            self.materials = materials
            self.workingAtHeightCompetencies = workingAtHeightCompetencies
            self.riskAssessmentRows = riskAssessmentRows
            self.riskReviewSelection = riskReviewSelection
            self.methodStatement = methodStatement
        }
    }

    struct AssignedSection: Identifiable, Hashable {
        var id: UUID
        var isActive: Bool
        var title: String
        var reference: String?
        var preStartCritical: Bool
        var notes: String?
        var liftingPlanPreview: LiftingPlanPreview?
        var body: EmbeddedSectionBody

        init(
            id: UUID = UUID(),
            isActive: Bool = true,
            title: String,
            reference: String? = nil,
            preStartCritical: Bool = false,
            notes: String? = nil,
            liftingPlanPreview: LiftingPlanPreview? = nil,
            body: EmbeddedSectionBody
        ) {
            self.id = id
            self.isActive = isActive
            self.title = title
            self.reference = reference
            self.preStartCritical = preStartCritical
            self.notes = notes
            self.liftingPlanPreview = liftingPlanPreview
            self.body = body
        }
    }

    struct Appendix: Identifiable, Hashable {
        enum Kind: Hashable {
            case image(data: Data?)
            case pdf(publicURL: String?)
        }

        var id: UUID
        var title: String
        var caption: String?
        var kind: Kind

        init(id: UUID = UUID(), title: String, caption: String? = nil, kind: Kind) {
            self.id = id
            self.title = title
            self.caption = caption
            self.kind = kind
        }
    }

    struct SignOffRecord: Identifiable, Hashable {
        var id: UUID
        var name: String?
        var company: String?
        var email: String?
        var date: String?
        var signatureImageData: Data?

        init(
            id: UUID = UUID(),
            name: String? = nil,
            company: String? = nil,
            email: String? = nil,
            date: String? = nil,
            signatureImageData: Data? = nil
        ) {
            self.id = id
            self.name = name
            self.company = company
            self.email = email
            self.date = date
            self.signatureImageData = signatureImageData
        }
    }

    struct SignOff: Hashable {
        var explanatoryCopy: String
        var revisionLabel: String?
        var dateOfIssue: String?
        var records: [SignOffRecord]
    }

    var id: UUID
    var header: Header
    var metadata: Metadata
    var scopeOfWorks: [String]
    var coverDetailCards: [CoverDetailCard]
    var nearestHospitalMapImageData: Data?
    var riskKeywords: [String]
    var additionalNotes: String?
    var contentsEntries: [ContentsEntry]
    var assignedSections: [AssignedSection]
    var appendices: [Appendix]
    var signOff: SignOff

    init(
        id: UUID = UUID(),
        header: Header,
        metadata: Metadata,
        scopeOfWorks: [String] = [],
        coverDetailCards: [CoverDetailCard] = [],
        nearestHospitalMapImageData: Data? = nil,
        riskKeywords: [String] = [],
        additionalNotes: String? = nil,
        contentsEntries: [ContentsEntry] = [],
        assignedSections: [AssignedSection] = [],
        appendices: [Appendix] = [],
        signOff: SignOff
    ) {
        self.id = id
        self.header = header
        self.metadata = metadata
        self.scopeOfWorks = scopeOfWorks
        self.coverDetailCards = coverDetailCards
        self.nearestHospitalMapImageData = nearestHospitalMapImageData
        self.riskKeywords = riskKeywords
        self.additionalNotes = additionalNotes
        self.contentsEntries = contentsEntries
        self.assignedSections = assignedSections
        self.appendices = appendices
        self.signOff = signOff
    }
}

