//
//  ContentView.swift
//  CapoRun
//
//  Created by Adhira on 26/06/26.
//

import SwiftUI

enum AppState {
    case menu
    case playing
}

struct ContentView: View {
    @State private var appState: AppState = .menu
    
    var body: some View {
        ZStack {
            if appState == .menu {
                MainMenu(onPlay: {
                    appState = .playing
                })
            } else {
                GameView(onQuit: {
                    appState = .menu
                })
            }
        }
    }
}

#Preview {
    ContentView()
}
