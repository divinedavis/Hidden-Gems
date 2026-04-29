//
//  AuthView.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/17/26.
//

import SwiftUI
import Supabase
import AuthenticationServices
import CryptoKit
import os

// MARK: - Auth Manager

private let authLogger = Logger(subsystem: "com.divinedavis.hiddengems", category: "auth")

@Observable
class AuthManager {
    var isSignedIn = false
    /// True from cold launch until `restoreSession()` finishes its
    /// initial fetch from the Supabase keychain. Lets the App scene
    /// hold a splash while we don't yet know whether the user is
    /// signed in, instead of flashing LandingView and then swapping
    /// to ContentView once the session resolves.
    var isRestoring = true
    var currentUser: User = User(name: "", username: "", profileImageURL: "", followersCount: 0, followingCount: 0)
    var errorMessage: String?
    /// In-memory copy of the avatar image the user most recently
    /// uploaded. Used by `ProfileView` to render the new picture the
    /// instant the upload finishes — `AsyncImage` still has to go
    /// fetch the public URL from the Supabase CDN, which would
    /// otherwise leave the circle blank for a beat after Save.
    var localAvatarImage: UIImage?

    func clearError() { errorMessage = nil }

    // MARK: Restore Session
    /// Restores the signed-in state from whatever the Supabase SDK has
    /// persisted locally (keychain on Apple platforms). We consider the
    /// user signed in as soon as the auth session is present — profile
    /// hydration runs afterwards and its failure does NOT sign the user
    /// out. A transient RLS or network failure used to force users back
    /// to the sign-in screen on every cold launch.
    func restoreSession() async {
        defer { isRestoring = false }
        do {
            let session = try await supabase.auth.session
            authLogger.info("restored session for user \(session.user.id, privacy: .public)")
            var user = currentUser
            user.id = session.user.id
            currentUser = user
            isSignedIn = true
            await loadProfile(authId: session.user.id)
        } catch {
            authLogger.info("no persisted session (\(String(describing: error), privacy: .public))")
        }
    }

    // MARK: Sign In
    func signIn(email: String, password: String) async {
        errorMessage = nil
        do {
            let session = try await supabase.auth.signIn(email: email, password: password)
            await loadProfile(authId: session.user.id)
            isSignedIn = true
        } catch {
            authLogger.error("sign in failed: \(String(describing: error), privacy: .public)")
            errorMessage = friendlySignInMessage(for: error)
        }
    }

    /// Maps Supabase's generic sign-in errors into actionable copy.
    /// "Incorrect email or password" is kept as the default catch-all
    /// so we don't reveal whether a given email exists (account
    /// enumeration protection), but we do surface email-confirmation
    /// and rate-limit cases so users know what to do.
    private func friendlySignInMessage(for error: Error) -> String {
        let raw = error.localizedDescription.lowercased()
        if raw.contains("email not confirmed") || raw.contains("not confirmed") || raw.contains("email_not_confirmed") {
            return "Please confirm your email first. Check your inbox for the confirmation link Supabase sent when you signed up."
        }
        if raw.contains("rate limit") || raw.contains("too many requests") || raw.contains("over_request_rate_limit") {
            return "Too many attempts. Wait a minute and try again."
        }
        if raw.contains("network") || raw.contains("offline") || raw.contains("connection") || raw.contains("internet") {
            return "No internet connection. Check your connection and try again."
        }
        if raw.contains("invalid login credentials") || raw.contains("invalid credentials") || raw.contains("invalid_grant") {
            return "Incorrect email or password."
        }
        return "Incorrect email or password."
    }

    // MARK: Sign In with Apple
    /// Exchanges an Apple identity token (plus the raw nonce we
    /// supplied to the Apple sign-in request) for a Supabase session.
    /// Requires the Apple provider to be enabled in the Supabase
    /// dashboard with this app's bundle id registered as a native
    /// client id.
    func signInWithApple(idToken: String, nonce: String, fullName: String?) async {
        errorMessage = nil
        do {
            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
            )
            let authId = session.user.id
            // If Apple gave us a name (only on the very first sign-in
            // for this Apple ID on this app), write it into the users
            // row so the profile isn't blank.
            if let fullName, !fullName.isEmpty {
                let usernameSeed = fullName
                    .lowercased()
                    .components(separatedBy: .whitespaces)
                    .joined()
                try? await supabase
                    .from("users")
                    .update(["name": fullName, "username": usernameSeed])
                    .eq("id", value: authId.uuidString)
                    .execute()
            }
            await loadProfile(authId: authId)
            isSignedIn = true
        } catch {
            authLogger.error("apple sign-in failed: \(String(describing: error), privacy: .public)")
            errorMessage = friendlyAppleErrorMessage(for: error)
        }
    }

    /// Maps Supabase errors we commonly see from the Apple id-token
    /// exchange into something actionable for the tester, while still
    /// surfacing the raw description when it's something we haven't
    /// explicitly classified.
    private func friendlyAppleErrorMessage(for error: Error) -> String {
        let raw = error.localizedDescription.lowercased()
        if raw.contains("provider") && (raw.contains("not enabled") || raw.contains("unsupported") || raw.contains("disabled")) {
            return "Apple provider isn't enabled in Supabase yet. Open Authentication → Providers → Apple and enable it."
        }
        if raw.contains("audience") || raw.contains("invalid_client") || raw.contains("client_id") {
            return "Apple provider is on, but this bundle id isn't registered. Add com.divinedavis.hiddengems under Apple → Client IDs (for native login)."
        }
        if raw.contains("nonce") {
            return "Nonce mismatch. Try the Apple button again."
        }
        return "Apple sign-in failed: \(error.localizedDescription)"
    }

    // MARK: Sign Up
    /// Creates the Supabase auth user, then fills in the profile row
    /// that the on_auth_user_created trigger inserted. One call, one
    /// screen — no separate profile-setup step.
    func signUp(email: String, password: String, fullName: String, username: String) async {
        errorMessage = nil
        do {
            let response = try await supabase.auth.signUp(email: email, password: password)
            let authId = response.user.id
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
            isSignedIn = true
        } catch {
            debugLog("Sign up error", error)
            errorMessage = friendlySignUpMessage(for: error)
        }
    }

    private func friendlySignUpMessage(for error: Error) -> String {
        let raw = error.localizedDescription.lowercased()
        if raw.contains("already") || raw.contains("registered") || raw.contains("exists") {
            return "An account with this email already exists."
        }
        if raw.contains("email_address_invalid") || raw.contains("invalid email") || (raw.contains("email address") && raw.contains("invalid")) {
            return "That email address isn't accepted. Try a different one."
        }
        if raw.contains("weak_password") || (raw.contains("password") && raw.contains("short")) {
            return "Password is too weak. Use at least 6 characters."
        }
        if raw.contains("rate limit") || raw.contains("too many requests") {
            return "Too many attempts. Please wait a moment and try again."
        }
        if raw.contains("network") || raw.contains("offline") || raw.contains("connection") {
            return "No internet connection. Check your connection and try again."
        }
        return "Sign up failed. Please try again."
    }

    // MARK: Load Profile
    func loadProfile(authId: UUID) async {
        do {
            struct UserRow: Codable {
                let id: UUID
                let name: String
                let username: String
                let profileImageUrl: String?
                let bio: String?
                let followersCount: Int?
                let followingCount: Int?
                enum CodingKeys: String, CodingKey {
                    case id, name, username, bio
                    case profileImageUrl = "profile_image_url"
                    case followersCount = "followers_count"
                    case followingCount = "following_count"
                }
            }

            // Queries the `user_profiles` view instead of the raw
            // `users` table so followers_count / following_count are
            // populated from live aggregates over the follows table.
            let rows: [UserRow] = try await supabase
                .from("user_profiles")
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
                    bio: row.bio ?? "",
                    followersCount: row.followersCount ?? 0,
                    followingCount: row.followingCount ?? 0
                )
                user.id = row.id
                currentUser = user
                isSignedIn = true
            } else {
                // Trigger should have inserted on sign-up, but at least
                // one Apple private-relay user landed without a public
                // row, which made every FK-bound write (saves, follows,
                // comments) silently fail. Self-heal by upserting a
                // minimal row keyed on auth.uid() — RLS allows it.
                await ensureProfileRow(authId: authId)
            }
        } catch {
            authLogger.error("profile fetch failed: \(String(describing: error), privacy: .public)")
            if !isSignedIn {
                errorMessage = "Could not load profile. Please try again."
            }
        }
    }

    /// Idempotently inserts a public.users row for the current auth
    /// user, then re-runs loadProfile. Used as a self-heal when the
    /// on_auth_user_created trigger didn't (or couldn't) populate the
    /// row at sign-up time. RLS allows the insert because we set
    /// `id = auth.uid()`.
    private func ensureProfileRow(authId: UUID) async {
        struct InsertRow: Encodable {
            let id: String
            let name: String
            let username: String
            let email: String
            let bio: String
        }
        let email = (try? await supabase.auth.session.user.email) ?? ""
        let usernameSeed = "user_" + authId.uuidString
            .lowercased()
            .replacingOccurrences(of: "-", with: "")
            .prefix(12)
        let row = InsertRow(
            id: authId.uuidString,
            name: "",
            username: String(usernameSeed),
            email: email,
            bio: ""
        )
        do {
            try await supabase
                .from("users")
                .upsert(row, onConflict: "id", ignoreDuplicates: true)
                .execute()
            authLogger.info("self-healed missing profile row for \(authId, privacy: .public)")
            // Now that the row exists, mark the user signed in even if
            // the live user_profiles fetch never returned anything.
            var user = User(
                name: "",
                username: String(usernameSeed),
                profileImageURL: "",
                followersCount: 0,
                followingCount: 0
            )
            user.id = authId
            currentUser = user
            isSignedIn = true
        } catch {
            authLogger.error("profile self-heal failed: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: Edit Profile
    /// Persists any subset of editable profile fields. A nil argument
    /// means "leave this field alone." Storage RLS allows writes only
    /// under `avatars/<auth.uid()>/…`, so the image path is rooted at
    /// the current user's id. On success, the just-uploaded UIImage
    /// is cached in `localAvatarImage` so the profile header can
    /// render it immediately without waiting for `AsyncImage` to
    /// round-trip the new URL from the CDN.
    func updateProfile(image: UIImage? = nil, bio: String? = nil) async throws {
        let authId = currentUser.id
        var uploadedImageURL: String?
        if let image {
            uploadedImageURL = try await MediaUploader.uploadJPEG(
                image,
                kind: .avatars,
                ownerId: authId
            )
        }
        let trimmedBio = bio.map { String($0.prefix(140)) }
        if let uploadedImageURL, let trimmedBio {
            struct Both: Encodable { let profile_image_url: String; let bio: String }
            try await supabase.from("users")
                .update(Both(profile_image_url: uploadedImageURL, bio: trimmedBio))
                .eq("id", value: authId.uuidString)
                .execute()
        } else if let uploadedImageURL {
            struct Pic: Encodable { let profile_image_url: String }
            try await supabase.from("users")
                .update(Pic(profile_image_url: uploadedImageURL))
                .eq("id", value: authId.uuidString)
                .execute()
        } else if let trimmedBio {
            struct Bio: Encodable { let bio: String }
            try await supabase.from("users")
                .update(Bio(bio: trimmedBio))
                .eq("id", value: authId.uuidString)
                .execute()
        } else {
            return
        }
        var user = currentUser
        if let uploadedImageURL { user.profileImageURL = uploadedImageURL }
        if let trimmedBio { user.bio = trimmedBio }
        currentUser = user
        if let image { localAvatarImage = image }
    }

    /// Compatibility shim for callers that only want to swap the
    /// avatar. New code should prefer `updateProfile(image:bio:)`.
    func updateProfileImage(_ image: UIImage) async throws {
        try await updateProfile(image: image, bio: nil)
    }

    // MARK: Sign Out
    func signOut() {
        Task { try? await supabase.auth.signOut() }
        isSignedIn = false
        currentUser = User(name: "", username: "", profileImageURL: "", followersCount: 0, followingCount: 0)
    }
}

// MARK: - Email Auth Sheet

/// Single sheet that handles both sign-in and sign-up. Mode toggles
/// in-place with a cross-fade so the extra fields (name, username,
/// confirm password) slide in/out without re-presenting the sheet.
struct EmailAuthSheet: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    enum Mode { case signIn, signUp }
    enum Field { case name, username, email, password, confirm }

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var fullName = ""
    @State private var username = ""
    @State private var isSubmitting = false
    @FocusState private var focused: Field?

    private let ink = Color(red: 0.10, green: 0.10, blue: 0.12)

    private var passwordsMatch: Bool {
        mode == .signIn || (password == confirmPassword && !confirmPassword.isEmpty)
    }

    private var canSubmit: Bool {
        let emailOk = !email.trimmingCharacters(in: .whitespaces).isEmpty
        let pwOk = password.count >= 6
        let nameOk = mode == .signIn || !fullName.trimmingCharacters(in: .whitespaces).isEmpty
        let usernameOk = mode == .signIn || !username.trimmingCharacters(in: .whitespaces).isEmpty
        return emailOk && pwOk && nameOk && usernameOk && passwordsMatch
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(ink.opacity(0.65))
                        }
                        Spacer()
                    }
                    .padding(.bottom, 24)

                    Text(mode == .signIn ? "Welcome back." : "Let's get started.")
                        .font(.subheadline)
                        .foregroundStyle(ink.opacity(0.55))
                        .padding(.bottom, 8)
                        .contentTransition(.opacity)

                    Text(mode == .signIn ? "Sign in to\nyour gems." : "Join Hidden\nGems.")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(ink)
                        .lineSpacing(-4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 12)
                        .contentTransition(.opacity)

                    Text("Restaurant recommendations from people who know the neighborhood.")
                        .font(.subheadline)
                        .foregroundStyle(ink.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 28)

                    VStack(spacing: 4) {
                        if mode == .signUp {
                            UnderlinedField(
                                "Full name",
                                text: $fullName,
                                ink: ink,
                                field: .name,
                                focused: $focused
                            )
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.next)
                            .onSubmit { focused = .username }

                            UnderlinedField(
                                "Username",
                                text: $username,
                                ink: ink,
                                field: .username,
                                focused: $focused
                            )
                            .textContentType(.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.next)
                            .onSubmit { focused = .email }
                        }

                        UnderlinedField(
                            "Email",
                            text: $email,
                            ink: ink,
                            field: .email,
                            focused: $focused
                        )
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .onSubmit { focused = .password }

                        UnderlinedSecureField(
                            "Password",
                            text: $password,
                            ink: ink,
                            field: .password,
                            focused: $focused
                        )
                        .textContentType(mode == .signIn ? .password : .newPassword)
                        .submitLabel(mode == .signIn ? (canSubmit ? .go : .return) : .next)
                        .onSubmit {
                            if mode == .signIn {
                                if canSubmit { submit() }
                            } else {
                                focused = .confirm
                            }
                        }

                        if mode == .signUp {
                            UnderlinedSecureField(
                                "Confirm password",
                                text: $confirmPassword,
                                ink: ink,
                                field: .confirm,
                                focused: $focused
                            )
                            .textContentType(.newPassword)
                            .submitLabel(canSubmit ? .join : .return)
                            .onSubmit {
                                if canSubmit { submit() }
                            }
                        }
                    }
                    .padding(.bottom, 20)

                    if mode == .signUp, !confirmPassword.isEmpty, password != confirmPassword {
                        Label("Passwords don't match.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .padding(.bottom, 12)
                    } else if let err = authManager.errorMessage {
                        Text(err)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .padding(.bottom, 12)
                    }

                    Button {
                        submit()
                    } label: {
                        Group {
                            if isSubmitting {
                                ProgressView().tint(.white)
                            } else {
                                Text(mode == .signIn ? "Sign In" : "Create Account")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .foregroundStyle(.white)
                        .background(Capsule().fill(ink))
                    }
                    .disabled(!canSubmit || isSubmitting)
                    .opacity(canSubmit ? 1 : 0.4)
                    .padding(.top, 8)

                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                mode = (mode == .signIn) ? .signUp : .signIn
                                confirmPassword = ""
                                authManager.clearError()
                            }
                        } label: {
                            Text(mode == .signIn
                                 ? "Don't have an account? Sign up"
                                 : "Already have an account? Sign in")
                                .font(.footnote)
                                .foregroundStyle(ink.opacity(0.6))
                                .underline()
                                .contentTransition(.opacity)
                        }
                        Spacer()
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 28)
                .padding(.top, 20)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onChange(of: authManager.isSignedIn) { _, newValue in
            if newValue { dismiss() }
        }
    }

    private func submit() {
        focused = nil
        isSubmitting = true
        Task {
            switch mode {
            case .signIn:
                await authManager.signIn(email: email, password: password)
            case .signUp:
                await authManager.signUp(
                    email: email,
                    password: password,
                    fullName: fullName,
                    username: username
                )
            }
            isSubmitting = false
        }
    }
}

// MARK: - Underlined Fields

/// Underlined field with an always-visible caption label above it
/// (the plain Apple placeholder is too faint to be readable when
/// the user is scanning the form for the first time). Label color
/// deepens on focus to reinforce which field is active.
private struct UnderlinedField: View {
    let label: String
    @Binding var text: String
    let ink: Color
    let field: EmailAuthSheet.Field
    @FocusState.Binding var focused: EmailAuthSheet.Field?

    init(
        _ label: String,
        text: Binding<String>,
        ink: Color,
        field: EmailAuthSheet.Field,
        focused: FocusState<EmailAuthSheet.Field?>.Binding
    ) {
        self.label = label
        self._text = text
        self.ink = ink
        self.field = field
        self._focused = focused
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.footnote.weight(.medium))
                .foregroundStyle(focused == field ? ink : ink.opacity(0.55))
                .animation(.easeInOut(duration: 0.15), value: focused)
            TextField("", text: $text)
                .focused($focused, equals: field)
                .font(.body)
                .foregroundStyle(ink)
                .padding(.vertical, 10)
            Rectangle()
                .fill(focused == field ? ink.opacity(0.6) : ink.opacity(0.2))
                .frame(height: 1)
                .animation(.easeInOut(duration: 0.15), value: focused)
        }
    }
}

private struct UnderlinedSecureField: View {
    let label: String
    @Binding var text: String
    let ink: Color
    let field: EmailAuthSheet.Field
    @FocusState.Binding var focused: EmailAuthSheet.Field?

    init(
        _ label: String,
        text: Binding<String>,
        ink: Color,
        field: EmailAuthSheet.Field,
        focused: FocusState<EmailAuthSheet.Field?>.Binding
    ) {
        self.label = label
        self._text = text
        self.ink = ink
        self.field = field
        self._focused = focused
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.footnote.weight(.medium))
                .foregroundStyle(focused == field ? ink : ink.opacity(0.55))
                .animation(.easeInOut(duration: 0.15), value: focused)
            SecureField("", text: $text)
                .focused($focused, equals: field)
                .font(.body)
                .foregroundStyle(ink)
                .padding(.vertical, 10)
            Rectangle()
                .fill(focused == field ? ink.opacity(0.6) : ink.opacity(0.2))
                .frame(height: 1)
                .animation(.easeInOut(duration: 0.15), value: focused)
        }
    }
}

// MARK: - Apple Sign In helpers

/// Generates a cryptographically strong random string suitable for
/// use as a Sign in with Apple nonce. Apple's identity token encodes
/// SHA256(this value); Supabase verifies by hashing the raw nonce we
/// pass and comparing.
enum AppleSignInNonce {
    static func random(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        for byte in bytes {
            result.append(charset[Int(byte) % charset.count])
        }
        return result
    }

    static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hashed = SHA256.hash(data: data)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

#Preview("Email Auth Sheet") {
    Color.blue
        .sheet(isPresented: .constant(true)) {
            EmailAuthSheet().environment(AuthManager())
        }
}
