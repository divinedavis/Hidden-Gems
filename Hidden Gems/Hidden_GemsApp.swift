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
    @State private var showLanding = true

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isSignedIn {
                    ContentView()
                        .environment(authManager)
                        .onAppear {
                            locationManager.requestPermission()
                        }
                } else if authManager.needsProfileSetup {
                    ProfileSetupView()
                        .environment(authManager)
                } else if showLanding {
                    LandingView {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            showLanding = false
                        }
                    }
                } else {
                    SignInView()
                        .environment(authManager)
                }
            }
            .environment(locationManager)
        }
    }
}
