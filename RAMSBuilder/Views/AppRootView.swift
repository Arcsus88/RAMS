import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var sessionViewModel: SessionViewModel

    var body: some View {
        Group {
            if sessionViewModel.currentUser == nil {
                LoginView()
            } else {
                DashboardView()
            }
        }
        .animation(.easeInOut, value: sessionViewModel.currentUser != nil)
    }
}

struct LoginView: View {
    @EnvironmentObject private var sessionViewModel: SessionViewModel
    @Environment(\.openURL) private var openURL

    @FocusState private var focusedField: Field?
    @State private var email = ""
    @State private var password = ""
    @State private var rememberDevice = true
    @State private var isPasswordVisible = false

    private enum Field {
        case email
        case password
    }

    var body: some View {
        NavigationStack {
            ZStack {
                IndustrialLoginBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 26) {
                        brandHeader
                        loginCard
                        complianceStrip

                        Text("Mock authentication for scaffold stage. Supabase auth can be integrated later.")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.45))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 18)
                    }
                    .frame(maxWidth: 460)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationBarHidden(true)
        }
    }

    private var brandHeader: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.proYellow.opacity(0.08))
                    .frame(width: 84, height: 84)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.proYellow.opacity(0.25), lineWidth: 1)
                    )

                Image(systemName: "doc.badge.shield.checkmark")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(Color.proYellow)

                Text("RAMS")
                    .font(.system(size: 9, weight: .black))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.proYellow)
                    .foregroundStyle(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .offset(x: 6, y: 4)
            }

            Text("PROBUILD")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .tracking(-1)
                .foregroundStyle(.white)

            Text("SAFETY MANAGEMENT SYSTEMS")
                .font(.system(size: 10, weight: .bold))
                .tracking(4)
                .foregroundStyle(.white.opacity(0.45))
                .padding(.leading, 4)
        }
    }

    private var loginCard: some View {
        VStack(spacing: 0) {
            CautionStripe()

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Portal Access")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(.white)
                    Text("Sign in with your work credentials")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))
                }

                emailField
                passwordField
                rememberRow

                if let errorMessage = sessionViewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.red.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 2)
                }

                Button {
                    focusedField = nil
                    Task {
                        await sessionViewModel.login(email: email, password: password)
                    }
                } label: {
                    HStack(spacing: 8) {
                        if sessionViewModel.isLoading {
                            ProgressView()
                                .controlSize(.small)
                                .tint(Color.black)
                        }
                        Text(sessionViewModel.isLoading ? "ACCESSING CLOUD..." : "INITIALIZE SESSION")
                            .font(.caption.weight(.black))
                            .tracking(2.2)
                    }
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.proYellow, Color(red: 245 / 255, green: 158 / 255, blue: 11 / 255)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(sessionViewModel.isLoading)
                .opacity(sessionViewModel.isLoading ? 0.85 : 1)

                HStack(spacing: 8) {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)
                    Text("SECURE GATEWAY")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.35))
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)
                }
                .padding(.top, 6)

                HStack(spacing: 4) {
                    Text("New Safety Officer?")
                        .foregroundStyle(.white.opacity(0.48))
                    Button("Enroll Here") {
                        if let url = URL(string: "https://www.probuild.com") {
                            openURL(url)
                        }
                    }
                    .foregroundStyle(Color.proYellow)
                    .fontWeight(.bold)
                }
                .font(.caption)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 22)
        }
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(red: 18 / 255, green: 18 / 255, blue: 18 / 255).opacity(0.95))
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.proYellow.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.65), radius: 30, y: 18)
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EMAIL ADDRESS")
                .font(.system(size: 10, weight: .black))
                .tracking(1.8)
                .foregroundStyle(.white.opacity(0.45))

            HStack(spacing: 10) {
                Image(systemName: "envelope.fill")
                    .foregroundStyle(iconColor(for: .email))
                    .frame(width: 18)

                TextField("name@probuild.com", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .password
                    }
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Color.black.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(borderColor(for: .email), lineWidth: 1)
            )
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ACCESS PASSWORD")
                    .font(.system(size: 10, weight: .black))
                    .tracking(1.8)
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
                Button("Recover") {
                    if let url = URL(string: "mailto:safety@probuild.com") {
                        openURL(url)
                    }
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.proYellow)
            }

            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(iconColor(for: .password))
                    .frame(width: 18)

                Group {
                    if isPasswordVisible {
                        TextField("••••••••", text: $password)
                    } else {
                        SecureField("••••••••", text: $password)
                    }
                }
                .focused($focusedField, equals: .password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .onSubmit {
                    focusedField = nil
                    Task {
                        await sessionViewModel.login(email: email, password: password)
                    }
                }
                .foregroundStyle(.white)

                Button {
                    isPasswordVisible.toggle()
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.fill" : "eye.slash.fill")
                        .foregroundStyle(.white.opacity(0.55))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Color.black.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(borderColor(for: .password), lineWidth: 1)
            )
        }
    }

    private var rememberRow: some View {
        Toggle(isOn: $rememberDevice) {
            Text("Stay authenticated on this device")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.65))
        }
        .tint(Color.proYellow)
    }

    private var complianceStrip: some View {
        VStack(spacing: 10) {
            HStack(spacing: 22) {
                Image(systemName: "checkmark.shield")
                Image(systemName: "rosette")
                Image(systemName: "helmet")
            }
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white.opacity(0.26))

            Text("VERIFIED NODE: SEC-RAMS-01")
                .font(.system(size: 9, weight: .bold))
                .tracking(2.5)
                .foregroundStyle(.white.opacity(0.28))
        }
    }

    private func iconColor(for field: Field) -> Color {
        focusedField == field ? Color.proYellow : Color.white.opacity(0.35)
    }

    private func borderColor(for field: Field) -> Color {
        focusedField == field ? Color.proYellow.opacity(0.5) : Color.white.opacity(0.12)
    }
}

private struct IndustrialLoginBackground: View {
    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color.proSlate800.opacity(0.65), Color.black],
                center: UnitPoint(x: 0.88, y: 0.04),
                startRadius: 10,
                endRadius: 560
            )
            .ignoresSafeArea()

            GeometryReader { proxy in
                Path { path in
                    let spacing: CGFloat = 38
                    let width = proxy.size.width
                    let height = proxy.size.height

                    var x: CGFloat = 0
                    while x <= width {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: height))
                        x += spacing
                    }

                    var y: CGFloat = 0
                    while y <= height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                        y += spacing
                    }
                }
                .stroke(Color.proYellow.opacity(0.08), lineWidth: 0.6)
            }
            .ignoresSafeArea()
        }
    }
}

private struct CautionStripe: View {
    var body: some View {
        GeometryReader { proxy in
            let stripeCount = Int((proxy.size.width / 18).rounded(.up)) + 4
            HStack(spacing: 0) {
                ForEach(0..<stripeCount, id: \.self) { index in
                    Rectangle()
                        .fill(index.isMultiple(of: 2) ? Color.proYellow : Color.black)
                        .frame(width: 18)
                }
            }
            .rotationEffect(.degrees(-18))
            .offset(x: -22)
        }
        .frame(height: 6)
        .clipped()
    }
}

private struct UserHomeView: View {
    @EnvironmentObject private var sessionViewModel: SessionViewModel
    @EnvironmentObject private var libraryViewModel: LibraryViewModel

    private struct ActivityItem: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let timestamp: Date
        let icon: String
        let tint: Color
    }
    
    private struct MetricTile: View {
        let title: String
        let value: String
        let icon: String
        let tint: Color
        
        var body: some View {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tint.opacity(0.16))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(tint)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.proSlate900)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.proSlate100, lineWidth: 1)
            )
        }
    }
    
    private struct TabGuideItem: Identifiable {
        let id = UUID()
        let tab: String
        let detail: String
        let icon: String
        let tint: Color
    }
    
    private var greetingName: String {
        let displayName = (sessionViewModel.currentUser?.displayName ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !displayName.isEmpty, displayName.count > 1 {
            return displayName
        }
        
        let emailPrefix = (sessionViewModel.currentUser?.email ?? "")
            .split(separator: "@")
            .first
            .map(String.init)?
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        return emailPrefix.isEmpty ? "Safety Team" : emailPrefix.capitalized
    }
    
    private var greetingPrefix: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<18:
            return "Good afternoon"
        default:
            return "Good evening"
        }
    }
    
    private var tabGuideItems: [TabGuideItem] {
        [
            TabGuideItem(tab: "Wizard", detail: "Create and export RAMS packs", icon: "wand.and.stars", tint: .proYellow),
            TabGuideItem(tab: "Libraries", detail: "Reuse hazards and prior docs", icon: "books.vertical", tint: .proTeal),
            TabGuideItem(tab: "Account", detail: "Review profile and session", icon: "person.circle", tint: .orange)
        ]
    }

    private var totalSavedDocuments: Int {
        libraryViewModel.library.masterDocuments.count +
            libraryViewModel.library.ramsDocuments.count +
            libraryViewModel.library.liftPlans.count
    }

    private var liftPlanIconName: String {
        "helmet"
    }

    private var highRiskCount: Int {
        libraryViewModel.library.ramsDocuments
            .filter { $0.overallRiskReview == .high || $0.overallRiskReview == .veryHigh }
            .count
    }

    private var recentActivity: [ActivityItem] {
        let master = libraryViewModel.library.masterDocuments.map {
            ActivityItem(
                title: $0.projectName.ifEmpty("Untitled project"),
                subtitle: "Master document",
                timestamp: $0.updatedAt,
                icon: "doc.text.fill",
                tint: .proTeal
            )
        }

        let rams = libraryViewModel.library.ramsDocuments.map {
            ActivityItem(
                title: $0.title.ifEmpty("Untitled RAMS"),
                subtitle: "RAMS (\($0.riskAssessments.count) hazards)",
                timestamp: $0.updatedAt,
                icon: "exclamationmark.shield.fill",
                tint: .proYellow
            )
        }

        let liftPlans = libraryViewModel.library.liftPlans.map {
            ActivityItem(
                title: $0.title.ifEmpty("Untitled lift plan"),
                subtitle: "Lift plan (\($0.category.rawValue))",
                timestamp: $0.updatedAt,
                icon: liftPlanIconName,
                tint: .orange
            )
        }

        return (master + rams + liftPlans)
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(6)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Operations Dashboard")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.74))
                        
                        Text("\(greetingPrefix), \(greetingName)")
                            .font(.title2.weight(.heavy))
                            .foregroundStyle(.white)
                        
                        Text("Use the bottom tabs to move between creation, libraries, and account management.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.84))
                        
                        if let latest = recentActivity.first {
                            HStack(spacing: 6) {
                                Image(systemName: "clock.badge.checkmark")
                                Text("Last update: \(DateFormatter.shortDateTime.string(from: latest.timestamp))")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.76))
                            .padding(.top, 2)
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(
                            colors: [Color.proSlate900, Color.proSlate800],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.proYellow.opacity(0.28), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.16), radius: 18, y: 9)

                    HStack(spacing: 10) {
                        MetricTile(
                            title: "Saved Docs",
                            value: "\(totalSavedDocuments)",
                            icon: "folder.fill.badge.plus",
                            tint: .proYellow
                        )
                        MetricTile(
                            title: "High Risk RAMS",
                            value: "\(highRiskCount)",
                            icon: "exclamationmark.triangle.fill",
                            tint: .orange
                        )
                    }
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        MetricTile(title: "Hazards", value: "\(libraryViewModel.library.hazards.count)", icon: "shield.lefthalf.filled", tint: .proTeal)
                        MetricTile(title: "Master Docs", value: "\(libraryViewModel.library.masterDocuments.count)", icon: "doc.on.doc.fill", tint: .proYellow)
                        MetricTile(title: "RAMS Docs", value: "\(libraryViewModel.library.ramsDocuments.count)", icon: "doc.text.magnifyingglass", tint: .orange)
                        MetricTile(title: "Lift Plans", value: "\(libraryViewModel.library.liftPlans.count)", icon: liftPlanIconName, tint: .orange)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent activity")
                            .font(.headline.weight(.semibold))

                        if recentActivity.isEmpty {
                            Text("No saved documents yet. Start from the Wizard tab to create your first RAMS pack.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                        } else {
                            ForEach(recentActivity) { item in
                                HStack(alignment: .top, spacing: 10) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                                            .fill(item.tint.opacity(0.16))
                                            .frame(width: 30, height: 30)
                                        Image(systemName: item.icon)
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(item.tint)
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.title)
                                            .font(.subheadline.weight(.semibold))
                                            .lineLimit(1)
                                        Text(item.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(DateFormatter.shortDateTime.string(from: item.timestamp))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.vertical, 3)
                            }
                        }
                    }
                    .proCard()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Tab guide")
                            .font(.headline.weight(.semibold))
                        
                        ForEach(tabGuideItems) { item in
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(item.tint.opacity(0.16))
                                        .frame(width: 30, height: 30)
                                    Image(systemName: item.icon)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(item.tint)
                                }
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.tab)
                                        .font(.subheadline.weight(.semibold))
                                    Text(item.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .proCard()

                    if let errorMessage = libraryViewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.red.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.red.opacity(0.18), lineWidth: 1)
                            )
                    }
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [Color.proSlate050, Color.white],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject private var sessionViewModel: SessionViewModel
    @EnvironmentObject private var libraryViewModel: LibraryViewModel

    var body: some View {
        TabView {
            UserHomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            WizardHostView(libraryViewModel: libraryViewModel)
                .tabItem {
                    Label("Wizard", systemImage: "wand.and.stars")
                }

            LibrariesHomeView()
                .environmentObject(libraryViewModel)
                .tabItem {
                    Label("Libraries", systemImage: "books.vertical")
                }

            accountView
                .tabItem {
                    Label("Account", systemImage: "person.circle")
                }
        }
        .tint(.proYellow)
        .task {
            libraryViewModel.loadIfNeeded()
        }
    }

    private var accountView: some View {
        NavigationStack {
            List {
                Section("Signed in") {
                    Text(sessionViewModel.currentUser?.email ?? "-")
                    Text(sessionViewModel.currentUser?.displayName ?? "-")
                }

                Section("Local library snapshot") {
                    HStack {
                        Text("Hazards")
                        Spacer()
                        Text("\(libraryViewModel.library.hazards.count)")
                    }
                    HStack {
                        Text("Master documents")
                        Spacer()
                        Text("\(libraryViewModel.library.masterDocuments.count)")
                    }
                    HStack {
                        Text("RAMS documents")
                        Spacer()
                        Text("\(libraryViewModel.library.ramsDocuments.count)")
                    }
                    HStack {
                        Text("Lift plans")
                        Spacer()
                        Text("\(libraryViewModel.library.liftPlans.count)")
                    }
                }

                if let libraryError = libraryViewModel.errorMessage {
                    Section("Storage") {
                        Text(libraryError)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        sessionViewModel.logout()
                    } label: {
                        Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Account")
        }
    }
}

private struct WizardHostView: View {
    @EnvironmentObject private var sessionViewModel: SessionViewModel
    @ObservedObject var libraryViewModel: LibraryViewModel
    @StateObject private var wizardViewModel: WizardViewModel

    init(libraryViewModel: LibraryViewModel) {
        self.libraryViewModel = libraryViewModel
        _wizardViewModel = StateObject(
            wrappedValue: WizardViewModel(libraryViewModel: libraryViewModel)
        )
    }

    var body: some View {
        WizardFlowView(
            viewModel: wizardViewModel,
            currentUserDisplayName: currentUserDisplayName
        )
    }

    private var currentUserDisplayName: String {
        let displayName = (sessionViewModel.currentUser?.displayName ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !displayName.isEmpty {
            return displayName
        }

        let emailPrefix = (sessionViewModel.currentUser?.email ?? "")
            .split(separator: "@")
            .first
            .map(String.init)?
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return emailPrefix.capitalized
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : self
    }
}
