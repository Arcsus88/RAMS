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
    private let printEngine = RamsPDFPrintEngine()

    func exportPDF(
        master: MasterDocument,
        rams: RamsDocument,
        liftPlan: LiftPlan?,
        signatures: [SignatureRecord]
    ) throws -> URL {
        let document = RamsPDFDocumentBuilder.build(
            master: master,
            rams: rams,
            liftPlan: liftPlan,
            signatures: signatures
        )
        return try printEngine.export(document: document, fileNameStem: rams.title.sanitizedPathComponent)
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
