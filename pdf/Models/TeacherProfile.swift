//
//  TeacherProfile.swift
//  pdf
//
//  Created on 13/11/2026.
//

import Foundation
import Observation

/// The look and name of the in-app teacher.
/// `avatarImageData` lets the student use a photo, including a screenshot of their own Memoji.
struct TeacherProfile: Codable, Equatable {
    var name: String = "Prof. Memo"
    var skinTone: Int = 1
    var hairStyle: Int = 0
    var hairColor: Int = 1
    var shirtColor: Int = 0
    var wearsGlasses: Bool = true
    var avatarImageData: Data?

    static let sample = TeacherProfile()
}

@Observable
final class TeacherStore {
    var profile: TeacherProfile {
        didSet { persist() }
    }

    private static let storageKey = "teacher.profile.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let storedProfile = try? JSONDecoder().decode(TeacherProfile.self, from: data) {
            profile = storedProfile
        } else {
            profile = .sample
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
