//
//  LandingView.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/31/26.
//

import SwiftUI

// MARK: - Animated Ring

struct AnimatedRing: View {
    let index: Int
    let color1: Color
    let color2: Color
    @State private var scale: CGFloat = 0.3
    @State private var opacity: Double = 0
    @State private var rotation: Double = 0

    var body: some View {
        Circle()
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [color1, color2, color1]),
                    center: .center,
                    startAngle: .degrees(0),
                    endAngle: .degrees(360)
                ),
                lineWidth: 2
            )
            .frame(width: 100 + CGFloat(index) * 80, height: 100 + CGFloat(index) * 80)
            .scaleEffect(scale)
            .opacity(opacity)
            .rotationEffect(.degrees(rotation))
            .task {
                withAnimation(
                    .easeOut(duration: 0.7)
                    .delay(Double(index) * 0.06)
                ) {
                    scale = 1.0
                    opacity = 0.6 - Double(index) * 0.08
                }
                withAnimation(
                    .linear(duration: Double(8 + index * 3))
                    .repeatForever(autoreverses: false)
                ) {
                    rotation = index.isMultiple(of: 2) ? 360 : -360
                }
            }
    }
}

// MARK: - Pulsing Glow

struct PulsingGlow: View {
    let color: Color
    let size: CGFloat
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.3

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [color.opacity(0.4), color.opacity(0)]),
                    center: .center,
                    startRadius: 0,
                    endRadius: size / 2
                )
            )
            .frame(width: size, height: size)
            .scaleEffect(scale)
            .opacity(opacity)
            .task {
                try? await Task.sleep(nanoseconds: 100_000_000)
                withAnimation(
                    .easeInOut(duration: 3)
                    .repeatForever(autoreverses: true)
                ) {
                    scale = 1.2
                    opacity = 0.6
                }
            }
    }
}

// MARK: - Landing View

struct LandingView: View {
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 30
    @State private var subtitleOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var buttonOffset: CGFloat = 20
    @State private var gemScale: CGFloat = 0.2
    @State private var gemOpacity: Double = 0
    @State private var gemRotation: Double = -30

    var onGetStarted: () -> Void

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 440, height: 440)
                    .scaleEffect(gemScale)
                    .opacity(gemOpacity)
                    .rotationEffect(.degrees(gemRotation))
                    .padding(.bottom, 20)


                Spacer()

                // Get Started button
                Button(action: onGetStarted) {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 32)
                .opacity(buttonOpacity)
                .offset(y: buttonOffset)

                // Sign in link
                HStack(spacing: 4) {
                    Text("Already have an account?")
                        .foregroundStyle(.secondary)
                    Button("Sign In") {
                        onGetStarted()
                    }
                    .foregroundStyle(.black)
                    .fontWeight(.semibold)
                }
                .font(.subheadline)
                .opacity(buttonOpacity)
                .padding(.top, 16)
                .padding(.bottom, 50)
            }
        }
        .task {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                gemScale = 1.0
                gemOpacity = 1.0
                gemRotation = 0
            }
            withAnimation(.easeOut(duration: 0.45).delay(0.1)) {
                titleOpacity = 1.0
                titleOffset = 0
            }
            withAnimation(.easeOut(duration: 0.45).delay(0.2)) {
                subtitleOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.45).delay(0.25)) {
                buttonOpacity = 1.0
                buttonOffset = 0
            }
        }
    }

    private func ringColor1(for index: Int) -> Color {
        let colors: [Color] = [.blue, .purple, .indigo, .cyan, .pink, .blue]
        return colors[index % colors.count]
    }

    private func ringColor2(for index: Int) -> Color {
        let colors: [Color] = [.purple, .pink, .blue, .indigo, .purple, .cyan]
        return colors[index % colors.count]
    }
}

#Preview {
    LandingView(onGetStarted: {})
}
