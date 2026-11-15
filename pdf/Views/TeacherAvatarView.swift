//
//  TeacherAvatarView.swift
//  pdf
//
//  Created on 13/11/2026.
//

import SwiftUI
import UIKit

enum TeacherPalette {
    static let skins: [Color] = [
        Color(red: 0.98, green: 0.84, blue: 0.72),
        Color(red: 0.93, green: 0.75, blue: 0.60),
        Color(red: 0.84, green: 0.62, blue: 0.45),
        Color(red: 0.66, green: 0.44, blue: 0.30),
        Color(red: 0.46, green: 0.29, blue: 0.20)
    ]

    static let hairs: [Color] = [
        Color(red: 0.12, green: 0.10, blue: 0.10),
        Color(red: 0.33, green: 0.21, blue: 0.12),
        Color(red: 0.78, green: 0.64, blue: 0.36),
        Color(red: 0.65, green: 0.28, blue: 0.15),
        Color(red: 0.62, green: 0.62, blue: 0.65),
        Color(red: 0.85, green: 0.45, blue: 0.55)
    ]

    static let shirts: [Color] = [
        Color(red: 0.30, green: 0.36, blue: 0.85),
        Color(red: 0.15, green: 0.62, blue: 0.58),
        Color(red: 0.95, green: 0.52, blue: 0.25),
        Color(red: 0.88, green: 0.35, blue: 0.52),
        Color(red: 0.35, green: 0.55, blue: 0.90),
        Color(red: 0.55, green: 0.40, blue: 0.82)
    ]

    static let hairstyleNames = ["Corti", "Lunghi", "Ricci", "Chignon"]
}

/// A customizable, memoji-inspired avatar.
/// If the student picked a photo (for example a screenshot of their Memoji),
/// that image is shown instead of the drawn character.
struct TeacherAvatarView: View {
    let profile: TeacherProfile
    var size: CGFloat = 96

    private var skin: Color { palette(TeacherPalette.skins, profile.skinTone) }
    private var hair: Color { palette(TeacherPalette.hairs, profile.hairColor) }
    private var shirt: Color { palette(TeacherPalette.shirts, profile.shirtColor) }

    var body: some View {
        ZStack {
            if let data = profile.avatarImageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                drawnAvatar
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.white.opacity(0.55), lineWidth: max(1, size * 0.02)))
        .shadow(color: .black.opacity(0.12), radius: size * 0.06, x: 0, y: size * 0.03)
        .accessibilityLabel("Teacher \(profile.name)")
    }

    // MARK: - Drawn character

    private var drawnAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.99, green: 0.88, blue: 0.72),
                            Color(red: 0.56, green: 0.79, blue: 0.91)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if profile.hairStyle == 1 {
                RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                    .fill(hair)
                    .frame(width: size * 0.52, height: size * 0.60)
                    .offset(y: size * 0.04)
            }

            // Shoulders and collar.
            Capsule()
                .fill(shirt)
                .frame(width: size * 0.80, height: size * 0.48)
                .offset(y: size * 0.47)
            Capsule()
                .fill(shirt.opacity(0.65))
                .frame(width: size * 0.20, height: size * 0.18)
                .offset(y: size * 0.31)

            // Neck.
            RoundedRectangle(cornerRadius: size * 0.05, style: .continuous)
                .fill(skin)
                .frame(width: size * 0.13, height: size * 0.14)
                .offset(y: size * 0.27)

            // Ears.
            Circle().fill(skin)
                .frame(width: size * 0.10, height: size * 0.10)
                .offset(x: -size * 0.235, y: size * 0.02)
            Circle().fill(skin)
                .frame(width: size * 0.10, height: size * 0.10)
                .offset(x: size * 0.235, y: size * 0.02)

            // Face.
            Ellipse()
                .fill(skin)
                .frame(width: size * 0.46, height: size * 0.55)
                .offset(y: -size * 0.02)

            hairView

            // Eyebrows.
            Capsule().fill(hair.opacity(0.85))
                .frame(width: size * 0.09, height: size * 0.018)
                .rotationEffect(.degrees(-8))
                .offset(x: -size * 0.10, y: -size * 0.125)
            Capsule().fill(hair.opacity(0.85))
                .frame(width: size * 0.09, height: size * 0.018)
                .rotationEffect(.degrees(8))
                .offset(x: size * 0.10, y: -size * 0.125)

            eye(offsetX: -size * 0.10)
            eye(offsetX: size * 0.10)

            // Nose.
            Capsule()
                .fill(skin.opacity(0.65))
                .frame(width: size * 0.035, height: size * 0.05)
                .offset(y: size * 0.02)

            // Blush.
            Circle().fill(Color.pink.opacity(0.22))
                .frame(width: size * 0.07, height: size * 0.07)
                .offset(x: -size * 0.15, y: size * 0.07)
            Circle().fill(Color.pink.opacity(0.22))
                .frame(width: size * 0.07, height: size * 0.07)
                .offset(x: size * 0.15, y: size * 0.07)

            // Smile.
            SmileShape()
                .stroke(
                    Color(red: 0.35, green: 0.16, blue: 0.14).opacity(0.8),
                    style: StrokeStyle(lineWidth: max(1, size * 0.017), lineCap: .round)
                )
                .frame(width: size * 0.14, height: size * 0.06)
                .offset(y: size * 0.10)

            if profile.wearsGlasses {
                glassesView
            }
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var hairView: some View {
        switch profile.hairStyle {
        case 1:
            HairCapShape()
                .fill(hair)
                .frame(width: size * 0.50, height: size * 0.30)
                .offset(y: -size * 0.17)
            Capsule().fill(hair)
                .frame(width: size * 0.09, height: size * 0.24)
                .offset(x: -size * 0.22, y: -size * 0.03)
            Capsule().fill(hair)
                .frame(width: size * 0.09, height: size * 0.24)
                .offset(x: size * 0.22, y: -size * 0.03)

        case 2:
            Circle().fill(hair)
                .frame(width: size * 0.14, height: size * 0.14)
                .offset(x: -size * 0.17, y: -size * 0.20)
            Circle().fill(hair)
                .frame(width: size * 0.16, height: size * 0.16)
                .offset(x: -size * 0.06, y: -size * 0.24)
            Circle().fill(hair)
                .frame(width: size * 0.16, height: size * 0.16)
                .offset(x: size * 0.06, y: -size * 0.24)
            Circle().fill(hair)
                .frame(width: size * 0.14, height: size * 0.14)
                .offset(x: size * 0.17, y: -size * 0.20)
            Circle().fill(hair)
                .frame(width: size * 0.10, height: size * 0.10)
                .offset(x: -size * 0.23, y: -size * 0.10)
            Circle().fill(hair)
                .frame(width: size * 0.10, height: size * 0.10)
                .offset(x: size * 0.23, y: -size * 0.10)

        case 3:
            HairCapShape()
                .fill(hair)
                .frame(width: size * 0.50, height: size * 0.30)
                .offset(y: -size * 0.17)
            Circle().fill(hair)
                .frame(width: size * 0.17, height: size * 0.17)
                .offset(x: size * 0.18, y: -size * 0.32)
            Capsule().fill(hair)
                .frame(width: size * 0.09, height: size * 0.18)
                .offset(x: -size * 0.22, y: -size * 0.08)

        default:
            HairCapShape()
                .fill(hair)
                .frame(width: size * 0.50, height: size * 0.28)
                .offset(y: -size * 0.18)
            Capsule().fill(hair)
                .frame(width: size * 0.08, height: size * 0.16)
                .offset(x: -size * 0.23, y: -size * 0.08)
            Capsule().fill(hair)
                .frame(width: size * 0.08, height: size * 0.16)
                .offset(x: size * 0.23, y: -size * 0.08)
        }
    }

    private func eye(offsetX: CGFloat) -> some View {
        ZStack {
            Ellipse()
                .fill(Color(red: 0.20, green: 0.13, blue: 0.10))
                .frame(width: size * 0.075, height: size * 0.09)
            Circle()
                .fill(.white)
                .frame(width: size * 0.026, height: size * 0.026)
                .offset(x: -size * 0.012, y: -size * 0.018)
        }
        .offset(x: offsetX, y: -size * 0.055)
    }

    private var glassesView: some View {
        HStack(spacing: size * 0.02) {
            RoundedRectangle(cornerRadius: size * 0.035, style: .continuous)
                .strokeBorder(Color.black.opacity(0.75), lineWidth: max(1, size * 0.018))
                .frame(width: size * 0.15, height: size * 0.12)
            RoundedRectangle(cornerRadius: size * 0.035, style: .continuous)
                .strokeBorder(Color.black.opacity(0.75), lineWidth: max(1, size * 0.018))
                .frame(width: size * 0.15, height: size * 0.12)
        }
        .offset(y: -size * 0.055)
    }

    private func palette(_ colors: [Color], _ index: Int) -> Color {
        colors[min(max(index, 0), colors.count - 1)]
    }
}

private struct HairCapShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.55)
        )
        path.closeSubpath()
        return path
    }
}

private struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        return path
    }
}

extension UIImage {
    /// Downscales and compresses a photo before storing it in the teacher profile.
    func teacherAvatarData(maxDimension: CGFloat = 512) -> Data? {
        let longestSide = max(size.width, size.height)
        guard longestSide > 0 else { return nil }

        let scale = min(1, maxDimension / longestSide)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.85)
    }
}
