import XCTest
@testable import RAMSBuilder

final class RiskScoringTests: XCTestCase {
    func testVeryLowRiskBand() {
        XCTAssertEqual(RiskScoreMatrix.review(for: 1), .veryLow)
        XCTAssertEqual(RiskScoreMatrix.review(for: 3), .veryLow)
    }

    func testLowRiskBand() {
        XCTAssertEqual(RiskScoreMatrix.review(for: 4), .low)
        XCTAssertEqual(RiskScoreMatrix.review(for: 6), .low)
    }

    func testMediumRiskBand() {
        XCTAssertEqual(RiskScoreMatrix.review(for: 7), .medium)
        XCTAssertEqual(RiskScoreMatrix.review(for: 12), .medium)
    }

    func testHighRiskBand() {
        XCTAssertEqual(RiskScoreMatrix.review(for: 13), .high)
        XCTAssertEqual(RiskScoreMatrix.review(for: 19), .high)
    }

    func testVeryHighRiskBand() {
        XCTAssertEqual(RiskScoreMatrix.review(for: 20), .veryHigh)
        XCTAssertEqual(RiskScoreMatrix.review(for: 25), .veryHigh)
    }

    func testRamsOverallRiskReviewUsesHighestResidual() {
        let lowRisk = RiskAssessment(
            hazardTitle: "Low",
            riskTo: "Operatives",
            controlMeasures: ["Control"],
            initialLikelihood: 2,
            initialSeverity: 2,
            residualLikelihood: 1,
            residualSeverity: 2
        )
        let highRisk = RiskAssessment(
            hazardTitle: "Higher",
            riskTo: "Operatives",
            controlMeasures: ["Control"],
            initialLikelihood: 5,
            initialSeverity: 4,
            residualLikelihood: 4,
            residualSeverity: 4
        )

        let rams = RamsDocument(
            id: UUID(),
            title: "Test RAMS",
            referenceCode: "RAMS-TEST",
            scopeOfWorks: "Scope",
            preparedBy: "User",
            approvedBy: "Manager",
            methodStatements: [],
            riskAssessments: [lowRisk, highRisk],
            requiresLiftingPlan: false,
            signatureTable: [],
            createdAt: Date(),
            updatedAt: Date()
        )

        XCTAssertEqual(rams.overallRiskReview, .high)
    }
}
