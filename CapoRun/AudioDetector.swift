//
//  AudioDetector.swift
//  CapoRun
//
//  Created by Maya Maria Nainggolan on 26/06/26.
//

import Foundation
import AVFoundation
internal import Combine

enum Direction {
    case up
    case down
    case left
    case right
}

class AudioDetector: NSObject, ObservableObject {
    private let audioEngine = AVAudioEngine()
    
    @Published var detectedChord: String = "Listening..."
    @Published var triggeredDirection: Direction? = nil
    
    // 🌟 New: Holds the latest raw audio samples for the waveform line
    @Published var waveSamples: [Float] = Array(repeating: 0.0, count: 50)
    
    func startListening() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: .defaultToSpeaker)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio Session error: \(error.localizedDescription)")
            return
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, time) in
            guard let self = self, let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = Int(buffer.frameLength)
            
            // 🌟 New: Downsample the audio buffer to 50 points so we can draw it smoothly
            let strideSize = frameLength / 50
            var temporarySamples: [Float] = []
            for i in stride(from: 0, to: frameLength, by: strideSize) {
                if temporarySamples.count < 50 {
                    // Multiply by 3.0 to boost the visual scale of the wave slightly
                    temporarySamples.append(channelData[i] * 3.0)
                }
            }
            
            // Analyze pitch on a background thread
            DispatchQueue.global(qos: .userInteractive).async {
                let frequency = self.detectPitchFrequency(channelData: channelData, length: frameLength, sampleRate: recordingFormat.sampleRate)
                
                DispatchQueue.main.async {
                    // Update the waveform on the main thread
                    self.waveSamples = temporarySamples
                    
                    if frequency > 0 {
                        self.mapFrequencyToChord(frequency)
                    }
                }
            }
        }
        
        do {
            try audioEngine.start()
        } catch {
            print("Audio Engine failed to start: \(error.localizedDescription)")
        }
    }
    
    private func detectPitchFrequency(channelData: UnsafeMutablePointer<Float>, length: Int, sampleRate: Double) -> Float {
        var maxCorrelation: Float = 0
        var maxLag = 0
        
        let minLag = Int(sampleRate / 350.0)
        let maxLagLimit = Int(sampleRate / 80.0)
        
        for lag in minLag..<maxLagLimit {
            var correlation: Float = 0
            for i in 0..<(length - lag) {
                correlation += channelData[i] * channelData[i + lag]
            }
            if correlation > maxCorrelation {
                maxCorrelation = correlation
                maxLag = lag
            }
        }
        
        if maxLag > 0 {
            return Float(sampleRate) / Float(maxLag)
        }
        return 0.0
    }
    
    private func mapFrequencyToChord(_ frequency: Float) {
        switch frequency {
        case 185...210:
            self.detectedChord = "G"
            self.triggeredDirection = .up
        case 105...120:
            self.detectedChord = "Am"
            self.triggeredDirection = .down
        case 125...138:
            self.detectedChord = "C"
            self.triggeredDirection = .left
        case 140...155:
            self.detectedChord = "D"
            self.triggeredDirection = .right
        default:
            break
        }
    }
}
