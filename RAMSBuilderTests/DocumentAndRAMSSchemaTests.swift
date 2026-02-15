import XCTest
@testable import RAMSBuilder

final class DocumentAndRAMSSchemaTests: XCTestCase {
    func testMasterDocumentCreateAcceptsValidPayload() throws {
        let payload = DocumentAndRAMSSchema.MasterDocumentCreatePayload(
            projectId: UUID(),
            title: "Master RAMS Document",
            documentReference: "RAMS-REF-001"
        )

        XCTAssertNoThrow(try payload.validate())
    }

    func testMasterDocumentUpdateRejectsOverlongReference() {
        let payload = DocumentAndRAMSSchema.MasterDocumentUpdatePayload(
            title: nil,
            documentReference: String(repeating: "A", count: 121),
            status: .issued
        )

        XCTAssertThrowsError(try payload.validate())
    }

    func testMasterCoverConfigRejectsInvalidAppendixURL() {
        let appendix = DocumentAndRAMSSchema.MasterCoverConfig.DocumentAppendix(
            id: "att-1",
            name: "Drawing",
            mimeType: "application/pdf",
            publicUrl: "not a url",
            storagePath: "/documents/drawing.pdf",
            size: 1_024,
            uploadedAt: "2026-01-10T10:00:00Z",
            caption: nil
        )

        let config = DocumentAndRAMSSchema.MasterCoverConfig(
            projectName: "Project A",
            projectReference: nil,
            projectSiteAddress: nil,
            projectScopeOfWorks: nil,
            dateOfIssue: nil,
            plannedStartDate: nil,
            plannedStartTime: nil,
            expectedDuration: nil,
            exactLocation: nil,
            attachmentPlan: nil,
            locationPlanAppendices: [appendix],
            documentPreparedByUserId: nil,
            riskAssessmentsCompletedByUserId: nil,
            personnelUserIds: nil,
            siteSupervisorUserId: nil,
            communicationBriefedByUserId: nil,
            communicationRecipientUserIds: nil,
            communicationEscalationUserId: nil,
            communicationDeliveryMethods: nil,
            plantEquipmentToolsItems: nil,
            materialsHazardousSubstancesItems: nil,
            attachmentPlanAssetUrl: nil,
            attachmentPlanAssetName: nil,
            attachmentPlanAssetType: nil,
            documentPreparedBy: nil,
            riskAssessmentsCompleted: nil,
            accessEgressRequirements: nil,
            personnelJobTitles: nil,
            siteSupervisor: nil,
            plantEquipmentTools: nil,
            materialsHazardousSubstances: nil,
            drawingsTechnicalInfo: nil,
            wasteRemoval: nil,
            housekeepingStorage: nil,
            permitsRequired: nil,
            permitType: nil,
            permitIssuedBy: nil,
            mandatorySitePpe: nil,
            taskSpecificPpe: nil,
            nearestHospital: nil,
            nearestHospitalMapImage: nil,
            emergencyRescue: nil,
            emergencyRescueFromHeight: nil,
            emergencyFirstAidPoint: nil,
            emergencyQualifiedFirstAiders: nil,
            emergencyFireSafetyArrangements: nil,
            emergencyAssemblyPoints: nil,
            awarenessCommunication: nil,
            monitoringResponsiblePerson: nil,
            havNoiseResponsiblePerson: nil,
            amendmentsAuthorisedBy: nil,
            issuedToReviewedBy: nil,
            emergencyArrangements: nil,
            responsibilities: nil,
            monitoringCompliance: nil,
            keyRiskKeywords: nil,
            minimumRiskAssessments: nil,
            additionalNotes: nil
        )

        XCTAssertThrowsError(try config.validate())
    }

    func testMasterTemplateCreateRequiresTitle() {
        let payload = DocumentAndRAMSSchema.MasterTemplateCreatePayload(
            title: " ",
            description: nil,
            coverConfig: .init(
                projectName: nil,
                projectReference: nil,
                projectSiteAddress: nil,
                projectScopeOfWorks: nil,
                dateOfIssue: nil,
                plannedStartDate: nil,
                plannedStartTime: nil,
                expectedDuration: nil,
                exactLocation: nil,
                attachmentPlan: nil,
                locationPlanAppendices: nil,
                documentPreparedByUserId: nil,
                riskAssessmentsCompletedByUserId: nil,
                personnelUserIds: nil,
                siteSupervisorUserId: nil,
                communicationBriefedByUserId: nil,
                communicationRecipientUserIds: nil,
                communicationEscalationUserId: nil,
                communicationDeliveryMethods: nil,
                plantEquipmentToolsItems: nil,
                materialsHazardousSubstancesItems: nil,
                attachmentPlanAssetUrl: nil,
                attachmentPlanAssetName: nil,
                attachmentPlanAssetType: nil,
                documentPreparedBy: nil,
                riskAssessmentsCompleted: nil,
                accessEgressRequirements: nil,
                personnelJobTitles: nil,
                siteSupervisor: nil,
                plantEquipmentTools: nil,
                materialsHazardousSubstances: nil,
                drawingsTechnicalInfo: nil,
                wasteRemoval: nil,
                housekeepingStorage: nil,
                permitsRequired: nil,
                permitType: nil,
                permitIssuedBy: nil,
                mandatorySitePpe: nil,
                taskSpecificPpe: nil,
                nearestHospital: nil,
                nearestHospitalMapImage: nil,
                emergencyRescue: nil,
                emergencyRescueFromHeight: nil,
                emergencyFirstAidPoint: nil,
                emergencyQualifiedFirstAiders: nil,
                emergencyFireSafetyArrangements: nil,
                emergencyAssemblyPoints: nil,
                awarenessCommunication: nil,
                monitoringResponsiblePerson: nil,
                havNoiseResponsiblePerson: nil,
                amendmentsAuthorisedBy: nil,
                issuedToReviewedBy: nil,
                emergencyArrangements: nil,
                responsibilities: nil,
                monitoringCompliance: nil,
                keyRiskKeywords: nil,
                minimumRiskAssessments: nil,
                additionalNotes: nil
            ),
            sections: []
        )

        XCTAssertThrowsError(try payload.validate())
    }

    func testRAMSRejectsMoreThanAllowedTags() {
        let rams = DocumentAndRAMSSchema.RAMS(
            projectDetails: .init(
                projectName: "Project",
                projectTitle: "Main Works",
                reference: "REF-001",
                date: "2026-01-10",
                siteAddress: "Site Address",
                assessor: "Assessor",
                supervisor: "Supervisor",
                description: "Scope description"
            ),
            selectedPPE: ["Helmet"],
            plantEquipmentAccess: ["Scaffold tower"],
            workingAtHeightEquipmentDetails: [
                .init(equipment: "MEWP", makeModelType: "Genie", qualificationsNeeded: "IPAF")
            ],
            specialistTools: ["Torque wrench"],
            consumables: ["Gloves"],
            materials: ["Steel"],
            hazards: [
                .init(
                    id: nil,
                    activity: "Installation",
                    hazard: "Falling objects",
                    personsAtRisk: "Operatives",
                    initL: 3,
                    initS: 4,
                    controls: "Use exclusion zone and tethered tools.",
                    resL: 2,
                    resS: 2
                )
            ],
            methodStatement: .init(
                sequence: "Step 1 -> Step 2",
                emergencyProcedures: nil,
                firstAid: nil
            ),
            category: "General",
            tags: (1...26).map { "tag-\($0)" }
        )

        XCTAssertThrowsError(try rams.validate())
    }

    func testHazardRejectsOutOfRangeResidualLikelihood() {
        let hazard = DocumentAndRAMSSchema.Hazard(
            id: 1,
            activity: "Work at height",
            hazard: "Fall from ladder",
            personsAtRisk: "Operatives",
            initL: 3,
            initS: 4,
            controls: "Use podium steps with guard rails.",
            resL: 6,
            resS: 2
        )

        XCTAssertThrowsError(try hazard.validate())
    }
}
