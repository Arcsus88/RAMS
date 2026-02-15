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
    @State private var mode: AuthMode = .login
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var rememberDevice = true
    @State private var isPasswordVisible = false
    @State private var isConfirmPasswordVisible = false

    private enum AuthMode: String, CaseIterable, Identifiable {
        case login = "Sign In"
        case register = "Register"

        var id: String { rawValue }
    }

    private enum Field {
        case firstName
        case lastName
        case email
        case password
        case confirmPassword
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

                        Text("Local auth scaffold with registration flow. Supabase auth can be integrated later.")
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
                Picker("Access mode", selection: $mode) {
                    ForEach(AuthMode.allCases) { currentMode in
                        Text(currentMode.rawValue).tag(currentMode)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 4) {
                    Text(mode == .login ? "Portal Access" : "Create Account")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(.white)
                    Text(mode == .login ? "Sign in with your work credentials" : "Register a new safety user profile")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))
                }

                if mode == .register {
                    nameFields
                }
                emailField
                passwordField

                if mode == .register {
                    confirmPasswordField
                } else {
                    rememberRow
                }

                if let errorMessage = sessionViewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.red.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 2)
                }

                Button {
                    submitAuthAction()
                } label: {
                    HStack(spacing: 8) {
                        if sessionViewModel.isLoading {
                            ProgressView()
                                .controlSize(.small)
                                .tint(Color.black)
                        }
                        Text(actionButtonTitle)
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

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Text(mode == .login ? "New Safety Officer?" : "Already Registered?")
                            .foregroundStyle(.white.opacity(0.48))
                        Button(mode == .login ? "Enroll Here" : "Sign In") {
                            mode = mode == .login ? .register : .login
                            sessionViewModel.errorMessage = nil
                            focusedField = nil
                        }
                        .foregroundStyle(Color.proYellow)
                        .fontWeight(.bold)
                    }
                    .font(.caption)

                    if mode == .login {
                        Text("Demo login: demo@probuild.com / demo123")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
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

    private var nameFields: some View {
        HStack(spacing: 10) {
            labeledCompactField(
                title: "FIRST NAME",
                placeholder: "Jane",
                symbol: "person.fill",
                text: $firstName,
                field: .firstName
            )
            labeledCompactField(
                title: "LAST NAME",
                placeholder: "Doe",
                symbol: "person.fill",
                text: $lastName,
                field: .lastName
            )
        }
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
                        focusedField = mode == .register ? .password : .password
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
                    if mode == .register {
                        focusedField = .confirmPassword
                    } else {
                        submitAuthAction()
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

    private var confirmPasswordField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CONFIRM PASSWORD")
                .font(.system(size: 10, weight: .black))
                .tracking(1.8)
                .foregroundStyle(.white.opacity(0.45))

            HStack(spacing: 10) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(iconColor(for: .confirmPassword))
                    .frame(width: 18)

                Group {
                    if isConfirmPasswordVisible {
                        TextField("••••••••", text: $confirmPassword)
                    } else {
                        SecureField("••••••••", text: $confirmPassword)
                    }
                }
                .focused($focusedField, equals: .confirmPassword)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .onSubmit {
                    submitAuthAction()
                }
                .foregroundStyle(.white)

                Button {
                    isConfirmPasswordVisible.toggle()
                } label: {
                    Image(systemName: isConfirmPasswordVisible ? "eye.fill" : "eye.slash.fill")
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
                    .stroke(borderColor(for: .confirmPassword), lineWidth: 1)
            )
        }
    }

    private func labeledCompactField(
        title: String,
        placeholder: String,
        symbol: String,
        text: Binding<String>,
        field: Field
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .black))
                .tracking(1.8)
                .foregroundStyle(.white.opacity(0.45))

            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .foregroundStyle(iconColor(for: field))
                    .frame(width: 18)
                TextField(placeholder, text: text)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: field)
                    .submitLabel(.next)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Color.black.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(borderColor(for: field), lineWidth: 1)
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

    private var actionButtonTitle: String {
        if sessionViewModel.isLoading {
            return mode == .login ? "ACCESSING CLOUD..." : "CREATING PROFILE..."
        }
        return mode == .login ? "INITIALIZE SESSION" : "REGISTER PROFILE"
    }

    private func submitAuthAction() {
        focusedField = nil
        Task {
            if mode == .login {
                await sessionViewModel.login(email: email, password: password)
            } else {
                await sessionViewModel.register(
                    firstName: firstName,
                    lastName: lastName,
                    email: email,
                    password: password,
                    confirmPassword: confirmPassword
                )
            }
        }
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

private enum DashboardTab: Hashable {
    case home
    case wizard
    case libraries
    case account
}

struct DashboardView: View {
    @EnvironmentObject private var sessionViewModel: SessionViewModel
    @EnvironmentObject private var libraryViewModel: LibraryViewModel
    @State private var selectedTab: DashboardTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            UserHomeView(
                onOpenWizard: { selectedTab = .wizard },
                onOpenLibraries: { selectedTab = .libraries },
                onOpenAccount: { selectedTab = .account }
            )
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(DashboardTab.home)

            WizardHostView(
                libraryViewModel: libraryViewModel,
                sessionViewModel: sessionViewModel
            )
                .tabItem {
                    Label("Wizard", systemImage: "wand.and.stars")
                }
                .tag(DashboardTab.wizard)

            LibrariesHomeView()
                .environmentObject(libraryViewModel)
                .tabItem {
                    Label("Libraries", systemImage: "books.vertical")
                }
                .tag(DashboardTab.libraries)

            accountView
                .tabItem {
                    Label("Account", systemImage: "person.circle")
                }
                .tag(DashboardTab.account)
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
                    Text("First name: \(sessionViewModel.currentUser?.firstName ?? "-")")
                    Text("Last name: \(sessionViewModel.currentUser?.lastName ?? "-")")
                    Text(sessionViewModel.currentUser?.displayName ?? "-")
                }

                Section("Local library snapshot") {
                    HStack {
                        Text("Projects")
                        Spacer()
                        Text("\(libraryViewModel.library.projects.count)")
                    }
                    HStack {
                        Text("Contacts")
                        Spacer()
                        Text("\(libraryViewModel.library.contacts.count)")
                    }
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
    @ObservedObject var libraryViewModel: LibraryViewModel
    @ObservedObject var sessionViewModel: SessionViewModel
    @StateObject private var wizardViewModel: WizardViewModel

    init(
        libraryViewModel: LibraryViewModel,
        sessionViewModel: SessionViewModel
    ) {
        self.libraryViewModel = libraryViewModel
        self.sessionViewModel = sessionViewModel
        _wizardViewModel = StateObject(
            wrappedValue: WizardViewModel(
                libraryViewModel: libraryViewModel,
                userProvider: { sessionViewModel.currentUser }
            )
        )
    }

    var body: some View {
        WizardFlowView(viewModel: wizardViewModel)
            .onAppear {
                wizardViewModel.applyCurrentUserDefaults()
            }
    }
}
