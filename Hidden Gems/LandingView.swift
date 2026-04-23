//
//  LandingView.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/31/26.
//

import SwiftUI
import AuthenticationServices

// MARK: - Landing View

struct LandingView: View {
    @Environment(AuthManager.self) private var authManager

    @State private var topOpacity: Double = 0
    @State private var brandOpacity: Double = 0
    @State private var bottomOpacity: Double = 0
    @State private var bodyOpacity: Double = 0
    @State private var bodyOffset: CGFloat = 20
    @State private var showEmailAuth = false
    @State private var currentNonce: String?
    @State private var appleErrorMessage: String?

    var body: some View {
        ZStack {
            gradient

            VStack(spacing: 0) {
                Spacer()

                // Stacked verbs: Discover / Hidden Gems / Share
                VStack(spacing: 6) {
                    Text("Discover")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.white.opacity(0.35))
                        .opacity(topOpacity)
                    Text("Hidden Gems")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(.white)
                        .opacity(brandOpacity)
                    Text("Share")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.white.opacity(0.35))
                        .opacity(bottomOpacity)
                }

                Spacer()

                // Icon + headline + subtitle
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                    Text("Local spots.\nActually good.")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    Text("Restaurant recommendations from people who know the neighborhood.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .opacity(bodyOpacity)
                .offset(y: bodyOffset)

                Spacer()

                // Buttons — rendered opaque at t=0 so the first tap is
                // processed immediately. Staggering their reveal with
                // the text intro queued taps behind in-flight animations
                // and made "Continue with Apple" feel laggy on cold
                // launch.
                VStack(spacing: 12) {
                    SignInWithAppleButton(.continue) { request in
                        // Nonce is pre-generated in .task so the tap
                        // path does zero work before handing off to
                        // AuthenticationServices.
                        let nonce = currentNonce ?? AppleSignInNonce.random()
                        currentNonce = nonce
                        appleErrorMessage = nil
                        authManager.clearError()
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = AppleSignInNonce.sha256(nonce)
                    } onCompletion: { result in
                        handleAppleResult(result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 52)
                    .clipShape(Capsule())

                    Button {
                        openEmailAuth()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "envelope.fill")
                            Text("Continue with email")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(.white.opacity(0.2), in: Capsule())
                        .foregroundStyle(.white)
                    }

                    if let appleErrorMessage {
                        Text(appleErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.white)
                            .padding(.top, 2)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .task {
            if currentNonce == nil {
                currentNonce = AppleSignInNonce.random()
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.05)) { topOpacity = 1.0 }
            withAnimation(.easeOut(duration: 0.5).delay(0.15)) { brandOpacity = 1.0 }
            withAnimation(.easeOut(duration: 0.5).delay(0.25)) { bottomOpacity = 1.0 }
            withAnimation(.easeOut(duration: 0.55).delay(0.35)) {
                bodyOpacity = 1.0
                bodyOffset = 0
            }
        }
        .sheet(isPresented: $showEmailAuth) {
            EmailAuthSheet()
                .environment(authManager)
                .presentationCornerRadius(28)
        }
    }

    private func openEmailAuth() {
        authManager.clearError()
        showEmailAuth = true
    }

    /// Bridges the `SignInWithAppleButton` completion to `AuthManager`.
    /// On success we have an identity token (a JWT Apple signed with
    /// the nonce-hash we provided). We pass the raw nonce to Supabase
    /// so it can verify that hash against the token.
    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard
                let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let nonce = currentNonce
            else {
                appleErrorMessage = "Couldn't read Apple credential. Try again."
                return
            }
            let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            Task {
                await authManager.signInWithApple(
                    idToken: idToken,
                    nonce: nonce,
                    fullName: fullName.isEmpty ? nil : fullName
                )
                if let err = authManager.errorMessage {
                    appleErrorMessage = err
                }
            }
        case .failure(let error):
            // User-cancelled is not an error worth showing.
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                appleErrorMessage = error.localizedDescription
            }
        }
    }

    private var gradient: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color.black,
                Color.blue.opacity(0.35),
                Color.blue.opacity(0.75),
                Color.blue
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

#Preview {
    LandingView().environment(AuthManager())
}
