//
//  Hidden_GemsApp.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/16/26.
//

import SwiftUI

enum AppScreen {
    case landing, auth
}

@main
struct Hidden_GemsApp: App {
    @State private var authManager = AuthManager()
    @State private var locationManager = LocationManager()
    @State private var screen: AppScreen = .landing

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if authManager.isRestoringSession {
                        SplashView()
                    } else if authManager.isSignedIn {
                        ContentView()
                            .environment(authManager)
                            .onAppear {
                                locationManager.requestPermission()
                            }
                    } else if authManager.needsProfileSetup {
                        ProfileSetupView()
                            .environment(authManager)
                    } else {
                        switch screen {
                        case .landing:
                            LandingView {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    screen = .auth
                                }
                            }
                            .transition(.opacity)
                        case .auth:
                            SignInView()
                                .environment(authManager)
                                .transition(.opacity)
                        }
                    }
                }
            }
            .environment(locationManager)
            .task {
                await authManager.restoreSession()
            }
        }
    }
}

private struct SplashView: View {
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 440, height: 440)
        }
    }
}
