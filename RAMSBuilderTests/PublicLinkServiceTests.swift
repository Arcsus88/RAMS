import XCTest
@testable import RAMSBuilder

final class PublicLinkServiceTests: XCTestCase {
    func testGeneratePublicLinkSanitizesTitleAndCreatesTokenizedPath() {
        let service = PublicLinkService()
        var rams = RamsDocument.draft()
        rams.title = "  My Unsafe/Title #1  "
        let start = Date()

        let link = service.generatePublicLink(for: rams)

        XCTAssertEqual(link.url.host, "share.ramsbuilder.app")

        let pathParts = link.url.pathComponents.filter { $0 != "/" }
        XCTAssertEqual(pathParts.count, 2)
        XCTAssertEqual(pathParts.first, "my-unsafe-title--1")

        guard let token = pathParts.last else {
            XCTFail("Expected a tokenized path segment.")
            return
        }

        XCTAssertEqual(token.count, 32)
        let allowed = CharacterSet(charactersIn: "0123456789abcdef")
        XCTAssertTrue(token.unicodeScalars.allSatisfy(allowed.contains))

        let interval = link.expiresAt.timeIntervalSince(start)
        XCTAssertGreaterThan(interval, 13 * 24 * 60 * 60)
        XCTAssertLessThan(interval, 15 * 24 * 60 * 60)
    }

    func testGeneratePublicLinkUsesUntitledSlugForEmptyTitle() {
        let service = PublicLinkService()
        let rams = RamsDocument.draft()

        let link = service.generatePublicLink(for: rams)
        let pathParts = link.url.pathComponents.filter { $0 != "/" }

        XCTAssertEqual(pathParts.first, "untitled-rams")
    }
}
