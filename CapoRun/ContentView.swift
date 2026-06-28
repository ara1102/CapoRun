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
    @State private var useGuitar: Bool = true
    
    var body: some View {
        ZStack {
            if appState == .menu {
                VStack(spacing: 30) {
                    Text("CapoRun")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Toggle(isOn: $useGuitar) {
                        Text(useGuitar ? "🎸 Guitar Mode: ON" : "👉 Manual Mode: ON")
                            .font(.headline)
                            .foregroundColor(useGuitar ? .green : .blue)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(15)
                    .frame(width: 280)
                    
                    Button(action: {
                        appState = .playing
                    }) {
                        Text("Start Game")
                            .font(.title2)
                            .bold()
                            .padding()
                            .frame(width: 220)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(15)
                    }
                }
            } else {
                GameView(initialUsingGuitar: useGuitar, onQuit: {
                    appState = .menu
                })
            }
        }
    }
}

#Preview {
    ContentView()
}
