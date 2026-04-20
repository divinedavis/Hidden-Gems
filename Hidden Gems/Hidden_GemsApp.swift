//
//  Hidden_GemsApp.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/16/26.
//

import SwiftUI

@main
struct Hidden_GemsApp: App {
    @State private var authManager = AuthManager()
    @State private var locationManager = LocationManager()

    var body: some Scene {
        WindowGroup {
            ZStack {
                if authManager.isRestoringSession {
                    SplashView()
                } else if authManager.isSignedIn {
                    ContentView()
                        .onAppear {
                            locationManager.requestPermission()
                        }
                } else {
                    LandingView()
                }
            }
            .environment(authManager)
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
