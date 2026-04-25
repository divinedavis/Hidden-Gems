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
                if authManager.isRestoring {
                    // Splash gate. Holds the screen while
                    // restoreSession() resolves so a cold launch
                    // doesn't briefly flash LandingView before
                    // swapping to ContentView for already-signed-in
                    // users.
                    Color.black.ignoresSafeArea()
                    ProgressView().tint(.white)
                } else if authManager.isSignedIn {
                    ContentView()
                        .onAppear {
                            #if DEBUG
                            // Screenshot harness: skip the permission prompt
                            // so it doesn't cover the first tab we capture.
                            if ProcessInfo.processInfo.environment["HG_TEST_EMAIL"] == nil {
                                locationManager.requestPermission()
                            }
                            #else
                            locationManager.requestPermission()
                            #endif
                        }
                } else {
                    LandingView()
                }
            }
            .environment(authManager)
            .environment(locationManager)
            .task {
                await authManager.restoreSession()
                #if DEBUG
                // Screenshot/demo harness: if HG_TEST_EMAIL and
                // HG_TEST_PASSWORD are present and no session was
                // restored, sign in automatically. Lets the README
                // capture script drive the app without synthesizing
                // taps into the Simulator.
                let env = ProcessInfo.processInfo.environment
                if !authManager.isSignedIn,
                   let email = env["HG_TEST_EMAIL"],
                   let password = env["HG_TEST_PASSWORD"] {
                    await authManager.signIn(email: email, password: password)
                }
                #endif
            }
        }
    }
}

