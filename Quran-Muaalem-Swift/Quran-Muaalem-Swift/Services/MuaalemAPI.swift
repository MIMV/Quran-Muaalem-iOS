//
//  MuaalemAPI.swift
//  Quran-Muaalem-Swift
//
//  Created by Tarek Mansour on 11/29/25.
//

import Foundation

enum MuaalemAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(String)
    case networkError(Error)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let message):
            return message
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}

actor MuaalemAPI {
    
    static let shared = MuaalemAPI()
    
    // Configure your Modal API endpoint URL here
    // Option 1: Replace the URL below with your own Modal deployment URL
    // Option 2: Set MUAALEM_API_URL environment variable (for testing)
    private let baseURL: String = {
        // Check for custom URL in environment variable (useful for testing)
        if let customURL = ProcessInfo.processInfo.environment["MUAALEM_API_URL"], !customURL.isEmpty {
            return customURL
        }
        // Default URL - REPLACE THIS with your own Modal deployment URL
        // Format: https://YOUR-USERNAME--quran-muaalem-api-muaalemapi-serve.modal.run
        return "https://YOUR-USERNAME--quran-muaalem-api-muaalemapi-serve.modal.run"
    }()
    
    private init() {}
    
    // MARK: - Analyze by Verse
    
    func analyzeByVerse(
        audioURL: URL,
        sura: Int,
        aya: Int,
        rewaya: String = "hafs",
        maddMonfaselLen: Int = 2,
        maddMottaselLen: Int = 4,
        maddMottaselWaqf: Int = 4,
        maddAaredLen: Int = 2,
        progressHandler: (@Sendable (Double) -> Void)? = nil
    ) async throws -> AnalyzeResponse {
        
        print("🚀 [MuaalemAPI] Starting analyzeByVerse for sura: \(sura), aya: \(aya)")
        
        guard let url = URL(string: "\(baseURL)/api/analyze-by-verse") else {
            print("❌ [MuaalemAPI] Invalid URL")
            throw MuaalemAPIError.invalidURL
        }
        
        print("📁 [MuaalemAPI] Reading audio from: \(audioURL.path)")
        
        // Read audio data
        let audioData = try Data(contentsOf: audioURL)
        print("📊 [MuaalemAPI] Audio data size: \(audioData.count) bytes (\(audioData.count / 1024) KB)")
        
        // Create multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120 // 2 minutes timeout for cold starts
        
        var body = Data()
        
        // Add audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"recording.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add form fields
        body.appendFormField(name: "sura", value: "\(sura)", boundary: boundary)
        body.appendFormField(name: "aya", value: "\(aya)", boundary: boundary)
        body.appendFormField(name: "rewaya", value: rewaya, boundary: boundary)
        body.appendFormField(name: "madd_monfasel_len", value: "\(maddMonfaselLen)", boundary: boundary)
        body.appendFormField(name: "madd_mottasel_len", value: "\(maddMottaselLen)", boundary: boundary)
        body.appendFormField(name: "madd_mottasel_waqf", value: "\(maddMottaselWaqf)", boundary: boundary)
        body.appendFormField(name: "madd_aared_len", value: "\(maddAaredLen)", boundary: boundary)
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("📤 [MuaalemAPI] Sending request to: \(url)")
        print("📦 [MuaalemAPI] Request body size: \(body.count) bytes")
        print("⏳ [MuaalemAPI] Waiting for response (may take 30-90 sec on cold start)...")
        
        let startTime = Date()
        
        // Perform request with progress tracking
        let (data, response) = try await performRequest(request, progressHandler: progressHandler)
        
        let elapsed = Date().timeIntervalSince(startTime)
        print("⏱️ [MuaalemAPI] Response received in \(String(format: "%.2f", elapsed)) seconds")
        
        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [MuaalemAPI] Invalid response type")
            throw MuaalemAPIError.invalidResponse
        }
        
        print("📥 [MuaalemAPI] HTTP Status: \(httpResponse.statusCode)")
        print("📥 [MuaalemAPI] Response size: \(data.count) bytes")
        
        if httpResponse.statusCode != 200 {
            // Try to decode error message
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ [MuaalemAPI] Error response: \(errorString)")
            }
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw MuaalemAPIError.serverError(apiError.detail)
            }
            throw MuaalemAPIError.serverError("Server returned status code \(httpResponse.statusCode)")
        }
        
        // Decode response
        do {
            print("🔄 [MuaalemAPI] Decoding response...")
            
            // Print full JSON response
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📄 [MuaalemAPI] ========== FULL JSON RESPONSE ==========")
                print(jsonString)
                print("📄 [MuaalemAPI] ========== END JSON RESPONSE ==========")
            }
            
            let decoder = JSONDecoder()
            let result = try decoder.decode(AnalyzeResponse.self, from: data)
            print("✅ [MuaalemAPI] Successfully decoded response!")
            print("✅ [MuaalemAPI] Phonemes (actual): \(result.phonemesText)")
            print("✅ [MuaalemAPI] Phonemes (expected): \(result.reference.phoneticScript.phonemesText)")
            print("✅ [MuaalemAPI] Sifat count: \(result.sifat.count)")
            print("✅ [MuaalemAPI] Expected sifat count: \(result.expectedSifat?.count ?? 0)")
            print("✅ [MuaalemAPI] Phoneme diff count: \(result.phonemeDiff?.count ?? 0)")
            print("✅ [MuaalemAPI] Sifat errors count: \(result.sifatErrors?.count ?? 0)")
            return result
        } catch {
            print("❌ [MuaalemAPI] Decoding error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📄 [MuaalemAPI] Raw JSON: \(jsonString)")
            }
            throw MuaalemAPIError.decodingError(error)
        }
    }
    
    // MARK: - Health Check
    
    func healthCheck() async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/health") else {
            throw MuaalemAPIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return false
        }
        
        struct HealthResponse: Codable {
            let status: String
        }
        
        let healthResponse = try JSONDecoder().decode(HealthResponse.self, from: data)
        return healthResponse.status == "healthy"
    }
    
    // MARK: - Private Helpers
    
    private func performRequest(
        _ request: URLRequest,
        progressHandler: (@Sendable (Double) -> Void)?
    ) async throws -> (Data, URLResponse) {
        
        // For simplicity, using URLSession.shared.data
        // In a production app, you might want to use URLSessionDelegate for upload progress
        print("🌐 [MuaalemAPI] Starting network request...")
        progressHandler?(0.3) // Indicate upload started
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            print("🌐 [MuaalemAPI] Network request completed")
            progressHandler?(1.0) // Complete
            return (data, response)
        } catch {
            print("❌ [MuaalemAPI] Network error: \(error.localizedDescription)")
            throw MuaalemAPIError.networkError(error)
        }
    }
}

// MARK: - Data Extension for Multipart Form

private extension Data {
    mutating func appendFormField(name: String, value: String, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }
}

