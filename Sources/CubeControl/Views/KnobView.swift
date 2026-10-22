import SwiftUI
import UIKit

public struct KnobView: View {
    public let title: String
    public let value: Int
    public let maxValue: Int
    public let tintColor: Color
    public let isBipolarMod: Bool
    public let onValueChanged: (Int) -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var initialValue: Int = 0
    private let feedback = UIImpactFeedbackGenerator(style: .light)

    public init(
        title: String,
        value: Int,
        maxValue: Int,
        tintColor: Color = Color.cyan,
        isBipolarMod: Bool = false,
        onValueChanged: @escaping (Int) -> Void
    ) {
        self.title = title
        self.value = value
        self.maxValue = maxValue
        self.tintColor = tintColor
        self.isBipolarMod = isBipolarMod
        self.onValueChanged = onValueChanged
    }

    private var normalizedFraction: Double {
        guard maxValue > 0 else { return 0 }
        return Double(value) / Double(maxValue)
    }

    private var displayString: String {
        if isBipolarMod {
            if value == 7 || value == 8 { return "OFF" }
            if value < 7 { return "CH-\(value)" }
            return "PH-\(value - 8)"
        }
        if value == 0 && (title == "REVERB" || title == "MIX" || title == "MOD") {
            return "OFF"
        }
        return "\(value)"
    }

    // Angle: -135 deg to +135 deg (270 deg total travel)
    private var angleDegrees: Double {
        return -135.0 + (normalizedFraction * 270.0)
    }

    public var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Background Track
                Circle()
                    .trim(from: 0.125, to: 0.875)
                    .stroke(
                        Color.white.opacity(0.12),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(90))
                    .frame(width: 58, height: 58)

                // Active Arc
                Circle()
                    .trim(from: 0.125, to: 0.125 + (normalizedFraction * 0.75))
                    .stroke(
                        tintColor,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(90))
                    .frame(width: 58, height: 58)
                    .shadow(color: tintColor.opacity(0.4), radius: 4)

                // Center Dial Face
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(white: 0.22), Color(white: 0.10)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 24
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )

                // Indicator Needle
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2.5, height: 10)
                    .offset(y: -14)
                    .rotationEffect(.degrees(angleDegrees))

                // Value Text inside knob
                Text(displayString)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(tintColor)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { gesture in
                        if dragOffset == 0 {
                            initialValue = value
                            dragOffset = gesture.location.y
                            feedback.prepare()
                        }
                        let deltaY = dragOffset - gesture.location.y
                        let sensitivity: CGFloat = 160.0 // Points of vertical drag to sweep full range
                        let deltaValue = Int((deltaY / sensitivity) * CGFloat(maxValue))
                        let target = max(0, min(maxValue, initialValue + deltaValue))

                        if target != value {
                            feedback.impactOccurred(intensity: 0.7)
                            onValueChanged(target)
                        }
                    }
                    .onEnded { _ in
                        dragOffset = 0
                    }
            )

            // Title Label below
            Text(title)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .tracking(0.5)
        }
        .frame(minWidth: 64)
    }
}
