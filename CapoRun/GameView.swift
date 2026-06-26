import SwiftUI
import SpriteKit

struct GameView: View {
    // @StateObject private var audioDetector = AudioDetector()
    @StateObject private var audioDetector = ChromaAudioDetector()
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
    
    var body: some View {
        ZStack(alignment: .top) {
            SpriteView(scene: scene)
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    Text("Detected Chord: \(audioDetector.detectedChord)")
                        .font(.headline)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    Spacer()
                    Button(action: {
                        scene.resetGame()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title2)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                }
                .padding()
                
                Spacer()
                
                // Temporary buttons for testing without real guitar
                HStack(spacing: 20) {
                    Button("C") { scene.changeLane(to: "C") }
                    Button("D") { scene.changeLane(to: "D") }
                    Button("Am") { scene.changeLane(to: "Am") }
                    Button("G") { scene.changeLane(to: "G") }
                }
                .padding()
                .buttonStyle(.borderedProminent)
            }
        }
        .onAppear {
            audioDetector.startListening()
        }
        .onChange(of: audioDetector.detectedChord) { _, newChord in
            // When the audio detector detects a new chord, tell the game scene to move the player
            scene.changeLane(to: newChord)
        }
    }
}

#Preview {
    GameView()
}
