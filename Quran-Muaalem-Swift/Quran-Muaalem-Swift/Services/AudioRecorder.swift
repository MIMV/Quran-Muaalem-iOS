//
//  AudioRecorder.swift
//  Quran-Muaalem-Swift
//
//  Created by Tarek Mansour on 11/29/25.
//

import AVFoundation
import Foundation

@Observable
final class AudioRecorder: NSObject {
    
    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession?
    
    var isRecording = false
    var recordingURL: URL?
    var recordingDuration: TimeInterval = 0
    var errorMessage: String?
    
    private var timer: Timer?
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession?.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession?.setActive(true)
        } catch {
            errorMessage = "Failed to setup audio session: \(error.localizedDescription)"
        }
    }
    
    func startRecording() {
        print("🎙️ [AudioRecorder] Starting recording...")
        
        // Create a unique filename for each recording
        let filename = "recording_\(Date().timeIntervalSince1970).wav"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        recordingURL = documentsPath.appendingPathComponent(filename)
        
        guard let url = recordingURL else {
            print("❌ [AudioRecorder] Failed to create recording URL")
            errorMessage = "Failed to create recording URL"
            return
        }
        
        print("📁 [AudioRecorder] Recording to: \(url.path)")
        
        // Recording settings - 16kHz mono WAV (required by Muaalem API)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            isRecording = true
            recordingDuration = 0
            errorMessage = nil
            
            print("✅ [AudioRecorder] Recording started successfully")
            
            // Start timer to track duration
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.recordingDuration = self?.audioRecorder?.currentTime ?? 0
            }
        } catch {
            print("❌ [AudioRecorder] Failed to start recording: \(error.localizedDescription)")
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
        }
    }
    
    func stopRecording() {
        print("⏹️ [AudioRecorder] Stopping recording...")
        timer?.invalidate()
        timer = nil
        audioRecorder?.stop()
        isRecording = false
        
        // Check file size
        if let url = recordingURL,
           let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let fileSize = attrs[.size] as? Int {
            print("✅ [AudioRecorder] Recording stopped. File size: \(fileSize) bytes (\(fileSize / 1024) KB)")
        } else {
            print("⚠️ [AudioRecorder] Recording stopped but couldn't get file size")
        }
    }
    
    func deleteRecording() {
        guard let url = recordingURL else { return }
        try? FileManager.default.removeItem(at: url)
        recordingURL = nil
        recordingDuration = 0
    }
    
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            errorMessage = "Recording failed"
            recordingURL = nil
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        errorMessage = error?.localizedDescription ?? "Encoding error"
    }
}

