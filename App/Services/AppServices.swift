import Foundation
import UIKit

enum AuthError: LocalizedError {
    case invalidCredentials

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Please provide a valid email and password."
        }
    }
}

protocol AuthServiceProviding {
    func login(email: String, password: String) async throws -> AuthUser
    func logout()
}

final class MockAuthService: AuthServiceProviding {
    private var activeUser: AuthUser?

    func login(email: String, password: String) async throws -> AuthUser {
        try await Task.sleep(nanoseconds: 400_000_000)

        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedEmail.contains("@"), normalizedPassword.count >= 4 else {
            throw AuthError.invalidCredentials
        }

        let user = AuthUser(
            id: UUID(),
            email: normalizedEmail.lowercased(),
            displayName: normalizedEmail.split(separator: "@").first.map(String.init)?.capitalized ?? "User"
        )
        activeUser = user
        return user
    }

    func logout() {
        activeUser = nil
    }
}

enum LibraryStoreError: LocalizedError {
    case failedToCreateDirectory

    var errorDescription: String? {
        switch self {
        case .failedToCreateDirectory:
            return "Could not create local storage directory."
        }
    }
}

final class LibraryStore {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let libraryFileName = "library.json"
    private let libraryDirectoryName = "RAMSBuilderStorage"

    init() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func loadLibrary() throws -> LibraryBundle {
        let url = try libraryFileURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .seeded
        }

        let data = try Data(contentsOf: url)
        return try decoder.decode(LibraryBundle.self, from: data)
    }

    func saveLibrary(_ library: LibraryBundle) throws {
        let url = try libraryFileURL()
        let data = try encoder.encode(library)
        try data.write(to: url, options: .atomic)
    }

    private func libraryFileURL() throws -> URL {
        let fileManager = FileManager.default
        let root = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = root.appendingPathComponent(libraryDirectoryName, isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                throw LibraryStoreError.failedToCreateDirectory
            }
        }
        return directory.appendingPathComponent(libraryFileName)
    }
}

struct PublicShareLink: Hashable {
    let url: URL
    let expiresAt: Date
}

final class PublicLinkService {
    func generatePublicLink(for rams: RamsDocument) -> PublicShareLink {
        let token = UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
        let safeTitle = rams.title.sanitizedPathComponent
        let url = URL(string: "https://share.ramsbuilder.app/\(safeTitle)/\(token)")!
        let expiry = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        return PublicShareLink(url: url, expiresAt: expiry)
    }
}

enum PDFExportError: LocalizedError {
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .exportFailed:
            return "Unable to create the PDF."
        }
    }
}

final class PDFExportService {
    func exportPDF(
        master: MasterDocument,
        rams: RamsDocument,
        liftPlan: LiftPlan?,
        signatures: [SignatureRecord]
    ) throws -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 at 72 DPI
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let filename = "RAMS-\(rams.title.sanitizedPathComponent)-\(Int(Date().timeIntervalSince1970)).pdf"
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        do {
            try renderer.writePDF(to: outputURL) { context in
                context.beginPage()
                var cursorY: CGFloat = 24

                cursorY = drawText("RAMS Builder Export", at: cursorY, font: .boldSystemFont(ofSize: 22))
                cursorY = drawText("Project: \(master.projectName)", at: cursorY, font: .boldSystemFont(ofSize: 16))
                cursorY = drawText("RAMS: \(rams.title)", at: cursorY)
                cursorY = drawText("Reference: \(rams.referenceCode)", at: cursorY)
                cursorY = drawText("Generated: \(DateFormatter.shortDateTime.string(from: Date()))", at: cursorY)
                cursorY += 8

                cursorY = drawHeading("Master Document", at: cursorY)
                cursorY = drawText("Site address: \(master.siteAddress)", at: cursorY)
                cursorY = drawText("Principal contractor: \(master.principalContractor)", at: cursorY)
                cursorY = drawText("Emergency contact: \(master.emergencyContactName) - \(master.emergencyContactPhone)", at: cursorY)
                cursorY = drawText("Nearest hospital: \(master.nearestHospitalName), \(master.nearestHospitalAddress)", at: cursorY)
                cursorY = drawText("Directions: \(master.hospitalDirections)", at: cursorY)
                cursorY += 8

                cursorY = drawHeading("Method Statement", at: cursorY)
                for step in rams.methodStatements {
                    ensurePage(context: context, cursorY: &cursorY, requiredSpace: 60, pageHeight: pageRect.height)
                    cursorY = drawText("\(step.sequence). \(step.title)", at: cursorY, font: .boldSystemFont(ofSize: 12))
                    cursorY = drawText(step.details, at: cursorY)
                }
                cursorY += 8

                ensurePage(context: context, cursorY: &cursorY, requiredSpace: 120, pageHeight: pageRect.height)
                cursorY = drawHeading("Risk Assessments", at: cursorY)
                for assessment in rams.riskAssessments {
                    ensurePage(context: context, cursorY: &cursorY, requiredSpace: 90, pageHeight: pageRect.height)
                    cursorY = drawText("Hazard: \(assessment.hazardTitle)", at: cursorY, font: .boldSystemFont(ofSize: 12))
                    cursorY = drawText("Risk to: \(assessment.riskTo)", at: cursorY)
                    cursorY = drawText(
                        "Initial score: \(assessment.initialScore) | Residual score: \(assessment.residualScore) | Review: \(assessment.overallReview.rawValue) \(assessment.overallReview.title)",
                        at: cursorY
                    )
                    let controls = assessment.controlMeasures.joined(separator: "; ")
                    cursorY = drawText("Controls: \(controls)", at: cursorY)
                    cursorY += 2
                }

                cursorY += 8
                ensurePage(context: context, cursorY: &cursorY, requiredSpace: 120, pageHeight: pageRect.height)
                cursorY = drawHeading("Overall Risk Review: \(rams.overallRiskReview.rawValue) \(rams.overallRiskReview.title)", at: cursorY)

                if let liftPlan {
                    cursorY += 8
                    ensurePage(context: context, cursorY: &cursorY, requiredSpace: 180, pageHeight: pageRect.height)
                    let loadWeight = String(format: "%.1f", liftPlan.loadWeightKg)
                    let radius = String(format: "%.1f", liftPlan.liftRadiusMeters)
                    let boom = String(format: "%.1f", liftPlan.boomLengthMeters)
                    cursorY = drawHeading("Lift Plan (\(liftPlan.category.rawValue))", at: cursorY)
                    cursorY = drawText("Title: \(liftPlan.title)", at: cursorY)
                    cursorY = drawText("Equipment: \(liftPlan.craneOrPlant)", at: cursorY)
                    cursorY = drawText("Load: \(liftPlan.loadDescription) - \(loadWeight) kg", at: cursorY)
                    cursorY = drawText("Radius: \(radius) m | Boom: \(boom) m", at: cursorY)
                    cursorY = drawText("Setup: \(liftPlan.setupLocation)", at: cursorY)
                    cursorY = drawText("Landing: \(liftPlan.landingLocation)", at: cursorY)
                    cursorY = drawText("Exclusion zone: \(liftPlan.exclusionZoneDetails)", at: cursorY)
                    cursorY = drawText("Emergency rescue: \(liftPlan.emergencyRescuePlan)", at: cursorY)
                    cursorY = drawText("Communication: \(liftPlan.communicationMethod)", at: cursorY)
                }

                cursorY += 8
                ensurePage(context: context, cursorY: &cursorY, requiredSpace: 200, pageHeight: pageRect.height)
                cursorY = drawHeading("Digital Signatures", at: cursorY)
                if signatures.isEmpty {
                    _ = drawText("No signatures captured.", at: cursorY)
                } else {
                    for signature in signatures {
                        ensurePage(context: context, cursorY: &cursorY, requiredSpace: 110, pageHeight: pageRect.height)
                        cursorY = drawText("\(signature.signerName) (\(signature.signerRole))", at: cursorY, font: .boldSystemFont(ofSize: 12))
                        cursorY = drawText("Signed: \(DateFormatter.shortDateTime.string(from: signature.signedAt))", at: cursorY)
                        if let image = UIImage(data: signature.signatureImageData) {
                            let signatureRect = CGRect(x: 28, y: cursorY, width: 180, height: 60)
                            image.draw(in: signatureRect)
                            cursorY += 68
                        } else {
                            cursorY = drawText("Signature image unavailable", at: cursorY)
                        }
                    }
                }
            }
        } catch {
            throw PDFExportError.exportFailed
        }

        return outputURL
    }

    @discardableResult
    private func drawHeading(_ text: String, at y: CGFloat) -> CGFloat {
        drawText(text, at: y, font: .boldSystemFont(ofSize: 14))
    }

    @discardableResult
    private func drawText(_ text: String, at y: CGFloat, font: UIFont = .systemFont(ofSize: 11)) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font
        ]
        let width: CGFloat = 540
        let origin = CGPoint(x: 28, y: y)
        let boundingRect = NSString(string: text).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        let drawingRect = CGRect(origin: origin, size: CGSize(width: width, height: ceil(boundingRect.height)))
        NSString(string: text).draw(with: drawingRect, options: [.usesLineFragmentOrigin], attributes: attributes, context: nil)
        return y + ceil(boundingRect.height) + 6
    }

    private func ensurePage(
        context: UIGraphicsPDFRendererContext,
        cursorY: inout CGFloat,
        requiredSpace: CGFloat,
        pageHeight: CGFloat
    ) {
        if cursorY + requiredSpace > pageHeight - 24 {
            context.beginPage()
            cursorY = 24
        }
    }
}

private extension String {
    var sanitizedPathComponent: String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        let collapsed = trimmed.replacingOccurrences(of: " ", with: "-")
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = collapsed.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let base = String(scalars)
        return base.isEmpty ? "untitled-rams" : base.lowercased()
    }
}

extension DateFormatter {
    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
