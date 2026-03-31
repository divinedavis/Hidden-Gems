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
            .onAppear {
                withAnimation(
                    .easeOut(duration: 1.2)
                    .delay(Double(index) * 0.15)
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
            .onAppear {
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
            // Background
            Color.black.ignoresSafeArea()

            // Animated rings
            ZStack {
                ForEach(0..<6, id: \.self) { i in
                    AnimatedRing(
                        index: i,
                        color1: ringColor1(for: i),
                        color2: ringColor2(for: i)
                    )
                }
            }
            .offset(y: -40)

            // Pulsing glows
            PulsingGlow(color: .blue, size: 300)
                .offset(x: -80, y: -200)
            PulsingGlow(color: .purple, size: 250)
                .offset(x: 100, y: 100)
            PulsingGlow(color: .indigo, size: 200)
                .offset(x: -60, y: 200)

            // Content
            VStack(spacing: 0) {
                Spacer()

                // Gem icon
                Image(systemName: "gem.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(gemScale)
                    .opacity(gemOpacity)
                    .rotationEffect(.degrees(gemRotation))
                    .shadow(color: .blue.opacity(0.5), radius: 20)
                    .padding(.bottom, 20)

                // Title
                Text("Hidden Gems")
                    .font(.system(size: 46, weight: .bold, design: .default))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .blue.opacity(0.3), radius: 10)
                    .opacity(titleOpacity)
                    .offset(y: titleOffset)

                // Subtitle
                Text("Discover restaurants worth finding")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.6))
                    .opacity(subtitleOpacity)
                    .padding(.top, 10)

                Spacer()

                // Get Started button
                Button(action: onGetStarted) {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .blue.opacity(0.4), radius: 12, y: 4)
                }
                .padding(.horizontal, 32)
                .opacity(buttonOpacity)
                .offset(y: buttonOffset)

                // Sign in link
                HStack(spacing: 4) {
                    Text("Already have an account?")
                        .foregroundStyle(.white.opacity(0.4))
                    Button("Sign In") {
                        onGetStarted()
                    }
                    .foregroundStyle(.blue)
                    .fontWeight(.semibold)
                }
                .font(.subheadline)
                .opacity(buttonOpacity)
                .padding(.top, 16)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            // Gem icon entrance
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2)) {
                gemScale = 1.0
                gemOpacity = 1.0
                gemRotation = 0
            }
            // Title entrance
            withAnimation(.easeOut(duration: 0.8).delay(0.5)) {
                titleOpacity = 1.0
                titleOffset = 0
            }
            // Subtitle entrance
            withAnimation(.easeOut(duration: 0.8).delay(0.8)) {
                subtitleOpacity = 1.0
            }
            // Button entrance
            withAnimation(.easeOut(duration: 0.8).delay(1.1)) {
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
