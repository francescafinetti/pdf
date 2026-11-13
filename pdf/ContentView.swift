//
//  ContentView.swift
//  pdf
//
//  Created by Francesca Finetti on 13/11/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        LibraryView()
    }
}

#Preview {
    ContentView()
        .environment(TeacherStore())
}
