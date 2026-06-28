import Foundation
import AVFoundation
internal import Combine
import Accelerate

class ChromaAudioDetector: NSObject, ObservableObject {
    private let audioEngine = AVAudioEngine()
    
    @Published var detectedChord: String = "Listening..."
    @Published var triggeredDirection: Direction? = nil
    
    // Waveform visualization (downsampled)
    @Published var waveSamples: [Float] = Array(repeating: 0.0, count: 50)
    
    // Chromagram variables
    private let chromagramBins = 12
    private var fftSetup: vDSP_DFT_Setup? = nil
    
    // Templates based on 12 bins: [C, C#, D, D#, E, F, F#, G, G#, A, A#, B]
    private let chordTemplates: [String: (template: [Float], direction: Direction)] = [
        "C":  ([1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0], .left),   // C, E, G
        "G":  ([0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1], .up),     // D, G, B
        "Am": ([1, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0], .down),   // C, E, A
        "D":  ([0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0], .right),  // D, F#, A
        "A":  ([0, 1, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0], .left),   // C#, E, A (shares .left with C)
        "E":  ([0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1], .up),     // E, G#, B (shares .up with G)
        "Em": ([0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1], .down),   // E, G, B  (shares .down with Am)
        "Dm": ([0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0], .right),  // D, F, A  (shares .right with D)
        "F":  ([1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0], .left)    // C, F, A  (shares .left with C)
    ]
    
    override init() {
        super.init()
    }
    
    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }
    
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
        
        // Use a 4096 buffer size for better low-frequency resolution, or whatever the system provides
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] (buffer, time) in
            guard let self = self, let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = Int(buffer.frameLength)
            
            // Downsample for the UI waveform
            let strideSize = max(1, frameLength / 50)
            var temporarySamples: [Float] = []
            for i in stride(from: 0, to: frameLength, by: strideSize) {
                if temporarySamples.count < 50 {
                    temporarySamples.append(channelData[i] * 3.0)
                }
            }
            
            // Analyze on background thread
            DispatchQueue.global(qos: .userInteractive).async {
                self.processAudioBuffer(channelData: channelData, length: frameLength, sampleRate: recordingFormat.sampleRate)
                
                DispatchQueue.main.async {
                    self.waveSamples = temporarySamples
                }
            }
        }
        
        do {
            try audioEngine.start()
        } catch {
            print("Audio Engine failed to start: \(error.localizedDescription)")
        }
    }
    
    func stopListening() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            DispatchQueue.main.async {
                self.detectedChord = "Listening..."
                self.triggeredDirection = nil
            }
        }
    }
    
    private func processAudioBuffer(channelData: UnsafeMutablePointer<Float>, length: Int, sampleRate: Double) {
        // Calculate root mean square (RMS) volume to gate noise/silence
        var rms: Float = 0
        vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(length))
        
        // Noise gate: skip analysis if input is too quiet (threshold can be adjusted)
        let minVolumeThreshold: Float = 0.01
        if rms < minVolumeThreshold {
            DispatchQueue.main.async {
                self.detectedChord = "Listening..."
                self.triggeredDirection = nil
            }
            return
        }
        
        // Find the nearest power of 2 for FFT
        let log2n = vDSP_Length(log2(Float(length)))
        let n = Int(1 << log2n)
        
        // Setup DFT if not already created or if size changed
        if fftSetup == nil {
            fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(n), .FORWARD)
        }
        
        guard let setup = fftSetup else { return }
        
        // Apply Hann window to the input signal to reduce spectral leakage
        var window = [Float](repeating: 0, count: n)
        vDSP_hann_window(&window, vDSP_Length(n), Int32(vDSP_HANN_NORM))
        
        var windowedData = [Float](repeating: 0, count: n)
        vDSP_vmul(channelData, 1, &window, 1, &windowedData, 1, vDSP_Length(n))
        
        // Prepare complex split array for FFT
        var realIn = windowedData
        var imagIn = [Float](repeating: 0, count: n)
        var realOut = [Float](repeating: 0, count: n)
        var imagOut = [Float](repeating: 0, count: n)
        
        vDSP_DFT_Execute(setup, &realIn, &imagIn, &realOut, &imagOut)
        
        // Calculate magnitudes
        var magnitudes = [Float](repeating: 0, count: n/2)
        realOut.withUnsafeMutableBufferPointer { realOutPtr in
            imagOut.withUnsafeMutableBufferPointer { imagOutPtr in
                var splitComplex = DSPSplitComplex(realp: realOutPtr.baseAddress!, imagp: imagOutPtr.baseAddress!)
                vDSP_zvabs(&splitComplex, 1, &magnitudes, 1, vDSP_Length(n/2))
            }
        }
        
        // Calculate Chromagram
        let chromagram = computeChromagram(magnitudes: magnitudes, sampleRate: sampleRate, n: n)
        
        // Match against chord templates
        matchChord(chromagram: chromagram)
    }
    
    private func computeChromagram(magnitudes: [Float], sampleRate: Double, n: Int) -> [Float] {
        var chromagram = [Float](repeating: 0.0, count: chromagramBins)
        
        let freqPerBin = sampleRate / Double(n)
        
        // Start from bin 1 to ignore DC offset (0 Hz)
        for i in 1..<(n/2) {
            let frequency = Double(i) * freqPerBin
            
            // Only consider frequencies typical for guitar/music (e.g., 60 Hz to 2000 Hz)
            if frequency < 60.0 || frequency > 2000.0 { continue }
            
            let magnitude = magnitudes[i]
            if magnitude < 0.01 { continue } // Noise gate
            
            // MIDI Note formula: d = 69 + 12 * log2(f / 440)
            let pitch = 69.0 + 12.0 * log2(frequency / 440.0)
            
            // Round to nearest note
            let roundedPitch = Int(round(pitch))
            
            // Modulo 12 to get the pitch class (0 = C, 1 = C#, etc.)
            let pitchClass = (roundedPitch + 1200) % 12 // +1200 ensures positive modulo
            
            // Accumulate magnitude into the respective bin
            chromagram[pitchClass] += magnitude
        }
        
        // Normalize the chromagram (L2 norm)
        var sumSquares: Float = 0
        vDSP_svesq(chromagram, 1, &sumSquares, vDSP_Length(chromagramBins))
        let norm = sqrt(sumSquares)
        
        if norm > 0 {
            vDSP_vsdiv(chromagram, 1, [norm], &chromagram, 1, vDSP_Length(chromagramBins))
        }
        
        return chromagram
    }
    
    private func matchChord(chromagram: [Float]) {
        var bestMatch: String? = nil
        var highestSimilarity: Float = 0.0
        
        for (chordName, templateData) in chordTemplates {
            let template = templateData.template
            
            // Cosine similarity (since templates and chromagram are both non-negative vectors)
            var dotProduct: Float = 0
            vDSP_dotpr(chromagram, 1, template, 1, &dotProduct, vDSP_Length(chromagramBins))
            
            // Norm of template
            var templateSumSquares: Float = 0
            vDSP_svesq(template, 1, &templateSumSquares, vDSP_Length(chromagramBins))
            let templateNorm = sqrt(templateSumSquares)
            
            let similarity = (templateNorm > 0) ? (dotProduct / templateNorm) : 0
            
            if similarity > highestSimilarity {
                highestSimilarity = similarity
                bestMatch = chordName
            }
        }
        
        // Threshold check - if similarity is high enough, we consider it detected
        // Note: Threshold might need tuning based on real audio tests
        let confidenceThreshold: Float = 0.70 // Raised from 0.6 to reduce false positives
        
        DispatchQueue.main.async {
            if highestSimilarity > confidenceThreshold, let chord = bestMatch {
                self.detectedChord = chord
                self.triggeredDirection = self.chordTemplates[chord]?.direction
            } else {
                // If similarity is too low, reset to listening state
                self.detectedChord = "Listening..."
                self.triggeredDirection = nil
            }
        }
    }
}
