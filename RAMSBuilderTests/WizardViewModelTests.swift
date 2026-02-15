import XCTest
@testable import RAMSBuilder

@MainActor
final class WizardViewModelTests: XCTestCase {
    func testGoNextStaysOnMasterStepWhenRequiredFieldsAreMissing() {
        let viewModel = makeViewModel()

        viewModel.goNext()

        XCTAssertEqual(viewModel.currentStep, .masterDocument)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testGoNextAdvancesToReviewWhenMasterAndRamsAreValidWithoutLiftPlan() {
        let viewModel = makeViewModel()
        makeMasterStepValid(on: viewModel)

        viewModel.goNext()
        XCTAssertEqual(viewModel.currentStep, .ramsDocument)

        makeRamsStepValid(on: viewModel)
        viewModel.goNext()

        XCTAssertEqual(viewModel.currentStep, .review)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testLiftPlanValidationBlocksProgressUntilRequiredFieldsFilled() {
        let viewModel = makeViewModel()
        viewModel.includeLiftPlan = true
        makeMasterStepValid(on: viewModel)

        viewModel.goNext()
        XCTAssertEqual(viewModel.currentStep, .ramsDocument)

        makeRamsStepValid(on: viewModel)
        viewModel.goNext()
        XCTAssertEqual(viewModel.currentStep, .liftPlan)

        viewModel.goNext()
        XCTAssertEqual(viewModel.currentStep, .liftPlan)
        XCTAssertNotNil(viewModel.errorMessage)

        viewModel.liftPlan.title = "Steel Beam Lift"
        viewModel.liftPlan.craneOrPlant = "Mobile Crane"
        viewModel.liftPlan.loadDescription = "Beam section A"
        viewModel.liftPlan.appointedPerson = "Appointed Person"
        viewModel.goNext()

        XCTAssertEqual(viewModel.currentStep, .review)
        XCTAssertNil(viewModel.errorMessage)
    }

    private func makeViewModel() -> WizardViewModel {
        let libraryViewModel = LibraryViewModel(store: LibraryStore())
        return WizardViewModel(libraryViewModel: libraryViewModel)
    }

    private func makeMasterStepValid(on viewModel: WizardViewModel) {
        viewModel.masterDocument.projectName = "Project One"
        viewModel.masterDocument.siteAddress = "1 Builder Way"
        viewModel.masterDocument.nearestHospitalName = "General Hospital"
        viewModel.masterDocument.hospitalDirections = "Turn left at the main roundabout."
    }

    private func makeRamsStepValid(on viewModel: WizardViewModel) {
        viewModel.ramsDocument.title = "Install steelwork"
        viewModel.ramsDocument.scopeOfWorks = "Install structural steel members."
        viewModel.ramsDocument.preparedBy = "Site Engineer"
        viewModel.ramsDocument.riskAssessments = [RiskAssessment()]
    }
}
