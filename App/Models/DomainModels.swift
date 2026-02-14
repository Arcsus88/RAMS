import Foundation

enum RiskReview: String, Codable, CaseIterable, Identifiable {
    case veryLow = "<L"
    case low = "L"
    case medium = "M"
    case high = "H"
    case veryHigh = "!"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .veryLow:
            return "Very Low"
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        case .veryHigh:
            return "Very High"
        }
    }
}

enum RiskScoreMatrix {
    static func review(for score: Int) -> RiskReview {
        switch score {
        case ..<4:
            return .veryLow
        case 4...6:
            return .low
        case 7...12:
            return .medium
        case 13...19:
            return .high
        default:
            return .veryHigh
        }
    }
}

struct RiskAssessment: Identifiable, Codable, Hashable {
    var id: UUID
    var hazardTitle: String
    var riskTo: String
    var controlMeasures: [String]
    var initialLikelihood: Int
    var initialSeverity: Int
    var residualLikelihood: Int
    var residualSeverity: Int

    var initialScore: Int { initialLikelihood * initialSeverity }
    var residualScore: Int { residualLikelihood * residualSeverity }
    var overallReview: RiskReview { RiskScoreMatrix.review(for: residualScore) }

    init(
        id: UUID = UUID(),
        hazardTitle: String = "",
        riskTo: String = "",
        controlMeasures: [String] = [],
        initialLikelihood: Int = 3,
        initialSeverity: Int = 3,
        residualLikelihood: Int = 2,
        residualSeverity: Int = 2
    ) {
        self.id = id
        self.hazardTitle = hazardTitle
        self.riskTo = riskTo
        self.controlMeasures = controlMeasures
        self.initialLikelihood = initialLikelihood
        self.initialSeverity = initialSeverity
        self.residualLikelihood = residualLikelihood
        self.residualSeverity = residualSeverity
    }
}

struct MethodStatementStep: Identifiable, Codable, Hashable {
    var id: UUID
    var sequence: Int
    var title: String
    var details: String

    init(id: UUID = UUID(), sequence: Int, title: String, details: String) {
        self.id = id
        self.sequence = sequence
        self.title = title
        self.details = details
    }
}

struct HazardTemplate: Identifiable, Codable, Hashable {
    var id: UUID
    var category: String
    var title: String
    var riskToDefault: String
    var controlMeasuresDefault: [String]
    var defaultInitialLikelihood: Int
    var defaultInitialSeverity: Int
    var defaultResidualLikelihood: Int
    var defaultResidualSeverity: Int

    func makeAssessment() -> RiskAssessment {
        RiskAssessment(
            hazardTitle: title,
            riskTo: riskToDefault,
            controlMeasures: controlMeasuresDefault,
            initialLikelihood: defaultInitialLikelihood,
            initialSeverity: defaultInitialSeverity,
            residualLikelihood: defaultResidualLikelihood,
            residualSeverity: defaultResidualSeverity
        )
    }
}

enum PPEItemID: String, Codable, CaseIterable, Identifiable {
    case hardhat
    case boots
    case vest
    case gloves
    case glasses
    case mask
    case ear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hardhat:
            return "Hard Hat"
        case .boots:
            return "Safety Boots"
        case .vest:
            return "Hi-Vis Vest"
        case .gloves:
            return "Gloves"
        case .glasses:
            return "Eye Protection"
        case .mask:
            return "Dust Mask (FFP3)"
        case .ear:
            return "Ear Protection"
        }
    }

    var emoji: String {
        switch self {
        case .hardhat:
            return "👷"
        case .boots:
            return "🥾"
        case .vest:
            return "🦺"
        case .gloves:
            return "🧤"
        case .glasses:
            return "🥽"
        case .mask:
            return "😷"
        case .ear:
            return "🎧"
        }
    }
}

struct KeyContact: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var role: String
    var phone: String

    init(id: UUID = UUID(), name: String = "", role: String = "", phone: String = "") {
        self.id = id
        self.name = name
        self.role = role
        self.phone = phone
    }
}

struct MasterDocument: Identifiable, Codable, Hashable {
    var id: UUID
    var projectName: String
    var siteAddress: String
    var clientName: String
    var principalContractor: String
    var emergencyContactName: String
    var emergencyContactPhone: String
    var nearestHospitalName: String
    var nearestHospitalAddress: String
    var hospitalDirections: String
    var mapImageData: Data?
    var keyContacts: [KeyContact]
    var createdAt: Date
    var updatedAt: Date

    static func draft() -> MasterDocument {
        MasterDocument(
            id: UUID(),
            projectName: "",
            siteAddress: "",
            clientName: "",
            principalContractor: "",
            emergencyContactName: "",
            emergencyContactPhone: "",
            nearestHospitalName: "",
            nearestHospitalAddress: "",
            hospitalDirections: "",
            mapImageData: nil,
            keyContacts: [KeyContact(name: "", role: "", phone: "")],
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

struct RamsDocument: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var referenceCode: String
    var scopeOfWorks: String
    var preparedBy: String
    var approvedBy: String
    var methodStatements: [MethodStatementStep]
    var requiredPPE: [PPEItemID]
    var riskAssessments: [RiskAssessment]
    var emergencyFirstAidStation: String
    var emergencyAssemblyPoint: String
    var emergencyContact: String
    var requiresLiftingPlan: Bool
    var signatureTable: [SignatureRecord]
    var createdAt: Date
    var updatedAt: Date

    var overallRiskReview: RiskReview {
        let highestResidual = riskAssessments.map(\.residualScore).max() ?? 0
        return RiskScoreMatrix.review(for: highestResidual)
    }

    init(
        id: UUID = UUID(),
        title: String = "",
        referenceCode: String = "",
        scopeOfWorks: String = "",
        preparedBy: String = "",
        approvedBy: String = "",
        methodStatements: [MethodStatementStep] = [MethodStatementStep(sequence: 1, title: "", details: "")],
        requiredPPE: [PPEItemID] = [],
        riskAssessments: [RiskAssessment] = [],
        emergencyFirstAidStation: String = "Main site office",
        emergencyAssemblyPoint: String = "Main Gate",
        emergencyContact: String = "",
        requiresLiftingPlan: Bool = false,
        signatureTable: [SignatureRecord] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.referenceCode = referenceCode
        self.scopeOfWorks = scopeOfWorks
        self.preparedBy = preparedBy
        self.approvedBy = approvedBy
        self.methodStatements = methodStatements
        self.requiredPPE = requiredPPE
        self.riskAssessments = riskAssessments
        self.emergencyFirstAidStation = emergencyFirstAidStation
        self.emergencyAssemblyPoint = emergencyAssemblyPoint
        self.emergencyContact = emergencyContact
        self.requiresLiftingPlan = requiresLiftingPlan
        self.signatureTable = signatureTable
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func draft() -> RamsDocument {
        RamsDocument()
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case referenceCode
        case scopeOfWorks
        case preparedBy
        case approvedBy
        case methodStatements
        case requiredPPE
        case riskAssessments
        case emergencyFirstAidStation
        case emergencyAssemblyPoint
        case emergencyContact
        case requiresLiftingPlan
        case signatureTable
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        referenceCode = try container.decode(String.self, forKey: .referenceCode)
        scopeOfWorks = try container.decode(String.self, forKey: .scopeOfWorks)
        preparedBy = try container.decode(String.self, forKey: .preparedBy)
        approvedBy = try container.decode(String.self, forKey: .approvedBy)
        methodStatements = try container.decodeIfPresent([MethodStatementStep].self, forKey: .methodStatements) ?? []
        requiredPPE = try container.decodeIfPresent([PPEItemID].self, forKey: .requiredPPE) ?? []
        riskAssessments = try container.decodeIfPresent([RiskAssessment].self, forKey: .riskAssessments) ?? []
        emergencyFirstAidStation = try container.decodeIfPresent(String.self, forKey: .emergencyFirstAidStation) ?? "Main site office"
        emergencyAssemblyPoint = try container.decodeIfPresent(String.self, forKey: .emergencyAssemblyPoint) ?? "Main Gate"
        emergencyContact = try container.decodeIfPresent(String.self, forKey: .emergencyContact) ?? ""
        requiresLiftingPlan = try container.decodeIfPresent(Bool.self, forKey: .requiresLiftingPlan) ?? false
        signatureTable = try container.decodeIfPresent([SignatureRecord].self, forKey: .signatureTable) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(referenceCode, forKey: .referenceCode)
        try container.encode(scopeOfWorks, forKey: .scopeOfWorks)
        try container.encode(preparedBy, forKey: .preparedBy)
        try container.encode(approvedBy, forKey: .approvedBy)
        try container.encode(methodStatements, forKey: .methodStatements)
        try container.encode(requiredPPE, forKey: .requiredPPE)
        try container.encode(riskAssessments, forKey: .riskAssessments)
        try container.encode(emergencyFirstAidStation, forKey: .emergencyFirstAidStation)
        try container.encode(emergencyAssemblyPoint, forKey: .emergencyAssemblyPoint)
        try container.encode(emergencyContact, forKey: .emergencyContact)
        try container.encode(requiresLiftingPlan, forKey: .requiresLiftingPlan)
        try container.encode(signatureTable, forKey: .signatureTable)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

enum LiftCategory: String, Codable, CaseIterable, Identifiable {
    case routine = "Routine"
    case complex = "Complex"
    case critical = "Critical"

    var id: String { rawValue }
}

struct LiftPlan: Identifiable, Codable, Hashable {
    var id: UUID
    var ramsDocumentID: UUID?
    var title: String
    var category: LiftCategory
    var craneOrPlant: String
    var loadDescription: String
    var loadWeightKg: Double
    var liftingAccessories: [String]
    var liftRadiusMeters: Double
    var boomLengthMeters: Double
    var setupLocation: String
    var landingLocation: String
    var groundBearingCapacity: String
    var windLimit: String
    var communicationMethod: String
    var appointedPerson: String
    var craneSupervisor: String
    var liftOperator: String
    var slingerSignaller: String
    var methodSequence: [String]
    var exclusionZoneDetails: String
    var emergencyRescuePlan: String
    var permitReferences: String
    var drawingImageData: Data?
    var createdAt: Date
    var updatedAt: Date

    static func draft() -> LiftPlan {
        LiftPlan(
            id: UUID(),
            ramsDocumentID: nil,
            title: "",
            category: .routine,
            craneOrPlant: "",
            loadDescription: "",
            loadWeightKg: 0,
            liftingAccessories: [],
            liftRadiusMeters: 0,
            boomLengthMeters: 0,
            setupLocation: "",
            landingLocation: "",
            groundBearingCapacity: "",
            windLimit: "",
            communicationMethod: "",
            appointedPerson: "",
            craneSupervisor: "",
            liftOperator: "",
            slingerSignaller: "",
            methodSequence: [""],
            exclusionZoneDetails: "",
            emergencyRescuePlan: "",
            permitReferences: "",
            drawingImageData: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

struct SignatureRecord: Identifiable, Codable, Hashable {
    var id: UUID
    var signerName: String
    var signerRole: String
    var signedAt: Date
    var signatureImageData: Data

    init(
        id: UUID = UUID(),
        signerName: String,
        signerRole: String,
        signedAt: Date = Date(),
        signatureImageData: Data
    ) {
        self.id = id
        self.signerName = signerName
        self.signerRole = signerRole
        self.signedAt = signedAt
        self.signatureImageData = signatureImageData
    }
}

struct AuthUser: Identifiable, Codable, Hashable {
    var id: UUID
    var email: String
    var displayName: String
}

struct LibraryBundle: Codable, Hashable {
    var hazards: [HazardTemplate]
    var masterDocuments: [MasterDocument]
    var ramsDocuments: [RamsDocument]
    var liftPlans: [LiftPlan]

    static var seeded: LibraryBundle {
        LibraryBundle(
            hazards: [
                HazardTemplate(
                    id: UUID(),
                    category: "Height",
                    title: "Falling from ladders/scaffold",
                    riskToDefault: "Operatives and nearby workers",
                    controlMeasuresDefault: [
                        "Ensure level ground",
                        "Maintain three points of contact",
                        "Use guard rails and inspected access equipment"
                    ],
                    defaultInitialLikelihood: 4,
                    defaultInitialSeverity: 5,
                    defaultResidualLikelihood: 2,
                    defaultResidualSeverity: 3
                ),
                HazardTemplate(
                    id: UUID(),
                    category: "Electrical",
                    title: "Contact with live wires",
                    riskToDefault: "Operatives and supervisors",
                    controlMeasuresDefault: [
                        "Isolate power sources before work",
                        "Use 110v equipment where applicable",
                        "Complete visual checks before use"
                    ],
                    defaultInitialLikelihood: 4,
                    defaultInitialSeverity: 5,
                    defaultResidualLikelihood: 2,
                    defaultResidualSeverity: 2
                ),
                HazardTemplate(
                    id: UUID(),
                    category: "Manual Handling",
                    title: "Heavy lifting of materials",
                    riskToDefault: "Operatives",
                    controlMeasuresDefault: [
                        "Use trolleys or mechanical aids",
                        "Apply two-person lifts for bulky loads",
                        "Use correct lifting posture and rest breaks"
                    ],
                    defaultInitialLikelihood: 3,
                    defaultInitialSeverity: 4,
                    defaultResidualLikelihood: 2,
                    defaultResidualSeverity: 2
                ),
                HazardTemplate(
                    id: UUID(),
                    category: "Environment",
                    title: "Dust inhalation (Silica)",
                    riskToDefault: "Operatives and nearby trades",
                    controlMeasuresDefault: [
                        "Use on-tool extraction with M-Class vacuum",
                        "Wear FFP3 masks",
                        "Dampen dust and clean work area frequently"
                    ],
                    defaultInitialLikelihood: 4,
                    defaultInitialSeverity: 4,
                    defaultResidualLikelihood: 2,
                    defaultResidualSeverity: 2
                ),
                HazardTemplate(
                    id: UUID(),
                    category: "Public",
                    title: "Pedestrian access to work area",
                    riskToDefault: "Public and visitors",
                    controlMeasuresDefault: [
                        "Install barriers and signage",
                        "Maintain exclusion zones",
                        "Assign banksman for interface points"
                    ],
                    defaultInitialLikelihood: 5,
                    defaultInitialSeverity: 4,
                    defaultResidualLikelihood: 2,
                    defaultResidualSeverity: 2
                )
            ],
            masterDocuments: [],
            ramsDocuments: [],
            liftPlans: []
        )
    }
}
