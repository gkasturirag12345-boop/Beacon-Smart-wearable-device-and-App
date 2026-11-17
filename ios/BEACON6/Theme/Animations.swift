//
//  Animations.swift
//  BEACON
//
//  Reusable animation helpers for smooth, modern transitions
//

import SwiftUI

struct AnimationConfig {

    // MARK: - Standard Animations

    /// Smooth spring animation for general UI transitions
    static let smooth = Animation.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)

    /// Quick spring for immediate feedback
    static let quick = Animation.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0)

    /// Bouncy animation for attention-grabbing elements
    static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0)

    /// Gentle ease for subtle changes
    static let gentle = Animation.easeInOut(duration: 0.3)

    /// Slow ease for major transitions
    static let slow = Animation.easeInOut(duration: 0.5)

    // MARK: - Alert & Status Animations

    /// Pulse animation for alerts
    static let pulse = Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)

    /// Heartbeat-style animation
    static let heartbeat = Animation.spring(response: 0.3, dampingFraction: 0.5)
        .repeatForever(autoreverses: true)

    /// Glow animation for important buttons
    static let glow = Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)

    // MARK: - Loading Animations

    /// Rotation for loading spinners
    static let rotation = Animation.linear(duration: 1.0).repeatForever(autoreverses: false)

    /// Fade in/out for loading states
    static let fade = Animation.easeInOut(duration: 0.4)
}

// MARK: - View Modifiers for Animated Effects

/// Shake animation for errors or alerts
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            translationX: amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
            y: 0
        ))
    }
}

extension View {
    /// Apply shake animation
    func shake(trigger: Int) -> some View {
        self.modifier(ShakeEffect(animatableData: CGFloat(trigger)))
    }

    /// Pulse scale effect (for alerts, notifications)
    func pulseEffect(isActive: Bool) -> some View {
        self
            .scaleEffect(isActive ? 1.05 : 1.0)
            .animation(AnimationConfig.pulse, value: isActive)
    }

    /// Glow effect for important elements
    func glowEffect(isActive: Bool, color: Color = .white) -> some View {
        self
            .shadow(
                color: isActive ? color.opacity(0.6) : color.opacity(0),
                radius: isActive ? 20 : 0
            )
            .animation(AnimationConfig.glow, value: isActive)
    }

    /// Smooth appearance animation
    func smoothAppear() -> some View {
        self
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                removal: .opacity
            ))
            .animation(AnimationConfig.smooth, value: UUID())
    }

    /// Slide in from bottom
    func slideInFromBottom() -> some View {
        self
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(AnimationConfig.smooth, value: UUID())
    }

    /// Fade and scale in
    func fadeAndScaleIn() -> some View {
        self
            .transition(.scale.combined(with: .opacity))
            .animation(AnimationConfig.gentle, value: UUID())
    }

    /// Loading shimmer effect
    func shimmer(isActive: Bool) -> some View {
        self.overlay(
            GeometryReader { geometry in
                if isActive {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.3),
                            Color.white.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: isActive ? geometry.size.width : -geometry.size.width)
                    .animation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false), value: isActive)
                }
            }
        )
        .clipped()
    }

    /// Heartbeat pulse (for heart rate display)
    func heartbeatPulse(isActive: Bool) -> some View {
        self
            .scaleEffect(isActive ? 1.1 : 1.0)
            .animation(AnimationConfig.heartbeat, value: isActive)
    }

    /// Success checkmark animation
    func successCheckmark(show: Bool) -> some View {
        self.overlay(
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.Colors.success)
                .scaleEffect(show ? 1.0 : 0.5)
                .opacity(show ? 1.0 : 0.0)
                .animation(AnimationConfig.bouncy, value: show)
        )
    }

    /// Error X animation
    func errorX(show: Bool) -> some View {
        self.overlay(
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.Colors.danger)
                .scaleEffect(show ? 1.0 : 0.5)
                .opacity(show ? 1.0 : 0.0)
                .animation(AnimationConfig.bouncy, value: show)
        )
    }
}

// MARK: - Number Animation (for smooth data transitions)

struct AnimatedNumber: View {
    let value: Int
    let font: Font
    let color: Color

    @State private var displayValue: Int = 0

    var body: some View {
        Text("\(displayValue)")
            .font(font)
            .foregroundColor(color)
            .contentTransition(.numericText(value: Double(displayValue)))
            .onChange(of: value) { oldValue, newValue in
                withAnimation(AnimationConfig.smooth) {
                    displayValue = newValue
                }
            }
            .onAppear {
                displayValue = value
            }
    }
}

// MARK: - Loading Spinner

struct ModernSpinner: View {
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(
                AngularGradient(
                    colors: [AppTheme.Colors.primary.opacity(0.2), AppTheme.Colors.primary],
                    center: .center
                ),
                style: StrokeStyle(lineWidth: 4, lineCap: .round)
            )
            .frame(width: 40, height: 40)
            .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
            .animation(AnimationConfig.rotation, value: isAnimating)
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Progress Ring

struct ProgressRing: View {
    let progress: Double // 0.0 to 1.0
    let color: Color
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(AnimationConfig.smooth, value: progress)
        }
    }
}

// MARK: - Haptic Feedback Helper

struct HapticFeedback {
    static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    static func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    static func heavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }

    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}
