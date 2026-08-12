import SwiftUI

/// A circular indicator that empties out over a TOTP period, giving an
/// at-a-glance sense of how much time remains before the code refreshes.
struct CountdownRing: View {
    /// Fraction of the current period elapsed, in [0, 1).
    let progress: Double
    /// Whole seconds remaining until the next code, shown inside the ring.
    let secondsRemaining: Int

    private var remainingFraction: Double {
        1 - progress
    }

    private var color: Color {
        remainingFraction < 0.2 ? .red : .accentColor
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.25), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: max(remainingFraction, 0.001))
                .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
            Text("\(secondsRemaining)")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
        }
    }
}
