//
//  RecordingView.swift
//  Quran-Muaalem-Swift
//
//  Created by Tarek Mansour on 11/29/25.
//

import SwiftUI

struct RecordingView: View {
    
    @State private var selectedSura: Sura = QuranData.suras[0]
    @State private var selectedAya: Int = 1
    @State private var audioRecorder = AudioRecorder()
    
    @State private var isAnalyzing = false
    @State private var uploadProgress: Double = 0
    @State private var errorMessage: String?
    @State private var showError = false
    
    @State private var analysisResult: AnalyzeResponse?
    @State private var navigateToResults = false
    
    @State private var hasPermission = false
    @State private var showSettings = false
    
    // Settings from AppStorage
    @AppStorage("rewaya") private var rewaya = "hafs"
    @AppStorage("madd_monfasel_len") private var maddMonfaselLen = 2
    @AppStorage("madd_mottasel_len") private var maddMottaselLen = 4
    @AppStorage("madd_mottasel_waqf") private var maddMottaselWaqf = 4
    @AppStorage("madd_aared_len") private var maddAaredLen = 2
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Header
                headerSection
                
                Spacer()
                
                // Sura & Aya Pickers
                pickersSection
                
                Spacer()
                
                // Recording Button
                recordingButtonSection
                
                // Duration indicator
                if audioRecorder.isRecording {
                    durationLabel
                }
                
                Spacer()
            }
            .navigationTitle("المعلم القرآني")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .navigationDestination(isPresented: $navigateToResults) {
                if let result = analysisResult {
                    ResultsView(result: result)
                }
            }
            .alert("خطأ", isPresented: $showError) {
                Button("حسناً", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "حدث خطأ غير متوقع")
            }
            .task {
                hasPermission = await audioRecorder.requestPermission()
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(.green)
            
            Text("سجّل تلاوتك")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("اختر السورة والآية ثم اضغط للتسجيل")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Pickers Section
    
    private var pickersSection: some View {
        VStack(spacing: 24) {
            HStack(spacing: 20) {
                // Sura Picker
                VStack(alignment: .center, spacing: 8) {
                    Text("السورة")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    
                    Picker("السورة", selection: $selectedSura) {
                        ForEach(QuranData.suras) { sura in
                            Text(sura.displayName)
                                .font(.footnote)
                                .tag(sura)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onChange(of: selectedSura) {
                        // Reset aya when sura changes
                        selectedAya = 1
                    }
                }
                
                // Aya Picker
                VStack(alignment: .center, spacing: 8) {
                    Text("الآية")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    
                    Picker("الآية", selection: $selectedAya) {
                        ForEach(1...selectedSura.ayaCount, id: \.self) { ayaNum in
                            Text("\(ayaNum)")
                                .font(.footnote)
                                .tag(ayaNum)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
            
            // Selected Ayah Text Display
            if let ayaText = QuranData.getAyaText(sura: selectedSura.id, aya: selectedAya) {
                VStack(spacing: 8) {
                    Text("نص الآية")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(ayaText)
                        .font(.custom("KFGQPC Hafs Smart Regular", size: 24))
                        .minimumScaleFactor(0.01)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding()
                    
                        .background(Color.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green.opacity(0.2), lineWidth: 1)
                        )
                }
                .padding(.horizontal)
                .transition(.opacity)
                .animation(.easeInOut, value: selectedAya)
                .animation(.easeInOut, value: selectedSura)
            }
        }
    }
    
    // MARK: - Recording Button Section
    
    private var recordingButtonSection: some View {
        Button(action: handleRecordButtonTap) {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(buttonColor.opacity(0.3), lineWidth: 8)
                    .frame(width: 140, height: 140)
                
                // Progress ring (when analyzing)
                if isAnalyzing {
                    Circle()
                        .trim(from: 0, to: uploadProgress)
                        .stroke(buttonColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: uploadProgress)
                }
                
                // Inner button
                Circle()
                    .fill(buttonColor)
                    .frame(width: 110, height: 110)
                    .shadow(color: buttonColor.opacity(0.4), radius: 10, y: 5)
                
                // Icon
                if isAnalyzing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                } else {
                    Image(systemName: buttonIcon)
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
        }
        .disabled(isAnalyzing || !hasPermission)
        .scaleEffect(audioRecorder.isRecording ? 1.1 : 1.0)
        .animation(.spring(response: 0.3), value: audioRecorder.isRecording)
    }
    
    private var buttonColor: Color {
        if isAnalyzing {
            return .orange
        } else if audioRecorder.isRecording {
            return .red
        } else {
            return .green
        }
    }
    
    private var buttonIcon: String {
        audioRecorder.isRecording ? "stop.fill" : "mic.fill"
    }
    
    // MARK: - Duration Label
    
    private var durationLabel: some View {
        Text(formatDuration(audioRecorder.recordingDuration))
            .font(.system(.title3, design: .monospaced))
            .foregroundStyle(.red)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.1))
            .clipShape(Capsule())
    }
    
    // MARK: - Actions
    
    private func handleRecordButtonTap() {
        if audioRecorder.isRecording {
            stopRecordingAndAnalyze()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        print("🎤 [RecordingView] Starting recording...")
        audioRecorder.startRecording()
    }
    
    private func stopRecordingAndAnalyze() {
        print("⏹️ [RecordingView] Stopping recording...")
        audioRecorder.stopRecording()
        
        guard let audioURL = audioRecorder.recordingURL else {
            print("❌ [RecordingView] No recording URL found!")
            errorMessage = "فشل في حفظ التسجيل"
            showError = true
            return
        }
        
        print("📁 [RecordingView] Recording saved at: \(audioURL.path)")
        print("📊 [RecordingView] Recording duration: \(audioRecorder.recordingDuration) seconds")
        
        // Start analysis
        isAnalyzing = true
        uploadProgress = 0.1
        
        print("🔄 [RecordingView] Starting API call for sura \(selectedSura.id), aya \(selectedAya)")
        
        Task {
            do {
                print("⚙️ [RecordingView] Using settings - rewaya: \(rewaya), maddMonfasel: \(maddMonfaselLen), maddMottasel: \(maddMottaselLen)")
                
                let result = try await MuaalemAPI.shared.analyzeByVerse(
                    audioURL: audioURL,
                    sura: selectedSura.id,
                    aya: selectedAya,
                    rewaya: rewaya,
                    maddMonfaselLen: maddMonfaselLen,
                    maddMottaselLen: maddMottaselLen,
                    maddMottaselWaqf: maddMottaselWaqf,
                    maddAaredLen: maddAaredLen,
                    progressHandler: { progress in
                        Task { @MainActor in
                            print("📈 [RecordingView] Progress: \(Int(progress * 100))%")
                            uploadProgress = progress
                        }
                    }
                )
                
                print("✅ [RecordingView] API call successful!")
                
                await MainActor.run {
                    analysisResult = result
                    isAnalyzing = false
                    uploadProgress = 0
                    navigateToResults = true
                    
                    // Clean up recording
                    audioRecorder.deleteRecording()
                }
            } catch {
                print("❌ [RecordingView] API call failed: \(error.localizedDescription)")
                
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isAnalyzing = false
                    uploadProgress = 0
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let milliseconds = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, milliseconds)
    }
}

#Preview {
    RecordingView()
}

