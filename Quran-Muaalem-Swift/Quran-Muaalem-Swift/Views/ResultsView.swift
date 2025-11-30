//
//  ResultsView.swift
//  Quran-Muaalem-Swift
//
//  Created by Tarek Mansour on 11/29/25.
//

import SwiftUI

struct ResultsView: View {
    
    // MARK: - Static Properties
    
    static let diacriticRegex = try? NSRegularExpression(
        pattern: "[\\u064b-\\u065f\\u0610-\\u061a\\u06d6-\\u06ed\\u08d4-\\u08e1\\u08e3-\\u08ff]",
        options: .caseInsensitive
    )
    
    private static let maddChars: Set<Character> = ["ا", "و", "ي", "ۥ", "ۦ", "آ", "ٱ", "ى"]
    private static let harakatChars: Set<Character> = ["َ", "ُ", "ِ", "ْ", "ً", "ٌ", "ٍ"]
    
    let result: AnalyzeResponse
    
    @State private var showAdvanced = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Reference Verse Card
                referenceCard
                
                // Only show detailed analysis if NOT a completely wrong verse
                if !isVeryDifferent() {
                    // Score Summary
                    scoreSummary
                    
                    // Errors Table (using API comparison if available)
                    errorsTableCard
                    
                    // Advanced Button
                    advancedButton
                    
                    // Advanced Details (if shown)
                    if showAdvanced {
                        advancedSection
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("نتائج التحليل")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Reference Card
    
    private var referenceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("الآية المرجعية", systemImage: "book.fill")
                .font(.headline)
                .foregroundStyle(.green)
            
            if let sura = result.reference.sura, let aya = result.reference.aya {
                Text("سورة \(QuranData.sura(byId: sura)?.arabicName ?? "") - آية \(aya)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Text(result.reference.uthmaniText)
                .font(.custom("KFGQPC Hafs Smart Regular", size: 24))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
    
    // MARK: - Score Summary
    
    private var scoreSummary: some View {
        let errors = getErrors()
        // Use server-provided word breakdown if available, otherwise split text
        let words = result.phonemesByWord?.map { $0.word } ?? result.reference.uthmaniText.components(separatedBy: " ")
        let totalWords = words.count
        
        // Find how many UNIQUE word indices have errors
        // If wordIndex is available, use it. If not, use the word string (fallback)
        let errorWordIndices: Set<Int> = Set(errors.compactMap { $0.wordIndex })
        let errorWordStrings: Set<String> = Set(errors.filter { $0.wordIndex == nil }.map { $0.word })
        
        // Total wrong words = words identified by index + words identified by string (that weren't covered by index)
        // This is an approximation if we have mixed error types, but with our recent fixes most should have wordIndex
        let wrongWordsCount = errorWordIndices.count + errorWordStrings.count
        
        // Ensure we don't count more wrong words than total (safety cap)
        let finalWrongCount = min(wrongWordsCount, totalWords)
        let correctWordsCount = max(0, totalWords - finalWrongCount)
        
        let score = totalWords > 0 ? Double(correctWordsCount) / Double(totalWords) * 100 : 100
        
        return VStack(spacing: 16) {
            HStack(spacing: 20) {
                // Score Circle
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                        .frame(width: 100, height: 100)
                    
                    Circle()
                        .trim(from: 0, to: score / 100)
                        .stroke(scoreColor(score), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                    
                    
                    VStack(spacing: 2) {
                        Text("\(Int(score))%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(scoreColor(score))
                        Text("الدرجة")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                
                Spacer()
                
                // Stats
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("كلمات صحيحة: \(correctWordsCount)")
                    }
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text("كلمات خاطئة: \(finalWrongCount)")
                    }
                    HStack {
                        Image(systemName: "text.word.spacing")
                            .foregroundStyle(.blue)
                        Text("مجموع الكلمات: \(totalWords)")
                    }
                }
                .font(.subheadline)
                .padding()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
    
    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 90...: return .green
        case 70..<90: return .orange
        default: return .red
        }
    }
    
    // MARK: - Errors Table Card
    
    private var errorsTableCard: some View {
        let errors = getErrors()
        let groupedErrors = groupErrorsByWord(errors)
        let totalErrorCount = errors.count
        
        return VStack(alignment: .leading, spacing: 16) {
            Label(errors.isEmpty ? "لا توجد أخطاء 🎉" : "الأخطاء المكتشفة (\(totalErrorCount))", systemImage: errors.isEmpty ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(errors.isEmpty ? .green : .orange)
            
            if errors.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.green)
                    Text("أحسنت! تلاوتك صحيحة")
                        .font(.title3)
                        .fontWeight(.medium)
                    Text("استمر في الممارسة")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                // Grouped Error Cards by Word
                ForEach(groupedErrors) { group in
                    WordErrorCardView(group: group, uthmaniText: result.reference.uthmaniText)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
    
    /// Group errors by word and sort by word position in the verse
    private func groupErrorsByWord(_ errors: [TajweedError]) -> [WordErrorGroup] {
        let words = result.reference.uthmaniText.components(separatedBy: " ")
        
        print("📊 [DEBUG] ========== GROUPING ERRORS ==========")
        print("📊 [DEBUG] Total errors: \(errors.count)")
        print("📊 [DEBUG] Words in verse: \(words)")
        
        // Group errors by word index (primary) or word string (fallback)
        // Key: wordIndex (if available) -> WordErrorGroup
        // If no index, we'll try to deduce it or group separately
        var indexToErrors: [Int: [TajweedError]] = [:]
        var unknownWordErrors: [String: [TajweedError]] = [:]
        
        for error in errors {
            if let index = error.wordIndex {
                if indexToErrors[index] == nil {
                    indexToErrors[index] = []
                }
                indexToErrors[index]?.append(error)
            } else {
                // Fallback: Group by word string
                let word = error.word
                if unknownWordErrors[word] == nil {
                    unknownWordErrors[word] = []
                }
                unknownWordErrors[word]?.append(error)
            }
        }
        
        var groups: [WordErrorGroup] = []
        
        // Process indexed groups
        for (index, groupErrors) in indexToErrors {
            let word = index < words.count ? words[index] : (groupErrors.first?.word ?? "")
            groups.append(WordErrorGroup(word: word, errors: groupErrors, positionInVerse: index))
        }
        
        // Process unknown groups (try to assign to first occurrence)
        for (word, groupErrors) in unknownWordErrors {
            // Find first occurrence not already taken? Or just assign to first occurrence
            let position = words.firstIndex(of: word) ?? words.count
            // If we already have a group for this position from indexed errors, merge them
            if let existingIndex = groups.firstIndex(where: { $0.positionInVerse == position }) {
                var mergedErrors = groups[existingIndex].errors
                mergedErrors.append(contentsOf: groupErrors)
                groups[existingIndex] = WordErrorGroup(word: word, errors: mergedErrors, positionInVerse: position)
            } else {
                groups.append(WordErrorGroup(word: word, errors: groupErrors, positionInVerse: position))
            }
        }
        
        // Sort by position in verse
        let sortedGroups = groups.sorted { $0.positionInVerse < $1.positionInVerse }
        
        print("📊 [DEBUG] ========== GROUPED RESULTS ==========")
        for group in sortedGroups {
            print("📊 [DEBUG] Word: '\(group.word)' (position: \(group.positionInVerse)) - \(group.errors.count) errors")
        }
        print("📊 [DEBUG] ========== END GROUPING ==========")
        
        return sortedGroups
    }
    
    // MARK: - Advanced Button
    
    private var advancedButton: some View {
        Button(action: { withAnimation { showAdvanced.toggle() } }) {
            HStack {
                Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                Text(showAdvanced ? "إخفاء التفاصيل المتقدمة" : "عرض التفاصيل المتقدمة")
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.blue)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Advanced Section
    
    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Phoneme Comparison Card (for advanced users)
            phonemeDiffCard
            
            // Sifat Analysis
            sifatSection
        }
    }
    
    // MARK: - Phoneme Diff Card (NEW)
    
    private var phonemeDiffCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("مقارنة النطق", systemImage: "arrow.left.arrow.right")
                .font(.headline)
                .foregroundStyle(.purple)
            
            // Expected (what they should say)
            VStack(alignment: .center, spacing: 8) {
                HStack {
                    Text("المتوقع")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                
                Text(result.reference.phoneticScript.phonemesText)
                    .font(.custom("KFGQPC Hafs Smart Regular", size: 20))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Diff visualization with legend
            if let diffs = result.phonemeDiff {
                VStack(alignment: .leading, spacing: 8) {
                    Text("تفاصيل المقارنة")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    // Legend
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Circle().fill(.green).frame(width: 8, height: 8)
                            Text("زيادة")
                                .font(.caption)
                        }
                        HStack(spacing: 4) {
                            Circle().fill(.red).frame(width: 8, height: 8)
                            Text("نقص")
                                .font(.caption)
                        }
                    }
                    .foregroundStyle(.secondary)
                    
                    phonemeDiffText(diffs)
                        .font(.custom("KFGQPC Hafs Smart Regular", size: 18))
                        .foregroundStyle(Color.gray)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                        .background(Color.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            
            // Warning if texts are very different
            if isVeryDifferent() {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("يبدو أنك قرأت آية مختلفة عن المحددة")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
    
    /// Format phonemes text - replace [PAD] with "غير واضح"
    private func formatPhonemesText(_ text: String) -> String {
        text.replacingOccurrences(of: "[PAD]", with: "⟨غير واضح⟩")
    }
    
    /// Check if the reading is very different from expected (wrong verse)
    private func isVeryDifferent() -> Bool {
        let expected = result.reference.phoneticScript.phonemesText
        let actual = result.phonemesText
        
        // If lengths differ significantly (more than 50%), probably wrong verse
        let lengthRatio = Double(min(expected.count, actual.count)) / Double(max(expected.count, actual.count))
        if lengthRatio < 0.4 {
            return true
        }
        
        // Use phoneme diff if available (most accurate)
        if let diffs = result.phonemeDiff {
            let equalChars = diffs.filter { $0.type == "equal" }.reduce(0) { $0 + $1.text.count }
            let totalExpected = expected.count
            
            // If less than 40% of expected text matches, it's a different verse
            if totalExpected > 0 && Double(equalChars) / Double(totalExpected) < 0.4 {
                return true
            }
            
            // If more than 40% of the diff is errors, it's a different verse
            let errorChars = diffs.filter { $0.type != "equal" }.reduce(0) { $0 + $1.text.count }
            let totalChars = diffs.reduce(0) { $0 + $1.text.count }
            
            if totalChars > 0 && Double(errorChars) / Double(totalChars) > 0.4 {
                return true
            }
            
            // If we have diff data and it's not too different, trust it
            return false
        }
        
        // Fallback: Simple character overlap check (less accurate)
        let expectedSet = Set(expected)
        let actualSet = Set(actual)
        let commonChars = expectedSet.intersection(actualSet)
        let similarity = Double(commonChars.count) / Double(max(expectedSet.count, actualSet.count))
        
        // If less than 40% similar unique characters, probably wrong verse
        if similarity < 0.4 {
            return true
        }
        
        return false
    }
    
    private func phonemeDiffText(_ diffs: [PhonemeDiffItem]) -> Text {
        var result = Text("")
        
        for diff in diffs {
            let displayText = formatPhonemesText(diff.text)
            switch diff.type {
            case "equal":
                result = result + Text(displayText)
            case "insert":
                result = result + Text(displayText).foregroundColor(.green).bold()
            case "delete":
                result = result + Text(displayText).foregroundColor(.red).strikethrough()
            default:
                result = result + Text(displayText)
            }
        }
        
        return result
    }
    
    // MARK: - Sifat Section
    
    private var sifatSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("نسبة التحقّق من صحة النطق", systemImage: "text.magnifyingglass")
                .font(.headline)
                .foregroundStyle(.purple)
            
            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle().fill(.green).frame(width: 8, height: 8)
                    Text("متأكد")
                        .font(.caption)
                }
                HStack(spacing: 4) {
                    Circle().fill(.orange).frame(width: 8, height: 8)
                    Text("متشكك")
                        .font(.caption)
                }
                HStack(spacing: 4) {
                    Circle().fill(.red).frame(width: 8, height: 8)
                    Text("غير متأكد")
                        .font(.caption)
                }
            }
            .foregroundStyle(.secondary)
            
            ForEach(result.sifat) { sifa in
                SifaItemView(sifa: sifa)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
    
    // MARK: - Helpers
    
    private func confidenceColor(_ confidence: Double) -> Color {
        switch confidence {
        case 0.9...: return .green
        case 0.7..<0.9: return .orange
        default: return .red
        }
    }
    
    // MARK: - Error Detection
    
    /// Get errors - uses API comparison when available, falls back to confidence-based
    private func getErrors() -> [TajweedError] {
        var errors: [TajweedError] = []
        
        // 1. Add sifat errors from API (phonetic attribute errors)
        // These are REAL errors from comparing expected vs actual
        if let apiErrors = result.sifatErrors {
            let words = result.reference.uthmaniText.components(separatedBy: " ")
            
            print("🔍 [DEBUG] ========== PROCESSING SIFAT ERRORS ==========")
            print("🔍 [DEBUG] API returned \(apiErrors.count) sifat errors")
            
            let sifatErrors = apiErrors.flatMap { error -> [TajweedError] in
                // Use EXPECTED phoneme to find the word (not the detected phoneme)
                // Because the expected phoneme is what should be in the word
                let (word, wordIndex) = findWordForPhonemeByIndex(
                    expectedPhoneme: error.expectedPhoneme,
                    index: error.index,
                    words: words,
                    expectedSifat: result.expectedSifat
                )
                
                print("🔍 [DEBUG] SifatError index=\(error.index) phoneme='\(error.phoneme)' expectedPhoneme='\(error.expectedPhoneme)' → word='\(word)'")
                
                return error.errors.map { attrError in
                    return TajweedError(
                        phoneme: error.expectedPhoneme, // Show expected phoneme for highlighting
                        word: word,
                        wordIndex: wordIndex,
                        rule: attrError.attributeAr,
                        expected: arabicSifaName(attrError.expected),
                        actual: arabicSifaName(attrError.actual),
                        confidence: attrError.prob
                    )
                }
            }
            errors.append(contentsOf: sifatErrors)
            print("🔍 [DEBUG] ========== END SIFAT ERRORS ==========")
        }
        
        // 2. Add madd errors from phoneme_diff (elongation length errors)
        errors.append(contentsOf: detectMaddErrors())
        
        // 3. ONLY use fallback if API didn't provide comparison data
        // If sifatErrors exists (even if empty), the API compared and found no errors - trust it!
        // The fallback confidence-based detection can produce false positives
        if result.sifatErrors == nil && result.expectedSifat == nil && errors.isEmpty {
            errors = findErrors()
        }
        
        return errors
    }
    
    /// Detect phoneme errors from phoneme_diff (letters, harakat, madd)
    private func detectMaddErrors() -> [TajweedError] {
        guard let diffs = result.phonemeDiff else { return [] }
        
        var errors: [TajweedError] = []
        let words = result.reference.uthmaniText.components(separatedBy: " ")
        
        // Build the expected phonemes string to find letters before harakat
        let expectedPhonemes = result.reference.phoneticScript.phonemesText
        
        // Track position in expected phonemes to find the word
        var expectedPosition = 0
        
        // Collect insertions and deletions with their positions
        var deletions: [(text: String, position: Int)] = []
        var insertions: [(text: String, position: Int)] = []
        
        for diff in diffs {
            // IMPORTANT: Use unicodeScalars.count to match Python's diff_match_patch
            // which works on code points, not graphemes
            if diff.type == "equal" {
                expectedPosition += diff.text.unicodeScalars.count
            } else if diff.type == "delete" {
                deletions.append((diff.text, expectedPosition))
                expectedPosition += diff.text.unicodeScalars.count
            } else if diff.type == "insert" {
                insertions.append((diff.text, expectedPosition))
            }
        }
        
        // Find the letter before a position (for harakat errors)
        func findLetterAtPosition(_ position: Int) -> String {
            guard position > 0 else { return "" }
            let index = expectedPhonemes.index(expectedPhonemes.startIndex, offsetBy: max(0, position - 1), limitedBy: expectedPhonemes.endIndex)
            if let idx = index {
                let char = expectedPhonemes[idx]
                // Skip if it's a haraka, get the one before
                if Self.harakatChars.contains(char) && position > 1 {
                    let prevIndex = expectedPhonemes.index(idx, offsetBy: -1, limitedBy: expectedPhonemes.startIndex)
                    if let prevIdx = prevIndex {
                        return String(expectedPhonemes[prevIdx])
                    }
                }
                return String(char)
            }
            return ""
        }
        
        // Find word at a given position in the expected phonemes
        func findWordAtPosition(_ position: Int) -> (String, Int?) {
            // First, find which sifa index this character position belongs to
            guard let expectedSifat = result.expectedSifat else { return (words.first ?? "—", 0) }
            
            var charCount = 0
            var sifaIndex = 0
            
            // Find the sifa index that COVERS this position
            for (idx, sifa) in expectedSifat.enumerated() {
                let sifaLen = sifa.phonemes.unicodeScalars.count
                // If position is WITHIN this sifa's range
                if position >= charCount && position < charCount + sifaLen {
                    sifaIndex = idx
                    break
                }
                charCount += sifaLen
                
                // If we reached the end and still haven't found (shouldn't happen if pos is valid), clamp to last
                if idx == expectedSifat.count - 1 {
                    sifaIndex = idx
                }
            }
            
            // BEST: Use server-provided phonemes_by_word mapping
            if let phonemesByWord = result.phonemesByWord {
                if let wordInfo = phonemesByWord.first(where: { $0.containsIndex(sifaIndex) }) {
                    print("🔎 [POS] ✅ Server mapping: position \(position) → sifat \(sifaIndex) → word '\(wordInfo.word)' (idx: \(wordInfo.wordIndex))")
                    return (wordInfo.word, wordInfo.wordIndex)
                }
            }
            
            // FALLBACK: Use client-side mapping
            let mapping = self.buildIndexToWordMapping(expectedSifat: expectedSifat, words: words)
            if let wordIndex = mapping[sifaIndex], wordIndex < words.count {
                return (words[wordIndex], wordIndex)
            }
            
            return (words.last ?? "—", words.indices.last)
        }
        
        // Pair deletions with insertions (substitution errors)
        let pairCount = min(deletions.count, insertions.count)
        for i in 0..<pairCount {
            let expected = deletions[i].text
            let actual = insertions[i].text
            let position = deletions[i].position
            let (word, wordIndex) = findWordAtPosition(position)
            
            // Determine error type
            let expectedHaraka = expected.filter { Self.harakatChars.contains($0) }
            let actualHaraka = actual.filter { Self.harakatChars.contains($0) }
            let expectedMadd = expected.filter { Self.maddChars.contains($0) }
            let actualMadd = actual.filter { Self.maddChars.contains($0) }
            
            if !expectedHaraka.isEmpty || !actualHaraka.isEmpty {
                // Harakat error - find the letter that has the wrong haraka
                let letter = findLetterAtPosition(position)
                let phonemeToHighlight = letter.isEmpty ? (actual.isEmpty ? expected : actual) : letter
                
                errors.append(TajweedError(
                    phoneme: phonemeToHighlight,
                    word: word,
                    wordIndex: wordIndex,
                    rule: "الحركات",
                    expected: harakaName(expectedHaraka.isEmpty ? "—" : expectedHaraka),
                    actual: harakaName(actualHaraka.isEmpty ? "—" : actualHaraka),
                    confidence: 1.0
                ))
            } else if !expectedMadd.isEmpty || !actualMadd.isEmpty {
                // Madd error
                errors.append(TajweedError(
                    phoneme: actual.isEmpty ? expected : actual,
                    word: word,
                    wordIndex: wordIndex,
                    rule: "المد",
                    expected: expectedMadd.isEmpty ? "بدون مد" : "مد (\(expectedMadd.count) حرف)",
                    actual: actualMadd.isEmpty ? "بدون مد" : "مد (\(actualMadd.count) حرف)",
                    confidence: 1.0
                ))
            } else {
                // Letter substitution error
                errors.append(TajweedError(
                    phoneme: actual,
                    word: word,
                    wordIndex: wordIndex,
                    rule: "الحروف",
                    expected: expected,
                    actual: actual,
                    confidence: 1.0
                ))
            }
        }
        
        // Handle remaining deletions (missing sounds)
        for i in pairCount..<deletions.count {
            let expected = deletions[i].text
            let position = deletions[i].position
            // Use position directly, or position + 1 if needed?
            // Deletion position is where the text WAS.
            let (word, wordIndex) = findWordAtPosition(position)
            let maddCount = expected.filter { Self.maddChars.contains($0) }.count
            let harakaCount = expected.filter { Self.harakatChars.contains($0) }.count
            
            if maddCount > 0 {
                errors.append(TajweedError(
                    phoneme: expected,
                    word: word,
                    wordIndex: wordIndex,
                    rule: "المد",
                    expected: "مد (\(maddCount) حرف)",
                    actual: "بدون مد",
                    confidence: 1.0
                ))
            } else if harakaCount > 0 {
                // Use position directly for missing haraka
                let letter = findLetterAtPosition(position)
                errors.append(TajweedError(
                    phoneme: letter.isEmpty ? expected : letter,
                    word: word,
                    wordIndex: wordIndex,
                    rule: "الحركات",
                    expected: harakaName(expected),
                    actual: "ناقص",
                    confidence: 1.0
                ))
            } else {
                errors.append(TajweedError(
                    phoneme: expected,
                    word: word,
                    wordIndex: wordIndex,
                    rule: "الحروف",
                    expected: expected,
                    actual: "ناقص",
                    confidence: 1.0
                ))
            }
        }
        
        // Handle remaining insertions (extra sounds)
        for i in pairCount..<insertions.count {
            let actual = insertions[i].text
            let position = insertions[i].position
            // Insertion happens AT this position.
            let (word, wordIndex) = findWordAtPosition(position)
            let maddCount = actual.filter { Self.maddChars.contains($0) }.count
            let harakaCount = actual.filter { Self.harakatChars.contains($0) }.count
            
            if maddCount > 0 {
                errors.append(TajweedError(
                    phoneme: actual,
                    word: word,
                    wordIndex: wordIndex,
                    rule: "المد",
                    expected: "بدون مد زائد",
                    actual: "مد زائد (\(maddCount) حرف)",
                    confidence: 1.0
                ))
            } else if harakaCount > 0 {
                let letter = findLetterAtPosition(position)
                errors.append(TajweedError(
                    phoneme: letter.isEmpty ? actual : letter,
                    word: word,
                    wordIndex: wordIndex,
                    rule: "الحركات",
                    expected: "بدون",
                    actual: harakaName(actual),
                    confidence: 1.0
                ))
            } else {
                errors.append(TajweedError(
                    phoneme: actual,
                    word: word,
                    wordIndex: wordIndex,
                    rule: "الحروف",
                    expected: "بدون",
                    actual: actual,
                    confidence: 1.0
                ))
            }
        }
        
        return errors
    }
    
    /// Convert haraka character to Arabic name
    private func harakaName(_ haraka: String) -> String {
        if haraka.contains("َ") { return "فتحة" }
        if haraka.contains("ُ") { return "ضمة" }
        if haraka.contains("ِ") { return "كسرة" }
        if haraka.contains("ْ") { return "سكون" }
        if haraka.contains("ً") { return "تنوين فتح" }
        if haraka.contains("ٌ") { return "تنوين ضم" }
        if haraka.contains("ٍ") { return "تنوين كسر" }
        return haraka
    }
    
    private func findErrors() -> [TajweedError] {
        var errors: [TajweedError] = []
        let words = result.reference.uthmaniText.components(separatedBy: " ")
        
        for (index, sifa) in result.sifat.enumerated() {
            // Find the word containing this phoneme
            let word = findWordForPhoneme(sifa.phonemesGroup, at: index, in: words)
            
            // Check Ghunnah
            if let ghonna = sifa.ghonna, ghonna.prob < 0.85 {
                let expected = ghonna.text == "maghnoon" ? "بدون غنة" : "مع غنة"
                let actual = ghonna.text == "maghnoon" ? "مع غنة" : "بدون غنة"
                errors.append(TajweedError(
                    phoneme: sifa.phonemesGroup,
                    word: word,
                    rule: "الغنة",
                    expected: expected,
                    actual: actual,
                    confidence: ghonna.prob
                ))
            }
            
            // Check Tafkheem/Tarqeeq
            if let tafkheem = sifa.tafkheemOrTaqeeq, tafkheem.prob < 0.85 {
                let expected = tafkheem.text == "mofakham" ? "مرقق" : "مفخم"
                let actual = tafkheem.text == "mofakham" ? "مفخم" : "مرقق"
                errors.append(TajweedError(
                    phoneme: sifa.phonemesGroup,
                    word: word,
                    rule: "التفخيم/الترقيق",
                    expected: expected,
                    actual: actual,
                    confidence: tafkheem.prob
                ))
            }
            
            // Check Qalqalah
            if let qalqla = sifa.qalqla, qalqla.prob < 0.85 {
                let expected = qalqla.text == "moqalqal" ? "بدون قلقلة" : "مع قلقلة"
                let actual = qalqla.text == "moqalqal" ? "مع قلقلة" : "بدون قلقلة"
                errors.append(TajweedError(
                    phoneme: sifa.phonemesGroup,
                    word: word,
                    rule: "القلقلة",
                    expected: expected,
                    actual: actual,
                    confidence: qalqla.prob
                ))
            }
            
            // Check Shidda/Rakhawa
            if let shidda = sifa.shiddaOrRakhawa, shidda.prob < 0.85 {
                errors.append(TajweedError(
                    phoneme: sifa.phonemesGroup,
                    word: word,
                    rule: "الشدة/الرخاوة",
                    expected: arabicSifaName(shidda.text),
                    actual: "غير واضح",
                    confidence: shidda.prob
                ))
            }
            
            // Check Hams/Jahr
            if let hams = sifa.hamsOrJahr, hams.prob < 0.85 {
                let expected = hams.text == "hams" ? "جهر" : "همس"
                let actual = hams.text == "hams" ? "همس" : "جهر"
                errors.append(TajweedError(
                    phoneme: sifa.phonemesGroup,
                    word: word,
                    rule: "الهمس/الجهر",
                    expected: expected,
                    actual: actual,
                    confidence: hams.prob
                ))
            }
            
            // Check Madd (elongation) - look for repeated alif/waw/ya patterns
            let maddChars: Set<Character> = ["ا", "و", "ي", "ۥ", "ۦ", "آ"]
            let phoneme = sifa.phonemesGroup
            
            // Count consecutive madd characters
            let maddCount = phoneme.filter { maddChars.contains($0) }.count
            
            if maddCount >= 2 {
                // This is a madd - check the phoneme probabilities for this segment
                // Get average probability for this phoneme group from the main phonemes
                let avgProb = getAverageProb(for: index)
                
                if avgProb < 0.85 {
                    let expectedLength = getMaddExpectedLength(phoneme: phoneme)
                    let actualLength = maddCount
                    
                    if actualLength != expectedLength {
                        errors.append(TajweedError(
                            phoneme: sifa.phonemesGroup,
                            word: word,
                            rule: "المد",
                            expected: "\(expectedLength) حركات",
                            actual: "\(actualLength) حركات",
                            confidence: avgProb
                        ))
                    }
                }
            }
        }
        
        return errors
    }
    
    // Get average probability for phonemes at a given index
    private func getAverageProb(for sifaIndex: Int) -> Double {
        // Map sifa index to approximate phoneme indices
        let totalSifat = result.sifat.count
        let totalProbs = result.phonemes.probs.count
        
        guard totalSifat > 0, totalProbs > 0 else { return 1.0 }
        
        let startIdx = sifaIndex * totalProbs / totalSifat
        let endIdx = min((sifaIndex + 1) * totalProbs / totalSifat, totalProbs)
        
        guard startIdx < endIdx else { return 1.0 }
        
        let probs = Array(result.phonemes.probs[startIdx..<endIdx])
        return probs.reduce(0, +) / Double(probs.count)
    }
    
    // Determine expected madd length based on context
    private func getMaddExpectedLength(phoneme: String) -> Int {
        // Default expected lengths (these should match the settings)
        // In a full implementation, we'd pass the settings here
        
        // Check for madd mottasel indicators (همزة after madd in same word)
        if phoneme.contains("ء") || phoneme.contains("أ") || phoneme.contains("إ") || phoneme.contains("آ") {
            return 4 // madd mottasel default
        }
        
        // Default to madd monfasel/aared
        return 2
    }
    
    // Find the word that likely contains this phoneme
    private func findWordForPhoneme(_ phoneme: String, at index: Int, in words: [String]) -> String {
        // Get the base letter (first character without diacritics)
        let baseChar = phoneme.first.map { String($0) } ?? phoneme
        
        // Try to find a word containing this character
        for word in words {
            // Check if word contains the base character
            if word.contains(baseChar) {
                return word
            }
        }
        
        // Fallback: estimate based on position
        // Roughly estimate which word based on index proportion
        if !words.isEmpty {
            let totalPhonemes = result.sifat.count
            let wordIndex = min(index * words.count / max(totalPhonemes, 1), words.count - 1)
            return words[wordIndex]
        }
        
        return phoneme
    }
    
    /// Find word for a phoneme using the expected sifat index
    /// Build a mapping from sifat index to word based on sequential matching
    private func findWordForPhonemeByIndex(
        expectedPhoneme: String,
        index: Int,
        words: [String],
        expectedSifat: [ExpectedSifaItem]?
    ) -> (String, Int?) {
        print("🔎 [FIND] Looking for word: expectedPhoneme='\(expectedPhoneme)' index=\(index)")
        
        // BEST: Use server-provided phonemes_by_word (if available)
        // This is the most reliable - server tells us exactly which indices belong to which word!
        if let phonemesByWord = result.phonemesByWord {
            if let wordInfo = phonemesByWord.first(where: { $0.containsIndex(index) }) {
                print("🔎 [FIND] ✅ Server mapping: index \(index) → word '\(wordInfo.word)' (range: \(wordInfo.sifatStart)-\(wordInfo.sifatEnd))")
                return (wordInfo.word, wordInfo.wordIndex)
            }
            print("🔎 [FIND] ⚠️ Index \(index) not in server's phonemes_by_word")
        }
        
        // FALLBACK: Use client-side mapping
        guard let expectedSifat = expectedSifat, !words.isEmpty else {
            print("🔎 [FIND] No expectedSifat, using basic fallback")
            return (findWordForPhoneme(expectedPhoneme, at: index, in: words), nil)
        }
        
        // Build index-to-word mapping by walking through sifat and words together
        let indexToWord = buildIndexToWordMapping(expectedSifat: expectedSifat, words: words)
        
        if let wordIdx = indexToWord[index], wordIdx < words.count {
            print("🔎 [FIND] Client mapping: index \(index) → word \(wordIdx): '\(words[wordIdx])'")
            return (words[wordIdx], wordIdx)
        }
        
        // Fallback: use the last word if index is beyond mapping
        print("🔎 [FIND] Index \(index) not in mapping, using last word")
        return (words.last ?? expectedPhoneme, words.indices.last)
    }
    
    /// Build a mapping from expected_sifat index to word index
    /// Walk through sifat in order and match each phoneme to the current word
    /// Move to next word when phoneme doesn't match current word but matches next
    private func buildIndexToWordMapping(expectedSifat: [ExpectedSifaItem], words: [String]) -> [Int: Int] {
        var mapping: [Int: Int] = [:]
        var wordIndex = 0
        
        // BEST: Use simple Emlaey words from hafs_smart_v8.json if available
        // These are plain Arabic like ["ذلك", "الكتاب"] instead of complex Uthmani
        let normalizedWords: [String]
        if let sura = result.reference.sura,
           let aya = result.reference.aya,
           let emlaeyWords = QuranData.getEmlaeyWords(sura: sura, aya: aya),
           emlaeyWords.count == words.count {
            normalizedWords = emlaeyWords
            print("🗺️ [MAP] Using Emlaey words from JSON (simple text)")
        } else {
            // FALLBACK: Normalize the Uthmani words ourselves
            normalizedWords = words.map { normalizeForMatching($0) }
            print("🗺️ [MAP] Using normalized Uthmani words (fallback)")
        }
        
        // Track remaining characters for each word
        var remainingInWord: [String] = normalizedWords
        
        print("🗺️ [MAP] Building index→word mapping: \(expectedSifat.count) sifat, \(words.count) words")
        print("🗺️ [MAP] Original words: \(words)")
        print("🗺️ [MAP] Matching words: \(normalizedWords)")
        
        for sifa in expectedSifat {
            let sifaIndex = sifa.index
            // Normalize phoneme: strip diacritics AND convert madd symbols to base letters
            let normalizedPhoneme = normalizeForMatching(sifa.phonemes)
            
            // Check if this phoneme matches current word
            if wordIndex < remainingInWord.count {
                let currentRemaining = remainingInWord[wordIndex]
                
                // Try to match phoneme in current word's remaining characters
                if let matchedChar = findFirstMatchingChar(phoneme: normalizedPhoneme, in: currentRemaining) {
                    mapping[sifaIndex] = wordIndex
                    // Remove only the first matched character from remaining
                    if let range = currentRemaining.range(of: matchedChar) {
                        remainingInWord[wordIndex] = String(currentRemaining[range.upperBound...])
                    }
                    print("🗺️ [MAP] Index \(sifaIndex) '\(sifa.phonemes)'→'\(normalizedPhoneme)' → word \(wordIndex) '\(words[wordIndex])' (matched '\(matchedChar)', remaining: '\(remainingInWord[wordIndex])')")
                }
                // If phoneme not in current word, check if we should move to next word
                else if wordIndex + 1 < remainingInWord.count {
                    let nextRemaining = remainingInWord[wordIndex + 1]
                    
                    // Move to next word if:
                    // 1. Current word is empty (consumed)
                    // 2. Phoneme matches next word
                    let shouldMove = currentRemaining.isEmpty ||
                    findFirstMatchingChar(phoneme: normalizedPhoneme, in: nextRemaining) != nil
                    
                    if shouldMove {
                        wordIndex += 1
                        mapping[sifaIndex] = wordIndex
                        if let matchedChar = findFirstMatchingChar(phoneme: normalizedPhoneme, in: remainingInWord[wordIndex]) {
                            if let range = remainingInWord[wordIndex].range(of: matchedChar) {
                                remainingInWord[wordIndex] = String(remainingInWord[wordIndex][range.upperBound...])
                            }
                        }
                        print("🗺️ [MAP] Index \(sifaIndex) '\(sifa.phonemes)'→'\(normalizedPhoneme)' → word \(wordIndex) '\(words[wordIndex])' (moved to next word)")
                    } else {
                        // Stay on current word (madd extension or special case)
                        mapping[sifaIndex] = wordIndex
                        print("🗺️ [MAP] Index \(sifaIndex) '\(sifa.phonemes)'→'\(normalizedPhoneme)' → word \(wordIndex) '\(words[wordIndex])' (staying, no match)")
                    }
                } else {
                    // Assign to last word
                    mapping[sifaIndex] = wordIndex
                    print("🗺️ [MAP] Index \(sifaIndex) '\(sifa.phonemes)'→'\(normalizedPhoneme)' → word \(wordIndex) '\(words[wordIndex])' (at end)")
                }
            } else {
                // Beyond words, assign to last word
                mapping[sifaIndex] = words.count - 1
            }
        }
        
        return mapping
    }
    
    /// Normalize Arabic text for matching: strip diacritics AND convert special chars to base letters
    private func normalizeForMatching(_ text: String) -> String {
        // First strip diacritics
        var result = stripDiacriticsForSearch(text)
        
        // Convert phonetic symbols to their base Arabic letters
        // IMPORTANT: Use Unicode scalars because ٰ (U+0670) is a combining character
        // that forms grapheme clusters like "ذٰ" - iterating by Character won't find it!
        let normalizationMap: [Unicode.Scalar: Unicode.Scalar] = [
            "\u{06E6}": "\u{064A}",  // ۦ Small yaa madd → ي yaa
            "\u{06E5}": "\u{0648}",  // ۥ Small waw madd → و waw
            "\u{0670}": "\u{0627}",  // ٰ Dagger alif → ا alif
            "\u{0671}": "\u{0627}",  // ٱ Alif wasla → ا alif
            "\u{0649}": "\u{064A}",  // ى Alif maqsura → ي yaa
            "\u{0629}": "\u{0647}",  // ة Ta marbuta → ه ha
        ]
        
        // Characters to remove entirely
        let removeScalars: Set<Unicode.Scalar> = [
            "\u{0640}",  // ـ Tatweel
        ]
        
        // Process using Unicode scalars to handle combining characters
        var normalized = ""
        for scalar in result.unicodeScalars {
            if removeScalars.contains(scalar) {
                continue  // Skip tatweel
            } else if let mapped = normalizationMap[scalar] {
                normalized.append(Character(mapped))
            } else {
                normalized.append(Character(scalar))
            }
        }
        result = normalized
        
        // Remove consecutive duplicates (e.g., "اا" → "ا", "لل" → "ل")
        // This helps match phonetic madd (اا) to single alif in word
        var deduplicated = ""
        var lastChar: Character? = nil
        for char in result {
            if char != lastChar {
                deduplicated.append(char)
                lastChar = char
            }
        }
        
        return deduplicated
    }
    
    /// Find the first character from phoneme that exists in the word
    private func findFirstMatchingChar(phoneme: String, in word: String) -> String? {
        guard !phoneme.isEmpty, !word.isEmpty else { return nil }
        
        // Try each character of the phoneme
        for char in phoneme {
            if word.contains(char) {
                return String(char)
            }
        }
        return nil
    }
    
    /// Strip Arabic diacritics for search purposes using regex
    private func stripDiacriticsForSearch(_ text: String) -> String {
        return Self.diacriticRegex?.stringByReplacingMatches(
            in: text,
            options: [],
            range: NSMakeRange(0, text.unicodeScalars.count),
            withTemplate: ""
        ) ?? text
    }
    
    /// Check if word contains an Arabic variant of the character
    private func containsArabicVariant(word: String, of char: String) -> Bool {
        let mappings: [String: [String]] = [
            "ء": ["أ", "إ", "آ", "ؤ", "ئ", "ٱ"],
            "ا": ["آ", "أ", "إ", "ٰ", "ى", "ـٰ"],
            "ه": ["ة", "ھ", "ہ"],
            "ي": ["ى", "ۦ", "ئ"],
            "و": ["ۥ", "ؤ"],
            "ت": ["ة"],
            "د": ["ڈ"],
            "ر": ["ڑ"],
        ]
        
        var charsToCheck = [char]
        if let variants = mappings[char] {
            charsToCheck.append(contentsOf: variants)
        }
        
        for c in charsToCheck {
            if word.contains(c) {
                return true
            }
        }
        return false
    }
    
    private func arabicSifaName(_ english: String) -> String {
        // Handle [PAD] token
        if english == "[PAD]" {
            return "غير واضح"
        }
        
        let translations: [String: String] = [
            "hams": "همس",
            "jahr": "جهر",
            "shadeed": "شديد",
            "between": "بين بين",
            "rikhw": "رخاوة",
            "mofakham": "مفخم",
            "moraqaq": "مرقق",
            "low_mofakham": "تفخيم خفيف",
            "monfateh": "منفتح",
            "motbaq": "مطبق",
            "safeer": "صفير",
            "no_safeer": "بدون صفير",
            "moqalqal": "مقلقل",
            "not_moqalqal": "بدون قلقلة",
            "mokarar": "مكرر",
            "not_mokarar": "بدون تكرار",
            "motafashie": "متفشي",
            "not_motafashie": "بدون تفشي",
            "mostateel": "مستطيل",
            "not_mostateel": "بدون استطالة",
            "maghnoon": "مغنون",
            "not_maghnoon": "بدون غنة",
        ]
        return translations[english] ?? english
    }
}

// MARK: - Tajweed Error Model

struct TajweedError: Identifiable {
    let id = UUID()
    let phoneme: String
    let word: String
    let wordIndex: Int? // Added to handle repeated words
    let rule: String
    let expected: String
    let actual: String
    let confidence: Double
    
    // Backward compatibility init
    init(phoneme: String, word: String, wordIndex: Int? = nil, rule: String, expected: String, actual: String, confidence: Double) {
        self.phoneme = phoneme
        self.word = word
        self.wordIndex = wordIndex
        self.rule = rule
        self.expected = expected
        self.actual = actual
        self.confidence = confidence
    }
}

// MARK: - Word Error Group Model

struct WordErrorGroup: Identifiable {
    let id = UUID()
    let word: String
    let errors: [TajweedError]
    let positionInVerse: Int
}

// MARK: - Phoneme Error Group (groups errors by same letter)

struct PhonemeErrorGroup: Identifiable {
    let id = UUID()
    let phoneme: String
    let errors: [TajweedError]
}

// MARK: - Word Error Card View (Groups all errors for one word)

struct WordErrorCardView: View {
    let group: WordErrorGroup
    let uthmaniText: String
    @State private var selectedPhonemeIndex: Int? = nil
    
    /// Group errors by phoneme (same letter gets grouped together)
    private var phonemeGroups: [PhonemeErrorGroup] {
        var groups: [String: [TajweedError]] = [:]
        var order: [String] = []
        
        for error in group.errors {
            if groups[error.phoneme] == nil {
                order.append(error.phoneme)
                groups[error.phoneme] = []
            }
            groups[error.phoneme]?.append(error)
        }
        
        return order.map { phoneme in
            PhonemeErrorGroup(phoneme: phoneme, errors: groups[phoneme] ?? [])
        }
    }
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            // Word display with conditional highlighting
            HStack {
                // Error count badge (total errors, not phoneme groups)
                Text("\(group.errors.count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.red)
                    .clipShape(Circle())
                
                Spacer()
                
                // Word (highlighted based on selection)
                Text(highlightedWord)
                    .font(.custom("KFGQPC Hafs Smart Regular", size: 24))
                    .multilineTextAlignment(.trailing)
            }
            .padding(.bottom, 4)
            
            Divider()
            
            // Clickable phoneme groups (errors grouped by letter)
            VStack(spacing: 8) {
                ForEach(Array(phonemeGroups.enumerated()), id: \.element.id) { index, phonemeGroup in
                    PhonemeGroupButton(
                        phonemeGroup: phonemeGroup,
                        isSelected: selectedPhonemeIndex == index,
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if selectedPhonemeIndex == index {
                                    selectedPhonemeIndex = nil
                                } else {
                                    selectedPhonemeIndex = index
                                }
                            }
                        }
                    )
                }
            }
        }
        .padding()
        .background(Color.red.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var highlightedWord: AttributedString {
        var result = AttributedString(group.word)
        result.font = .custom("KFGQPC Hafs Smart Regular", size: 24)
        
        guard let selectedIndex = selectedPhonemeIndex,
              selectedIndex < phonemeGroups.count else {
            return result
        }
        
        let selectedPhonemeGroup = phonemeGroups[selectedIndex]
        let originalPhoneme = selectedPhonemeGroup.phoneme
        
        // 1. Clean up the phoneme
        // Strip diacritics from the phoneme itself
        let phonemeBase = stripArabicDiacritics(originalPhoneme)
        
        // Handle repeated chars (shadda): "تت" -> "ت"
        // If all chars are the same, reduce to one
        let uniqueChars = Set(phonemeBase)
        let targetBase = (uniqueChars.count == 1 && !phonemeBase.isEmpty) ? String(uniqueChars.first!) : phonemeBase
        
        // Get mappings for target (e.g. ۦ -> ي)
        let mappings = getCharMappings(for: targetBase)
        
        // Iterate through the attributed string characters
        var currentIndex = result.startIndex
        while currentIndex < result.endIndex {
            // Extract the character at current index
            let range = currentIndex...currentIndex
            let charSlice = result[range]
            let charStr = String(charSlice.characters)
            
            // Clean the word character
            let charBase = stripArabicDiacritics(charStr)
            
            // Match logic:
            // 1. Base match: charBase == targetBase (e.g. د == د)
            // 2. Mapping match: mappings contains charBase (e.g. ۦ maps to ي)
            // 3. Containment (fallback): targetBase contains charBase (e.g. phoneme="تت", char="ت")
            let isMatch = !charBase.isEmpty && (
                charBase == targetBase ||
                mappings.contains(charBase) ||
                (targetBase.contains(charBase) && targetBase.count > charBase.count)
            )
            
            if isMatch {
                result[range].foregroundColor = .red
                result[range].backgroundColor = .red.opacity(0.2)
            }
            
            currentIndex = result.index(afterCharacter: currentIndex)
        }
        
        return result
    }
    
    private func getCharMappings(for char: String) -> Set<String> {
        let mappings: [String: [String]] = [
            // Hamza variants
            "ء": ["أ", "إ", "آ", "ؤ", "ئ", "ٱ"],
            "أ": ["ء", "إ", "آ", "ٱ"],
            "إ": ["ء", "أ", "آ", "ٱ"],
            // Alef variants
            "ا": ["آ", "أ", "إ", "ٰ", "ى", "ٱ", "ـٰ"],
            "ٱ": ["ا", "آ", "أ", "إ"],
            "ٰ": ["ا"],
            "ـٰ": ["ا"],
            // Ha/Ta marbuta
            "ه": ["ة", "ھ"],
            "ة": ["ه"],
            // Yaa variants
            "ي": ["ى", "ۦ", "ئ", "ی"],
            "ى": ["ي", "ۦ"],
            "ۦ": ["ي", "ى", "ئ"],
            // Waw variants
            "و": ["ۥ", "ؤ"],
            "ۥ": ["و", "ؤ"],
            // Common substitutions
            "ن": ["ں"],
            "ر": ["ڔ"],
            "ل": ["ڵ"],
            "ك": ["ک"]
        ]
        
        var result = Set<String>()
        // Direct mapping
        if let direct = mappings[char] {
            result.formUnion(direct)
        }
        
        // Check per-character for longer strings (rare)
        for c in char {
            if let m = mappings[String(c)] {
                result.formUnion(m)
            }
        }
        
        return result
    }
    
    private func stripArabicDiacritics(_ text: String) -> String {
        // We use a custom regex for highlighting that preserves small madd letters (ۦ, ۥ)
        // Original range was: ...\\u06d6-\\u06ed...
        // We split it to exclude \\u06e5 (small waw) and \\u06e6 (small yea)
        // Range 1: \\u06d6-\\u06e4
        // Range 2: \\u06e7-\\u06ed
        
        let pattern = "[\\u064b-\\u065f\\u0610-\\u061a\\u06d6-\\u06e4\\u06e7-\\u06ed\\u08d4-\\u08e1\\u08e3-\\u08ff]"
        
        // Cache the regex if possible or just create it (performance impact negligible for short words)
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        
        return regex?.stringByReplacingMatches(
            in: text,
            options: [],
            range: NSMakeRange(0, text.unicodeScalars.count),
            withTemplate: ""
        ) ?? text
    }
}

// MARK: - Phoneme Group Button (Groups multiple errors for same letter)

struct PhonemeGroupButton: View {
    let phonemeGroup: PhonemeErrorGroup
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .trailing, spacing: 6) {
                // Header row: selection indicator and phoneme
                HStack(spacing: 8) {
                    // Selection indicator
                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(isSelected ? .red : .secondary)
                        .font(.body)
                    
                    Spacer()
                    
                    // Phoneme (the letter)
                    Text(phonemeGroup.phoneme)
                        .font(.custom("KFGQPC Hafs Smart Regular", size: 20))
                        .foregroundStyle(isSelected ? .red : .primary)
                }
                
                // Always show all errors (no expand/collapse)
                VStack(alignment: .trailing, spacing: 4) {
                    ForEach(phonemeGroup.errors) { error in
                        HStack(spacing: 4) {
                            Text(error.expected)
                                .font(.caption)
                                .foregroundStyle(.green)
                            
                            Image(systemName: "arrow.left")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            
                            Text(error.actual)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.red.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Error Item Button (Clickable error in the list)

struct ErrorItemButton: View {
    let error: TajweedError
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // Selection indicator
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? .red : .secondary)
                    .font(.body)
                
                // Phoneme
                Text(error.phoneme)
                    .font(.custom("KFGQPC Hafs Smart Regular", size: 18))
                    .foregroundStyle(isSelected ? .red : .primary)
                    .frame(width: 40)
                
                // Rule
                Text(error.rule)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                // Expected → Actual
                HStack(spacing: 4) {
                    Text(error.expected)
                        .font(.caption)
                        .foregroundStyle(.green)
                    
                    Image(systemName: "arrow.left")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Text(error.actual)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.red.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Legacy Error Row View (kept for compatibility)

struct ErrorRowView: View {
    let error: TajweedError
    
    var body: some View {
        VStack(spacing: 8) {
            // Word with highlighted letter
            HStack {
                Text(highlightedWord)
                    .font(.custom("KFGQPC Hafs Smart Regular", size: 20))
                
                Spacer()
                
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.title3)
            }
            
            // Details row
            HStack(spacing: 12) {
                // Rule
                VStack(alignment: .leading, spacing: 2) {
                    Text("القاعدة")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(error.rule)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Expected
                VStack(alignment: .center, spacing: 2) {
                    Text("المتوقع")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(error.expected)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                }
                .frame(maxWidth: .infinity)
                
                // Actual
                VStack(alignment: .center, spacing: 2) {
                    Text("قراءتك")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(error.actual)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.red)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding()
        .background(Color.red.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var highlightedWord: AttributedString {
        var result = AttributedString(error.word)
        
        // Set base font for the whole word
        result.font = .custom("KFGQPC Hafs Smart Regular", size: 22)
        
        // Get the base letter from phoneme (strip diacritics)
        let phonemeBase = stripArabicDiacritics(error.phoneme)
        
        // Try multiple matching strategies
        var foundMatch = false
        
        // Strategy 1: Exact match
        if let range = result.range(of: error.phoneme) {
            result[range].foregroundColor = .red
            foundMatch = true
        }
        
        // Strategy 2: Match base letter (without diacritics)
        if !foundMatch && !phonemeBase.isEmpty {
            // Try to find the base letter in the word
            let wordString = error.word
            for (index, char) in wordString.enumerated() {
                let charBase = stripArabicDiacritics(String(char))
                if charBase == phonemeBase {
                    // Found matching base letter, highlight it
                    let startIndex = wordString.index(wordString.startIndex, offsetBy: index)
                    let endIndex = wordString.index(startIndex, offsetBy: 1)
                    if let attrRange = result.range(of: String(wordString[startIndex..<endIndex])) {
                        result[attrRange].foregroundColor = .red
                        foundMatch = true
                        break
                    }
                }
            }
        }
        
        // Strategy 3: Try common Arabic letter mappings
        if !foundMatch {
            let mappings: [String: [String]] = [
                "ء": ["أ", "إ", "آ", "ؤ", "ئ", "ٱ"],
                "ا": ["آ", "أ", "إ", "ٰ", "ى"],
                "ه": ["ة"],
                "ي": ["ى", "ۦ"],
                "و": ["ۥ"],
                "ن": ["ں"],
                "ر": ["ڔ"],
                "ل": ["ڵ"],
            ]
            
            for char in error.phoneme {
                let charStr = String(char)
                var charsToTry = [charStr]
                
                // Add mapped variations
                if let variations = mappings[charStr] {
                    charsToTry.append(contentsOf: variations)
                }
                
                // Try each variation
                for tryChar in charsToTry {
                    if let range = result.range(of: tryChar) {
                        result[range].foregroundColor = .red
                        foundMatch = true
                        break
                    }
                }
                if foundMatch { break }
            }
        }
        
        // Strategy 4: Just highlight the first non-diacritic character in the word
        if !foundMatch {
            let diacritics: Set<Character> = ["َ", "ُ", "ِ", "ْ", "ً", "ٌ", "ٍ", "ّ", "ٰ", "ۡ", "ۢ", "ۣ", "ۤ", "ۧ", "ۨ", "۪", "۫", "۬", "ۭ"]
            for char in error.word {
                if !diacritics.contains(char) {
                    if let range = result.range(of: String(char)) {
                        result[range].foregroundColor = .red
                        break
                    }
                }
            }
        }
        
        return result
    }
    
    /// Strip Arabic diacritics from a string to get base letter
    private func stripArabicDiacritics(_ text: String) -> String {
        let diacritics: Set<Character> = [
            "َ", "ُ", "ِ", "ْ", "ً", "ٌ", "ٍ", "ّ", "ٰ", "ۡ", "ۢ", "ۣ", "ۤ", "ۧ", "ۨ", "۪", "۫", "۬", "ۭ",
            "\u{0610}", "\u{0611}", "\u{0612}", "\u{0613}", "\u{0614}", "\u{0615}", "\u{0616}", "\u{0617}",
            "\u{0618}", "\u{0619}", "\u{061A}", "\u{064B}", "\u{064C}", "\u{064D}", "\u{064E}", "\u{064F}",
            "\u{0650}", "\u{0651}", "\u{0652}", "\u{0653}", "\u{0654}", "\u{0655}", "\u{0656}", "\u{0657}",
            "\u{0658}", "\u{0659}", "\u{065A}", "\u{065B}", "\u{065C}", "\u{065D}", "\u{065E}", "\u{065F}"
        ]
        return String(text.filter { !diacritics.contains($0) })
    }
}

// MARK: - Sifa Item View

struct SifaItemView: View {
    let sifa: SifaItem
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Text(sifa.phonemesGroup)
                        .font(.custom("KFGQPC Hafs Smart Regular", size: 22))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            
            // Expanded Details
            if isExpanded {
                VStack(spacing: 8) {
                    if let unit = sifa.hamsOrJahr {
                        SifaRow(label: "الهمس/الجهر", value: arabicSifaName(unit.text), prob: unit.prob)
                    }
                    if let unit = sifa.shiddaOrRakhawa {
                        SifaRow(label: "الشدة/الرخاوة", value: arabicSifaName(unit.text), prob: unit.prob)
                    }
                    if let unit = sifa.tafkheemOrTaqeeq {
                        SifaRow(label: "التفخيم/الترقيق", value: arabicSifaName(unit.text), prob: unit.prob)
                    }
                    if let unit = sifa.ghonna {
                        SifaRow(label: "الغنة", value: arabicSifaName(unit.text), prob: unit.prob)
                    }
                    if let unit = sifa.qalqla {
                        SifaRow(label: "القلقلة", value: arabicSifaName(unit.text), prob: unit.prob)
                    }
                    if let unit = sifa.safeer {
                        SifaRow(label: "الصفير", value: arabicSifaName(unit.text), prob: unit.prob)
                    }
                    if let unit = sifa.tikraar {
                        SifaRow(label: "التكرار", value: arabicSifaName(unit.text), prob: unit.prob)
                    }
                    if let unit = sifa.tafashie {
                        SifaRow(label: "التفشي", value: arabicSifaName(unit.text), prob: unit.prob)
                    }
                    if let unit = sifa.istitala {
                        SifaRow(label: "الاستطالة", value: arabicSifaName(unit.text), prob: unit.prob)
                    }
                    if let unit = sifa.itbaq {
                        SifaRow(label: "الإطباق", value: arabicSifaName(unit.text), prob: unit.prob)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
    }
    
    private func arabicSifaName(_ english: String) -> String {
        let translations: [String: String] = [
            "hams": "همس",
            "jahr": "جهر",
            "shadeed": "شديد",
            "between": "بين بين",
            "rikhw": "رخاوة",
            "mofakham": "مفخم",
            "moraqaq": "مرقق",
            "low_mofakham": "تفخيم خفيف",
            "monfateh": "منفتح",
            "motbaq": "مطبق",
            "safeer": "صفير",
            "no_safeer": "بدون صفير",
            "moqalqal": "مقلقل",
            "not_moqalqal": "بدون قلقلة",
            "mokarar": "مكرر",
            "not_mokarar": "بدون تكرار",
            "motafashie": "متفشي",
            "not_motafashie": "بدون تفشي",
            "mostateel": "مستطيل",
            "not_mostateel": "بدون استطالة",
            "maghnoon": "مغنون",
            "not_maghnoon": "بدون غنة",
        ]
        return translations[english] ?? english
    }
}

// MARK: - Madd Letter Mapping

/// Maps phonetic madd symbols to their corresponding Arabic letters
func maddLetterMapping(_ phoneme: String) -> [String] {
    // ۦ (small yaa) represents madd on ي
    // ۥ (small waw) represents madd on و
    // ا represents itself and variants
    var mappings: [String] = [phoneme]
    
    for char in phoneme {
        switch char {
        case "ۦ": // Small yaa madd symbol
            mappings.append(contentsOf: ["ي", "ى", "ئ"])
        case "ۥ": // Small waw madd symbol
            mappings.append(contentsOf: ["و", "ؤ"])
        case "ا", "آ", "أ", "إ", "ٱ":
            mappings.append(contentsOf: ["ا", "آ", "أ", "إ", "ٱ", "ى"])
        default:
            break
        }
    }
    
    return mappings
}

// MARK: - Sifa Row

struct SifaRow: View {
    let label: String
    let value: String
    let prob: Double
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            HStack(spacing: 8) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                // Confidence indicator
                Circle()
                    .fill(confidenceColor)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var confidenceColor: Color {
        switch prob {
        case 0.9...: return .green
        case 0.7..<0.9: return .orange
        default: return .red
        }
    }
}

#Preview {
    NavigationStack {
        ResultsView(result: AnalyzeResponse(
            phonemesText: "بِسمِ ٱللَّهِ",
            phonemes: PhonemeUnit(text: "بِسمِ ٱللَّهِ", probs: [0.95, 0.98, 0.92], ids: [1, 2, 3]),
            sifat: [
                SifaItem(
                    phonemesGroup: "بِ",
                    index: 0,
                    hamsOrJahr: SingleUnit(text: "jahr", prob: 0.98, idx: 2),
                    shiddaOrRakhawa: SingleUnit(text: "shadeed", prob: 0.95, idx: 1),
                    tafkheemOrTaqeeq: SingleUnit(text: "moraqaq", prob: 0.72, idx: 2),
                    itbaq: SingleUnit(text: "monfateh", prob: 0.99, idx: 1),
                    safeer: SingleUnit(text: "no_safeer", prob: 0.97, idx: 2),
                    qalqla: SingleUnit(text: "not_moqalqal", prob: 0.88, idx: 2),
                    tikraar: SingleUnit(text: "not_mokarar", prob: 0.99, idx: 2),
                    tafashie: SingleUnit(text: "not_motafashie", prob: 0.96, idx: 2),
                    istitala: SingleUnit(text: "not_mostateel", prob: 0.98, idx: 2),
                    ghonna: SingleUnit(text: "not_maghnoon", prob: 0.74, idx: 2)
                ),
                SifaItem(
                    phonemesGroup: "سْ",
                    index: 1,
                    hamsOrJahr: SingleUnit(text: "hams", prob: 0.95, idx: 1),
                    shiddaOrRakhawa: SingleUnit(text: "rikhw", prob: 0.92, idx: 3),
                    tafkheemOrTaqeeq: SingleUnit(text: "moraqaq", prob: 0.98, idx: 2),
                    itbaq: SingleUnit(text: "monfateh", prob: 0.99, idx: 1),
                    safeer: SingleUnit(text: "safeer", prob: 0.97, idx: 1),
                    qalqla: SingleUnit(text: "not_moqalqal", prob: 0.99, idx: 2),
                    tikraar: SingleUnit(text: "not_mokarar", prob: 0.99, idx: 2),
                    tafashie: SingleUnit(text: "not_motafashie", prob: 0.98, idx: 2),
                    istitala: SingleUnit(text: "not_mostateel", prob: 0.99, idx: 2),
                    ghonna: SingleUnit(text: "not_maghnoon", prob: 0.97, idx: 2)
                )
            ],
            reference: Reference(
                sura: 1,
                aya: 1,
                uthmaniText: "بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ",
                moshaf: Moshaf(rewaya: "hafs", maddMonfaselLen: 2, maddMottaselLen: 4, maddMottaselWaqf: 4, maddAaredLen: 2),
                phoneticScript: PhoneticScript(phonemesText: "بِسمِ ٱللَّهِ")
            ),
            expectedSifat: nil,
            phonemeDiff: [
                PhonemeDiffItem(type: "equal", text: "بِسمِ ٱل"),
                PhonemeDiffItem(type: "delete", text: "ل"),
                PhonemeDiffItem(type: "equal", text: "لَّهِ")
            ],
            sifatErrors: [
                SifatComparisonError(
                    index: 0,
                    phoneme: "بِ",
                    expectedPhoneme: "بِ",
                    errors: [
                        SifaAttributeError(
                            attribute: "ghonna",
                            attributeAr: "الغنة",
                            expected: "not_maghnoon",
                            actual: "maghnoon",
                            prob: 0.74
                        )
                    ]
                )
            ],
            phonemesByWord: nil
        ))
    }
}
