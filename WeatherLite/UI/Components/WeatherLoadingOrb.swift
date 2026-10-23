import SwiftUI

struct WeatherLoadingOrb: View {
    var message: String? = nil

    @Environment(\.weatherLiteColorScheme) private var colors

    private static func pingPongProgress(time: TimeInterval, duration: TimeInterval) -> Double {
        let cycle = time.truncatingRemainder(dividingBy: duration * 2.0)
        let linear = cycle <= duration ? (cycle / duration) : (2.0 - cycle / duration)
        // Smooth ease-in-out approximation matching FastOutSlowIn
        return 0.5 - 0.5 * cos(.pi * linear)
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let scaleProgress = Self.pingPongProgress(time: now, duration: 1.6)
            let orbScale = 0.88 + (1.12 - 0.88) * scaleProgress
            let haloAlpha = 0.25 + (0.65 - 0.25) * scaleProgress

            let yProgress = Self.pingPongProgress(time: now, duration: 2.0)
            let cloudOffsetY = -4.0 + 8.0 * yProgress

            let xProgress = Self.pingPongProgress(time: now, duration: 2.4)
            let cloudOffsetX = -6.0 + 12.0 * xProgress

            VStack(spacing: 0) {
                ZStack {
                    Canvas { context, size in
                        let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
                        let outerRadius = min(size.width, size.height) / 2.0
                        let innerRadius = outerRadius * 0.55

                        let outerRect = CGRect(
                            x: center.x - outerRadius,
                            y: center.y - outerRadius,
                            width: outerRadius * 2.0,
                            height: outerRadius * 2.0
                        )
                        let outerGradient = Gradient(colors: [
                            Color(hex: 0xFFD54F, alpha: haloAlpha),
                            Color(hex: 0xFF9800, alpha: haloAlpha * 0.5),
                            Color.clear
                        ])
                        context.fill(
                            Path(ellipseIn: outerRect),
                            with: .radialGradient(
                                outerGradient,
                                center: center,
                                startRadius: 0,
                                endRadius: outerRadius
                            )
                        )

                        let innerRect = CGRect(
                            x: center.x - innerRadius,
                            y: center.y - innerRadius,
                            width: innerRadius * 2.0,
                            height: innerRadius * 2.0
                        )
                        let innerGradient = Gradient(colors: [
                            Color(hex: 0xFFF176),
                            Color(hex: 0xFFB300)
                        ])
                        context.fill(
                            Path(ellipseIn: innerRect),
                            with: .radialGradient(
                                innerGradient,
                                center: center,
                                startRadius: 0,
                                endRadius: innerRadius
                            )
                        )
                    }
                    .frame(width: 80, height: 80)
                    .scaleEffect(orbScale)

                    Image(systemName: "cloud.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 46, height: 46)
                        .foregroundStyle(colors.onSurface.opacity(0.85))
                        .offset(x: cloudOffsetX + 6.0, y: cloudOffsetY + 6.0)
                }
                .frame(width: 96, height: 96)

                if let message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Spacer()
                        .frame(height: 12)
                    Text(message)
                        .font(WeatherLiteTypography.bodyMedium)
                        .foregroundStyle(colors.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
}
