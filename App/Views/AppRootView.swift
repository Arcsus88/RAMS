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
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer(minLength: 12)

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.proYellow)
                            .frame(width: 42, height: 42)
                            .overlay {
                                Image(systemName: "shield.fill")
                                    .foregroundStyle(Color.proSlate900)
                                    .font(.headline.weight(.bold))
                            }
                        Text("ProRAMS Builder")
                            .font(.title2.weight(.heavy))
                            .foregroundStyle(.white)
                    }
                    Text("Create professional RAMS documents, lift plans, and sign-off packs.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Color.proSlate900)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(spacing: 12) {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.proSlate100, lineWidth: 1)
                        )

                    SecureField("Password", text: $password)
                        .padding(12)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.proSlate100, lineWidth: 1)
                        )

                    if let errorMessage = sessionViewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .font(.footnote)
                    }

                    Button {
                        Task {
                            await sessionViewModel.login(email: email, password: password)
                        }
                    } label: {
                        if sessionViewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .tint(Color.proSlate900)
                        } else {
                            Text("Login")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.proSlate900)
                    .padding(.vertical, 12)
                    .background(Color.proYellow)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(sessionViewModel.isLoading)
                }
                .padding()
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.proSlate100, lineWidth: 1)
                )

                Spacer()

                Text("Mock authentication for scaffold stage. Supabase auth can be integrated later.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(red: 248 / 255, green: 250 / 255, blue: 252 / 255))
            .navigationBarHidden(true)
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject private var sessionViewModel: SessionViewModel
    @EnvironmentObject private var libraryViewModel: LibraryViewModel

    var body: some View {
        TabView {
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
    @ObservedObject var libraryViewModel: LibraryViewModel
    @StateObject private var wizardViewModel: WizardViewModel

    init(libraryViewModel: LibraryViewModel) {
        self.libraryViewModel = libraryViewModel
        _wizardViewModel = StateObject(
            wrappedValue: WizardViewModel(libraryViewModel: libraryViewModel)
        )
    }

    var body: some View {
        WizardFlowView(viewModel: wizardViewModel)
    }
}
