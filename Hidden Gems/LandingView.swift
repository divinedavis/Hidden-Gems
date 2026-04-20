//
//  LandingView.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/31/26.
//

import SwiftUI

// MARK: - Landing View

struct LandingView: View {
    @State private var topOpacity: Double = 0
    @State private var brandOpacity: Double = 0
    @State private var bottomOpacity: Double = 0
    @State private var bodyOpacity: Double = 0
    @State private var bodyOffset: CGFloat = 20
    @State private var buttonOpacity: Double = 0
    @State private var buttonOffset: CGFloat = 24

    var onGetStarted: () -> Void

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

                // Buttons
                VStack(spacing: 12) {
                    Button(action: onGetStarted) {
                        HStack(spacing: 8) {
                            Image(systemName: "apple.logo")
                                .font(.body.weight(.semibold))
                            Text("Continue with Apple")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(.white, in: Capsule())
                        .foregroundStyle(.black)
                    }

                    Button(action: onGetStarted) {
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
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .opacity(buttonOpacity)
                .offset(y: buttonOffset)
            }
        }
        .task {
            withAnimation(.easeOut(duration: 0.5).delay(0.05)) { topOpacity = 1.0 }
            withAnimation(.easeOut(duration: 0.5).delay(0.15)) { brandOpacity = 1.0 }
            withAnimation(.easeOut(duration: 0.5).delay(0.25)) { bottomOpacity = 1.0 }
            withAnimation(.easeOut(duration: 0.55).delay(0.35)) {
                bodyOpacity = 1.0
                bodyOffset = 0
            }
            withAnimation(.easeOut(duration: 0.55).delay(0.5)) {
                buttonOpacity = 1.0
                buttonOffset = 0
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
    LandingView(onGetStarted: {})
}
