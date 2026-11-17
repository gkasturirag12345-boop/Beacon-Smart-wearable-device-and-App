//
//  AlertBannerView.swift
//  BEACON6
//
//  In-app visual alert banner for immediate SOS feedback
//

import SwiftUI

struct AlertBannerView: View {
    let message: String
    let confidence: Float
    let detectionTime: String  // HH:mm:ss.SSS format
    let latencyMs: Double?  // Optional latency in milliseconds
    @Binding var isPresented: Bool

    @State private var opacity: Double = 0
    @State private var offset: CGFloat = -100

    var body: some View {
        VStack {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 4) {
                    Text("🚨 SOS DETECTED")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Text(message)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))

                    HStack(spacing: 12) {
                        Text("Confidence: \(Int(confidence * 100))%")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))

                        if let latency = latencyMs {
                            Text("| Latency: \(String(format: "%.0f", latency))ms")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }

                    Text("Detected at: \(detectionTime)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                // Close button
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [Color.red, Color.red.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 16)
            .padding(.top, 50) // Below status bar

            Spacer()
        }
        .opacity(opacity)
        .offset(y: offset)
        .onAppear {
            // Slide in animation
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                opacity = 1
                offset = 0
            }

            // Auto-dismiss after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                dismiss()
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.3)) {
            opacity = 0
            offset = -100
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
        }
    }
}

#Preview {
    ZStack {
        Color.blue.ignoresSafeArea()

        AlertBannerView(
            message: "SOS keyword detected with 97.5% confidence",
            confidence: 0.975,
            detectionTime: "14:32:15.789",
            latencyMs: 45.2,
            isPresented: .constant(true)
        )
    }
}
