//
//  pdfApp.swift
//  pdf
//
//  Created by Francesca Finetti on 13/11/2026.
//

import SwiftUI

@main
struct pdfApp: App {
    @State private var teacherStore = TeacherStore()
    @State private var reviewStore = ReviewStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(teacherStore)
                .environment(reviewStore)
                .tint(.indigo)
        }
    }
}
