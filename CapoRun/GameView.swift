import SwiftUI
import SpriteKit

struct GameView: View {
    @StateObject private var audioDetector = ChromaAudioDetector()
    @State private var isUsingGuitar: Bool = true
    @State private var isPaused: Bool = false
    @State private var showInputSelection: Bool = true
    
    var onQuit: () -> Void = {}
    
    @State private var scene: GameScene = {
        let screenSize: CGSize
        if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            screenSize = windowScene.screen.bounds.size
        } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            screenSize = windowScene.screen.bounds.size
        } else {
            screenSize = CGSize(width: 393, height: 852) // Default iPhone 15 size fallback
        }
        let scene = GameScene(size: screenSize)
        scene.scaleMode = .resizeFill
        return scene
    }()
    
    private func color(for chord: String) -> Color {
        switch chord {
        case "C": return Color(red: 255/255, green: 65/255, blue: 77/255)       // Red/Coral (#FF414D)
        case "D": return Color(red: 255/255, green: 174/255, blue: 25/255)      // Orange/Gold (#FFAE19)
        case "Am": return Color(red: 155/255, green: 48/255, blue: 255/255)     // Purple/Violet (#9B30FF)
        case "G": return Color(red: 38/255, green: 196/255, blue: 185/255)      // Teal/Cyan (#26C4B9)
        default: return .purple
        }
    }
    
    private func textColor(for chord: String) -> Color {
        switch chord {
        case "C", "Am": return .white
        case "D", "G": return .black
        default: return .white
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            SpriteView(scene: scene)
                .ignoresSafeArea()
            
            VStack {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: $isUsingGuitar) {
                            Image(systemName: "guitars")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                        .padding(8)
                        .padding(.horizontal, 4)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(20)
                        .fixedSize()
                        .onChange(of: isUsingGuitar) { _, newValue in
                            if newValue {
                                audioDetector.startListening()
                            } else {
                                audioDetector.stopListening()
                            }
                        }
                        
                        if isUsingGuitar {
                            Text("Chord: \(audioDetector.detectedChord)")
                                .font(.headline)
                                .padding(8)
                                .background(Color.black.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        isPaused = true
                        scene.isPaused = true
                    }) {
                        Image(systemName: "pause.fill")
                            .font(.title2)
                            .padding(14)
                            .background(Color.black.opacity(0.8))
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
                
                Spacer()
                
                // Manual Buttons
                VStack(spacing: 12) {
                    
                    HStack(spacing: 40) {
                        ForEach(["C", "D", "Am", "G"], id: \.self) { chord in
                            Button(action: {
                                if !isUsingGuitar {
                                    scene.changeLane(to: chord)
                                }
                            }) {
                                Text(chord)
                                    .font(.headline)
                                    .bold()
                                    .frame(width: 40, height: 32)
                                    .foregroundColor(isUsingGuitar ? color(for: chord) : textColor(for: chord))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(isUsingGuitar ? Color.black.opacity(0.8) : color(for: chord))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(color(for: chord), lineWidth: isUsingGuitar ? 2 : 0)
                            )
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
            
            if showInputSelection {
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Text("Select Input Mode")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.bottom, 20)
                    
                    Button(action: {
                        isUsingGuitar = true
                        showInputSelection = false
                        scene.isPaused = false
                        scene.startGame()
                        audioDetector.startListening()
                    }) {
                        Text("🎸 Guitar Mode")
                            .font(.title2).bold()
                            .padding()
                            .frame(width: 250)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(15)
                    }
                    
                    Button(action: {
                        isUsingGuitar = false
                        showInputSelection = false
                        scene.isPaused = false
                        scene.startGame()
                    }) {
                        Text("👉 Manual Mode")
                            .font(.title2).bold()
                            .padding()
                            .frame(width: 250)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(15)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isPaused {
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("PAUSED")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.bottom, 20)
                    
                    Button(action: {
                        isPaused = false
                        scene.isPaused = false
                    }) {
                        Text("Resume")
                            .font(.title2).bold()
                            .padding()
                            .frame(width: 200)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        isPaused = false
                        scene.resetGame()
                    }) {
                        Text("Retry")
                            .font(.title2).bold()
                            .padding()
                            .frame(width: 200)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        isPaused = false
                        audioDetector.stopListening()
                        onQuit()
                    }) {
                        Text("Main Menu")
                            .font(.title2).bold()
                            .padding()
                            .frame(width: 200)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            scene.isPaused = true
            scene.onGameEnd = {
                audioDetector.stopListening()
                onQuit()
            }
        }
        .onChange(of: audioDetector.detectedChord) { _, newChord in
            if isUsingGuitar {
                scene.changeLane(to: newChord)
            }
        }
    }
}

#Preview {
    GameView()
}
