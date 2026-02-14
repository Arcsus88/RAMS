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
    var riskAssessments: [RiskAssessment]
    var requiresLiftingPlan: Bool
    var signatureTable: [SignatureRecord]
    var createdAt: Date
    var updatedAt: Date

    var overallRiskReview: RiskReview {
        let highestResidual = riskAssessments.map(\.residualScore).max() ?? 0
        return RiskScoreMatrix.review(for: highestResidual)
    }

    static func draft() -> RamsDocument {
        RamsDocument(
            id: UUID(),
            title: "",
            referenceCode: "",
            scopeOfWorks: "",
            preparedBy: "",
            approvedBy: "",
            methodStatements: [MethodStatementStep(sequence: 1, title: "", details: "")],
            riskAssessments: [],
            requiresLiftingPlan: false,
            signatureTable: [],
            createdAt: Date(),
            updatedAt: Date()
        )
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
                    category: "Access",
                    title: "Working at height",
                    riskToDefault: "Operatives, supervisors, visitors",
                    controlMeasuresDefault: [
                        "Use inspected towers or MEWPs with valid tags",
                        "Maintain 3 points of contact and secure materials",
                        "Exclude and signpost drop zones below work area"
                    ],
                    defaultInitialLikelihood: 4,
                    defaultInitialSeverity: 5,
                    defaultResidualLikelihood: 2,
                    defaultResidualSeverity: 3
                ),
                HazardTemplate(
                    id: UUID(),
                    category: "Plant",
                    title: "Plant and vehicle movement",
                    riskToDefault: "Operatives, banksman, public",
                    controlMeasuresDefault: [
                        "Use designated banksman with clear communication",
                        "Maintain segregated pedestrian routes",
                        "Apply one-way systems and speed controls"
                    ],
                    defaultInitialLikelihood: 4,
                    defaultInitialSeverity: 4,
                    defaultResidualLikelihood: 2,
                    defaultResidualSeverity: 2
                ),
                HazardTemplate(
                    id: UUID(),
                    category: "Lifting",
                    title: "Suspended load during lifting operation",
                    riskToDefault: "Slinger/signaller, crane operator, nearby workers",
                    controlMeasuresDefault: [
                        "Lift plan approved by appointed person",
                        "Certified lifting accessories inspected before use",
                        "No persons under suspended loads"
                    ],
                    defaultInitialLikelihood: 5,
                    defaultInitialSeverity: 5,
                    defaultResidualLikelihood: 2,
                    defaultResidualSeverity: 3
                )
            ],
            masterDocuments: [],
            ramsDocuments: [],
            liftPlans: []
        )
    }
}
