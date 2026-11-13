//
//  TeacherSettingsView.swift
//  pdf
//
//  Created on 13/11/2026.
//

import PhotosUI
import SwiftUI

struct TeacherSettingsView: View {
    @Environment(TeacherStore.self) private var teacherStore
    @Environment(\.dismiss) private var dismiss

    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        @Bindable var store = teacherStore

        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        TeacherAvatarView(profile: store.profile, size: 124)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Nome") {
                    TextField("Come ti chiami?", text: $store.profile.name)
                }

                Section("Aspetto") {
                    colorRow("Carnagione", colors: TeacherPalette.skins, selection: $store.profile.skinTone)
                    colorRow("Capelli", colors: TeacherPalette.hairs, selection: $store.profile.hairColor)
                    Picker("Taglio", selection: $store.profile.hairStyle) {
                        ForEach(TeacherPalette.hairstyleNames.indices, id: \.self) { index in
                            Text(TeacherPalette.hairstyleNames[index]).tag(index)
                        }
                    }
                    colorRow("Maglia", colors: TeacherPalette.shirts, selection: $store.profile.shirtColor)
                    Toggle("Occhiali", isOn: $store.profile.wearsGlasses)
                }

                Section("La tua Memoji") {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Usa una foto o la tua Memoji", systemImage: "photo")
                    }

                    if store.profile.avatarImageData != nil {
                        Button("Rimuovi foto", role: .destructive) {
                            store.profile.avatarImageData = nil
                        }
                    }

                    Text("Suggerimento: salva la tua Memoji come immagine e sceglila qui per dare al Teacher le tue sembianze.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Il tuo Teacher")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fine") { dismiss() }
                }
            }
            .onChange(of: photoItem) { _, newItem in
                loadPhoto(from: newItem)
            }
        }
    }

    private func colorRow(_ title: String, colors: [Color], selection: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                    Button {
                        selection.wrappedValue = index
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Circle().strokeBorder(
                                    Color.primary.opacity(selection.wrappedValue == index ? 0.9 : 0.15),
                                    lineWidth: selection.wrappedValue == index ? 2.5 : 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title) \(index + 1)")
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item else { return }

        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let compressed = image.teacherAvatarData() else { return }
            teacherStore.profile.avatarImageData = compressed
        }
    }
}
