import SwiftUI
import UIKit

public struct FootswitchView: View {
    public let slot: String
    public let isSelected: Bool
    public let onSelect: () -> Void

    private let haptic = UIImpactFeedbackGenerator(style: .medium)

    public init(slot: String, isSelected: Bool, onSelect: @escaping () -> Void) {
        self.slot = slot
        self.isSelected = isSelected
        self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: {
            haptic.impactOccurred()
            onSelect()
        }) {
            VStack(spacing: 8) {
                // LED Status Light
                Circle()
                    .fill(isSelected ? Color.cyan : Color.white.opacity(0.15))
                    .frame(width: 8, height: 8)
                    .shadow(color: isSelected ? Color.cyan : Color.clear, radius: isSelected ? 6 : 0)

                // Footswitch Button Graphic
                ZStack {
                    // Outer Ring
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.35), Color(white: 0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 58, height: 58)
                        .shadow(color: .black.opacity(0.6), radius: 4, y: 3)

                    // Inner Nut / Hexagon ring
                    Circle()
                        .stroke(Color(white: 0.5), lineWidth: 1.5)
                        .frame(width: 48, height: 48)

                    // Stomp Center Button
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    isSelected ? Color.cyan.opacity(0.3) : Color(white: 0.28),
                                    Color(white: 0.12)
                                ],
                                center: .center,
                                startRadius: 2,
                                endRadius: 20
                            )
                        )
                        .frame(width: 42, height: 42)

                    // Footswitch Letter
                    Text(slot)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(isSelected ? .white : Color.white.opacity(0.45))
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.cyan.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
