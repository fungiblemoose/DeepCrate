import AppKit
import SwiftUI

enum LiquidMetrics {
    static let paneRadius: CGFloat = 30
    static let cardRadius: CGFloat = 22
    static let compactRadius: CGFloat = 16
}

enum LiquidPalette {
    static let base = Color(red: 0.12, green: 0.13, blue: 0.14)
    static let elevated = Color(red: 0.16, green: 0.17, blue: 0.19)
    static let warm = Color(red: 0.42, green: 0.26, blue: 0.12)
    static let cool = Color(red: 0.10, green: 0.29, blue: 0.27)
}

private struct LiquidSurfaceBackground: View {
    let cornerRadius: CGFloat
    let material: Material
    var baseOpacity: Double = 0.90
    var highlightOpacity: Double = 0.18

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        LiquidPalette.elevated.opacity(baseOpacity),
                        LiquidPalette.base.opacity(baseOpacity + 0.04)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(material)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                LiquidPalette.warm.opacity(highlightOpacity),
                                Color.clear,
                                LiquidPalette.cool.opacity(highlightOpacity * 0.9)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
    }
}

struct ToolbarStatusPillBackground: View {
    var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        LiquidPalette.elevated.opacity(0.97),
                        LiquidPalette.base.opacity(0.95)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Capsule()
                    .fill(.thinMaterial)
                    .opacity(0.46)
            }
            .overlay {
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.30), Color.white.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
    }
}

struct LiquidGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            configuration.label
                .font(.headline.weight(.semibold))
            configuration.content
        }
        .padding(14)
        .background(
            LiquidSurfaceBackground(
                cornerRadius: LiquidMetrics.cardRadius,
                material: .thinMaterial,
                baseOpacity: 0.92,
                highlightOpacity: 0.16
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: LiquidMetrics.cardRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.45), Color.white.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .allowsHitTesting(false)
        )
        .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 6)
    }
}

struct LiquidStatusBadge: View {
    let text: String
    let taskLabel: String
    let isWorking: Bool
    let progressCurrent: Int
    let progressTotal: Int
    let indeterminate: Bool
    let updatedAt: Date

    private var statusSymbol: String {
        if isWorking {
            return "arrow.triangle.2.circlepath"
        }
        return "checkmark.seal.fill"
    }

    private var statusTone: Color {
        isWorking ? .blue : .green
    }

    private var progressLabel: String {
        if isWorking {
            if indeterminate || progressTotal <= 0 {
                return "Working"
            }
            return "\(min(progressCurrent, progressTotal))/\(progressTotal)"
        }
        return "Ready"
    }

    private var timestampLabel: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: updatedAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                Image(systemName: statusSymbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(statusTone)
                    .symbolEffect(.pulse.byLayer, isActive: isWorking)

                VStack(alignment: .leading, spacing: 2) {
                    Text(taskLabel)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .allowsTightening(true)
                    Text(text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .allowsTightening(true)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(progressLabel)
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(timestampLabel)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if isWorking {
                if indeterminate || progressTotal <= 0 {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.blue)
                } else {
                    ProgressView(value: Double(progressCurrent), total: Double(max(progressTotal, 1)))
                        .controlSize(.small)
                        .tint(.blue)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minWidth: 220, idealWidth: 340)
        .background(ToolbarStatusPillBackground())
    }
}

struct VisualEffectGlass: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
    }
}

struct WindowAppearanceConfigurator: NSViewRepresentable {
    var minContentSize: CGSize = CGSize(width: 880, height: 620)

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            configureWindowIfAvailable(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configureWindowIfAvailable(from: nsView)
        }
    }

    private func configureWindowIfAvailable(from view: NSView) {
        guard let window = view.window else { return }
        window.isOpaque = false
        window.backgroundColor = NSColor(
            calibratedRed: 0.10,
            green: 0.11,
            blue: 0.12,
            alpha: 0.94
        )
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.contentMinSize = minContentSize
    }
}

extension View {
    func liquidPane(cornerRadius: CGFloat = LiquidMetrics.paneRadius) -> some View {
        self
            .padding(24)
            .background(
                LiquidSurfaceBackground(
                    cornerRadius: cornerRadius,
                    material: .regularMaterial,
                    baseOpacity: 0.93,
                    highlightOpacity: 0.20
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.55), Color.white.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            )
            .shadow(color: .black.opacity(0.10), radius: 24, x: 0, y: 12)
    }

    func liquidCard(
        cornerRadius: CGFloat = LiquidMetrics.cardRadius,
        material: Material = .ultraThinMaterial,
        contentPadding: CGFloat = 18,
        shadowOpacity: Double = 0.06
    ) -> some View {
        self
            .padding(contentPadding)
            .background(
                LiquidSurfaceBackground(
                    cornerRadius: cornerRadius,
                    material: material,
                    baseOpacity: 0.92,
                    highlightOpacity: 0.15
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.45), Color.white.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            )
            .shadow(color: .black.opacity(shadowOpacity), radius: 12, x: 0, y: 7)
    }
}
