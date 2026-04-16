//
//  AuthView.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/17/26.
//

import SwiftUI
import Supabase

// MARK: - Auth Manager

@Observable
class AuthManager {
    var isSignedIn = false
    var needsProfileSetup = false
    var currentUser: User = User(name: "", username: "", profileImageURL: "", followersCount: 0, followingCount: 0)
    var errorMessage: String?

    // Carried from sign up to profile setup
    var pendingEmail = ""
    var pendingUsername = ""
    var pendingAuthId: UUID?

    // MARK: Sign In
    func signIn(email: String, password: String) async {
        errorMessage = nil
        do {
            let session = try await supabase.auth.signIn(email: email, password: password)
            await loadProfile(authId: session.user.id)
        } catch {
            // Keep the user-facing message generic so we don't reveal
            // whether the email exists (account enumeration protection).
            // The real error is only logged in Debug builds.
            debugLog("Sign in error", error)
            errorMessage = "Incorrect email or password."
        }
    }

    // MARK: Sign Up
    func signUp(email: String, username: String, password: String) async {
        errorMessage = nil
        do {
            let response = try await supabase.auth.signUp(email: email, password: password)
            pendingEmail = email
            pendingUsername = username
            pendingAuthId = response.user.id
            needsProfileSetup = true
        } catch {
            debugLog("Sign up error", error)
            errorMessage = friendlySignUpMessage(for: error)
        }
    }

    /// Maps a Supabase auth error to a user-friendly message. We look at
    /// the raw description (Supabase-swift includes the server's error_code
    /// in there) and map known codes to actionable copy, falling back to
    /// a generic message so internal details never leak to the UI.
    private func friendlySignUpMessage(for error: Error) -> String {
        let raw = error.localizedDescription.lowercased()
        if raw.contains("already") || raw.contains("registered") || raw.contains("exists") {
            return "An account with this email already exists."
        }
        if raw.contains("email_address_invalid") || raw.contains("invalid email") || raw.contains("email address") && raw.contains("invalid") {
            return "That email address isn't accepted. Try a different one."
        }
        if raw.contains("weak_password") || raw.contains("password") && raw.contains("short") {
            return "Password is too weak. Use at least 8 characters with a mix of letters and numbers."
        }
        if raw.contains("rate limit") || raw.contains("too many requests") {
            return "Too many attempts. Please wait a moment and try again."
        }
        if raw.contains("network") || raw.contains("offline") || raw.contains("connection") {
            return "No internet connection. Check your connection and try again."
        }
        return "Sign up failed. Please try again."
    }

    // MARK: Complete Profile Setup
    func completeProfileSetup(firstName: String, lastName: String) async {
        guard let authId = pendingAuthId else { return }
        errorMessage = nil

        let fullName = "\(firstName) \(lastName)"
        let username = pendingUsername

        do {
            // Row is auto-created by the on_auth_user_created trigger.
            // We just fill in the details the user entered.
            try await supabase
                .from("users")
                .update([
                    "name": fullName,
                    "username": username
                ])
                .eq("id", value: authId.uuidString)
                .execute()

            var user = User(
                name: fullName,
                username: username,
                profileImageURL: "",
                followersCount: 0,
                followingCount: 0
            )
            user.id = authId
            currentUser = user
            needsProfileSetup = false
            isSignedIn = true
        } catch {
            debugLog("Profile setup error", error)
            errorMessage = "Could not save profile: \(error.localizedDescription)"
        }
    }

    // MARK: Load Profile
    func loadProfile(authId: UUID) async {
        do {
            struct UserRow: Codable {
                let id: UUID
                let name: String
                let username: String
                let profileImageUrl: String?
                let followersCount: Int?
                let followingCount: Int?
                enum CodingKeys: String, CodingKey {
                    case id, name, username
                    case profileImageUrl = "profile_image_url"
                    case followersCount = "followers_count"
                    case followingCount = "following_count"
                }
            }

            let rows: [UserRow] = try await supabase
                .from("users")
                .select()
                .eq("id", value: authId.uuidString)
                .limit(1)
                .execute()
                .value

            if let row = rows.first {
                var user = User(
                    name: row.name,
                    username: row.username,
                    profileImageURL: row.profileImageUrl ?? "",
                    followersCount: row.followersCount ?? 0,
                    followingCount: row.followingCount ?? 0
                )
                user.id = row.id
                currentUser = user
                isSignedIn = true
            } else {
                // Auth exists but no profile row yet — go to profile setup
                pendingAuthId = authId
                needsProfileSetup = true
            }
        } catch {
            errorMessage = "Could not load profile. Please try again."
        }
    }

    // MARK: Sign Out
    func signOut() {
        Task { try? await supabase.auth.signOut() }
        isSignedIn = false
        needsProfileSetup = false
        pendingEmail = ""
        pendingUsername = ""
        pendingAuthId = nil
        currentUser = User(name: "", username: "", profileImageURL: "", followersCount: 0, followingCount: 0)
    }
}

// MARK: - Sign In View

struct SignInView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var email = ""
    @State private var password = ""
    @State private var showingSignUp = false
    @State private var showingForgotPassword = false
    @State private var isLoading = false
    @FocusState private var focusedField: Field?

    enum Field { case email, password }

    private var canSignIn: Bool { !email.isEmpty && !password.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Logo
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 360, height: 360)
                        .padding(.top, 60)
                        .padding(.bottom, 48)

                    // Error
                    if let error = authManager.errorMessage {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .padding(.bottom, 12)
                    }

                    // Fields
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Email").font(.subheadline).fontWeight(.medium)
                            TextField("Enter your email", text: $email)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .focused($focusedField, equals: .email)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .submitLabel(.next)
                                .onSubmit { focusedField = .password }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Password").font(.subheadline).fontWeight(.medium)
                            SecureField("Enter your password", text: $password)
                                .textContentType(.password)
                                .focused($focusedField, equals: .password)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .submitLabel(.go)
                                .onSubmit { if canSignIn { handleSignIn() } }
                        }

                        HStack {
                            Spacer()
                            Button("Forgot Password?") { showingForgotPassword = true }
                                .font(.subheadline).foregroundStyle(.blue)
                        }
                    }
                    .padding(.horizontal)

                    // Sign in button
                    Button { handleSignIn() } label: {
                        Group {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Sign In").font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canSignIn ? Color.blue : Color(.systemGray4))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!canSignIn || isLoading)
                    .padding(.horizontal)
                    .padding(.top, 24)

                    // Divider
                    HStack {
                        Rectangle().fill(Color(.separator)).frame(height: 1)
                        Text("or").font(.subheadline).foregroundStyle(.secondary).padding(.horizontal, 12)
                        Rectangle().fill(Color(.separator)).frame(height: 1)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 28)

                    // Sign up link
                    VStack(spacing: 4) {
                        Text("Don't have an account?").font(.subheadline).foregroundStyle(.secondary)
                        Button("Create Account") { showingSignUp = true }
                            .font(.subheadline).fontWeight(.semibold).foregroundStyle(.blue)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationDestination(isPresented: $showingSignUp) {
                SignUpView()
            }
            .alert("Reset Password", isPresented: $showingForgotPassword) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("A password reset link will be sent to \(email.isEmpty ? "your email" : email).")
            }
        }
    }

    private func handleSignIn() {
        focusedField = nil
        isLoading = true
        Task {
            await authManager.signIn(email: email, password: password)
            isLoading = false
        }
    }
}

// MARK: - Sign Up View

struct SignUpView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var agreedToTerms = false
    @State private var isLoading = false
    @FocusState private var focusedField: Field?

    enum Field { case username, email, password, confirmPassword }

    private var passwordsMatch: Bool { password == confirmPassword }

    private var canSignUp: Bool {
        !username.isEmpty &&
        !email.isEmpty &&
        password.count >= 8 &&
        passwordsMatch &&
        agreedToTerms
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Text("Create Account").font(.largeTitle).fontWeight(.bold)
                    Text("Join and start sharing your hidden gems")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .padding(.top, 32)
                .padding(.bottom, 40)

                // Error
                if let error = authManager.errorMessage {
                    Text(error)
                        .font(.subheadline).foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                }

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Username").font(.subheadline).fontWeight(.medium)
                        TextField("Choose a username", text: $username)
                            .textContentType(.username)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($focusedField, equals: .username)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .submitLabel(.next)
                            .onSubmit { focusedField = .email }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Email").font(.subheadline).fontWeight(.medium)
                        TextField("Enter your email", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($focusedField, equals: .email)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Password").font(.subheadline).fontWeight(.medium)
                        SecureField("At least 8 characters", text: $password)
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .password)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .submitLabel(.next)
                            .onSubmit { focusedField = .confirmPassword }
                        if !password.isEmpty && password.count < 8 {
                            Text("Password must be at least 8 characters")
                                .font(.caption).foregroundStyle(.red).padding(.horizontal, 4)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Confirm Password").font(.subheadline).fontWeight(.medium)
                        SecureField("Re-enter your password", text: $confirmPassword)
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .confirmPassword)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .submitLabel(.go)
                            .onSubmit { if canSignUp { handleSignUp() } }
                        if !confirmPassword.isEmpty && !passwordsMatch {
                            Text("Passwords do not match")
                                .font(.caption).foregroundStyle(.red).padding(.horizontal, 4)
                        }
                    }

                    Toggle(isOn: $agreedToTerms) {
                        Text("I agree to the **Terms of Service** and **Privacy Policy**")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .tint(.blue)
                    .padding(.top, 4)
                }
                .padding(.horizontal)

                Button { handleSignUp() } label: {
                    Group {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Create Account").font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canSignUp ? Color.blue : Color(.systemGray4))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!canSignUp || isLoading)
                .padding(.horizontal)
                .padding(.top, 28)

                HStack(spacing: 4) {
                    Text("Already have an account?").font(.subheadline).foregroundStyle(.secondary)
                    Button("Sign In") { dismiss() }
                        .font(.subheadline).fontWeight(.semibold).foregroundStyle(.blue)
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationBarBackButtonHidden(false)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                focusedField = .username
            }
        }
    }

    private func handleSignUp() {
        focusedField = nil
        isLoading = true
        Task {
            await authManager.signUp(email: email, username: username, password: password)
            isLoading = false
        }
    }
}

// MARK: - Profile Setup View

struct ProfileSetupView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var isLoading = false
    @FocusState private var focusedField: Field?

    enum Field { case firstName, lastName }

    private var canContinue: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                Text("Set Up Your Profile").font(.largeTitle).fontWeight(.bold)
                Text("Let the community know who you are")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            if let error = authManager.errorMessage {
                Text(error)
                    .font(.subheadline).foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, 16)
            }

            Spacer().frame(height: 48)

            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("First Name").font(.subheadline).fontWeight(.medium)
                    TextField("Enter your first name", text: $firstName)
                        .textContentType(.givenName)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .firstName)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .submitLabel(.next)
                        .onSubmit { focusedField = .lastName }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Last Name").font(.subheadline).fontWeight(.medium)
                    TextField("Enter your last name", text: $lastName)
                        .textContentType(.familyName)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .lastName)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .submitLabel(.go)
                        .onSubmit { if canContinue { handleContinue() } }
                }
            }
            .padding(.horizontal)

            Spacer().frame(height: 32)

            Button { handleContinue() } label: {
                Group {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Continue").font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canContinue ? Color.blue : Color(.systemGray4))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!canContinue || isLoading)
            .padding(.horizontal)

            Spacer()
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                focusedField = .firstName
            }
        }
    }

    private func handleContinue() {
        focusedField = nil
        isLoading = true
        Task {
            await authManager.completeProfileSetup(firstName: firstName, lastName: lastName)
            isLoading = false
        }
    }
}

#Preview("Sign In") {
    SignInView().environment(AuthManager())
}

#Preview("Sign Up") {
    NavigationStack { SignUpView().environment(AuthManager()) }
}

#Preview("Profile Setup") {
    ProfileSetupView().environment(AuthManager())
}
