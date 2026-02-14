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
                Spacer(minLength: 16)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Construction RAMS Builder")
                        .font(.largeTitle.weight(.bold))
                    Text("Create Master Documents, RAMS and Lift Plans with reusable libraries.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)

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
                        } else {
                            Text("Login")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(sessionViewModel.isLoading)
                }
                .padding()
                .background(Color.secondary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Spacer()

                Text("Mock authentication for scaffold stage. Supabase auth can be integrated later.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
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
