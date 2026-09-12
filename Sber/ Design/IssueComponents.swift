import SwiftUI

extension Color {
    static let priorityCritical = Color(red: 197 / 255, green: 32 / 255, blue: 42 / 255)
    static let priorityHigh = Color(red: 226 / 255, green: 112 / 255, blue: 34 / 255)
    static let priorityMedium = Color(red: 42 / 255, green: 118 / 255, blue: 189 / 255)
    static let priorityLow = Color(red: 108 / 255, green: 122 / 255, blue: 137 / 255)
    static let missingRed = Color(red: 197 / 255, green: 32 / 255, blue: 42 / 255)
}

extension IssuePriority {
    var color: Color {
        switch self {
        case .critical: return .priorityCritical
        case .high: return .priorityHigh
        case .medium: return .priorityMedium
        case .low: return .priorityLow
        }
    }
}

extension IssueStatus {
    var color: Color {
        switch self {
        case .new: return .priorityMedium
        case .awaitingInfo: return .priorityHigh
        case .inProgress: return .pantone349
        case .resolved: return Color(red: 30 / 255, green: 140 / 255, blue: 95 / 255)
        case .closed: return .priorityLow
        }
    }
}

/// Small filled capsule used for category, priority and status.
struct IssueBadge: View {
    let text: String
    let color: Color
    var iconName: String?
    var filled: Bool = true

    var body: some View {
        HStack(spacing: 4) {
            if let iconName {
                Image(systemName: iconName).font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(filled ? .white : color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(filled ? color : color.opacity(0.12))
        .clipShape(Capsule())
    }
}

/// Selectable filter chip for the operator's feed.
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .pantone349 : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? Color.white : Color.white.opacity(0.18))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Visible whenever canned data is served, so nobody mistakes the demo mode for
/// a working backend.
struct MockBanner: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "wifi.slash").font(.system(size: 11, weight: .bold))
            Text("Демо-режим: данные локальные, бэкенд не используется")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(Color.priorityHigh)
    }
}

/// Error strip with a one-tap escape hatch into demo mode.
struct ErrorStrip: View {
    let message: String
    var onRetry: (() -> Void)?
    var onUseMock: (() -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                if let onRetry {
                    Button("Повторить", action: onRetry)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }
                if let onUseMock {
                    Button("Включить демо-режим", action: onUseMock)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .underline()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.85))
        .cornerRadius(12)
    }
}
