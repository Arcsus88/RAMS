import SwiftUI

struct UserHomeView: View {
    @EnvironmentObject private var sessionViewModel: SessionViewModel
    @EnvironmentObject private var libraryViewModel: LibraryViewModel

    let onOpenWizard: () -> Void
    let onOpenLibraries: () -> Void
    let onOpenAccount: () -> Void

    private let metricsColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var greetingName: String {
        let name = sessionViewModel.currentUser?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "Safety Officer" : name
    }

    private var totalSavedDocuments: Int {
        libraryViewModel.library.masterDocuments.count
            + libraryViewModel.library.ramsDocuments.count
            + libraryViewModel.library.liftPlans.count
    }

    private var highRiskRamsCount: Int {
        libraryViewModel.library.ramsDocuments.filter { document in
            document.overallRiskReview == .high || document.overallRiskReview == .veryHigh
        }.count
    }

    private var recentDocuments: [HomeRecentDocument] {
        let masterDocuments = libraryViewModel.library.masterDocuments.map { document in
            HomeRecentDocument(
                id: "master-\(document.id.uuidString)",
                title: nonEmpty(document.projectName, fallback: "Untitled project"),
                subtitle: nonEmpty(document.siteAddress, fallback: "No site address"),
                updatedAt: document.updatedAt,
                kind: .master
            )
        }
        let ramsDocuments = libraryViewModel.library.ramsDocuments.map { document in
            HomeRecentDocument(
                id: "rams-\(document.id.uuidString)",
                title: nonEmpty(document.title, fallback: "Untitled RAMS"),
                subtitle: nonEmpty(document.referenceCode, fallback: "No reference code"),
                updatedAt: document.updatedAt,
                kind: .rams
            )
        }
        let liftPlans = libraryViewModel.library.liftPlans.map { plan in
            HomeRecentDocument(
                id: "lift-\(plan.id.uuidString)",
                title: nonEmpty(plan.title, fallback: "Untitled lift plan"),
                subtitle: plan.category.rawValue,
                updatedAt: plan.updatedAt,
                kind: .liftPlan
            )
        }

        return Array((masterDocuments + ramsDocuments + liftPlans).sorted { $0.updatedAt > $1.updatedAt }.prefix(6))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    welcomePanel

                    LazyVGrid(columns: metricsColumns, spacing: 12) {
                        HomeMetricCard(title: "Total Saved", value: "\(totalSavedDocuments)", symbolName: "folder.badge.person.crop")
                        HomeMetricCard(title: "RAMS Docs", value: "\(libraryViewModel.library.ramsDocuments.count)", symbolName: "doc.text.magnifyingglass")
                        HomeMetricCard(title: "Master Docs", value: "\(libraryViewModel.library.masterDocuments.count)", symbolName: "doc.badge.gearshape")
                        HomeMetricCard(title: "High Risk RAMS", value: "\(highRiskRamsCount)", symbolName: "exclamationmark.triangle")
                    }

                    quickActionsPanel
                    recentDocumentsPanel
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Home")
        }
    }

    private var welcomePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Welcome back, \(greetingName)")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text("Create RAMS documents, review your local library, and continue where you left off.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))

            Text("Last login: \(DateFormatter.shortDateTime.string(from: Date()))")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.proSlate800, Color.proSlate900],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.proYellow.opacity(0.35), lineWidth: 1)
        )
    }

    private var quickActionsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            HomeActionButton(
                title: "Start New RAMS Wizard",
                subtitle: "Open the guided RAMS workflow",
                symbolName: "wand.and.stars",
                action: onOpenWizard
            )

            HomeActionButton(
                title: "Open Libraries",
                subtitle: "Review hazard, master, RAMS, and lift templates",
                symbolName: "books.vertical",
                action: onOpenLibraries
            )

            HomeActionButton(
                title: "Account & Logout",
                subtitle: "View signed in profile and session controls",
                symbolName: "person.crop.circle",
                action: onOpenAccount
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var recentDocumentsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Documents")
                    .font(.headline)
                Spacer()
                if highRiskRamsCount > 0 {
                    Text("\(highRiskRamsCount) high risk")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.orange.opacity(0.14))
                        .clipShape(Capsule())
                }
            }

            if recentDocuments.isEmpty {
                Text("No documents saved yet. Start the wizard to create your first RAMS package.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                ForEach(recentDocuments) { document in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: document.kind.symbolName)
                            .foregroundStyle(document.kind.tint)
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(document.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)

                            Text("\(document.kind.title) • \(document.subtitle)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("Updated \(DateFormatter.shortDateTime.string(from: document.updatedAt))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    if document.id != recentDocuments.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func nonEmpty(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}

private struct HomeMetricCard: View {
    let title: String
    let value: String
    let symbolName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbolName)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.proYellow)

            Text(value)
                .font(.title3.weight(.bold))

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

private struct HomeActionButton: View {
    let title: String
    let subtitle: String
    let symbolName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbolName)
                    .frame(width: 22)
                    .foregroundStyle(Color.proYellow)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }
}

private struct HomeRecentDocument: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let updatedAt: Date
    let kind: HomeDocumentKind
}

private enum HomeDocumentKind {
    case master
    case rams
    case liftPlan

    var title: String {
        switch self {
        case .master:
            return "Master Document"
        case .rams:
            return "RAMS"
        case .liftPlan:
            return "Lift Plan"
        }
    }

    var symbolName: String {
        switch self {
        case .master:
            return "doc.badge.gearshape"
        case .rams:
            return "doc.text.magnifyingglass"
        case .liftPlan:
            return "figure.crane"
        }
    }

    var tint: Color {
        switch self {
        case .master:
            return .blue
        case .rams:
            return Color.proYellow
        case .liftPlan:
            return .purple
        }
    }
}
