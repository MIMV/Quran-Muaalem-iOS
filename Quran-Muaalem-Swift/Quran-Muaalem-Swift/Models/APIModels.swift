//
//  APIModels.swift
//  Quran-Muaalem-Swift
//
//  Created by Tarek Mansour on 11/29/25.
//

import Foundation

// MARK: - API Response Models

struct AnalyzeResponse: Codable {
    let phonemesText: String
    let phonemes: PhonemeUnit
    let sifat: [SifaItem]
    let reference: Reference
    
    // Expected sifat from phonetizer
    let expectedSifat: [ExpectedSifaItem]?
    // Phoneme diff (insertions, deletions, matches)
    let phonemeDiff: [PhonemeDiffItem]?
    // Sifat comparison errors
    let sifatErrors: [SifatComparisonError]?
    // NEW: Word-by-word phonemes with sifat index ranges
    // This makes mapping errors to words trivial!
    let phonemesByWord: [WordPhonemes]?
    
    enum CodingKeys: String, CodingKey {
        case phonemesText = "phonemes_text"
        case phonemes, sifat, reference
        case expectedSifat = "expected_sifat"
        case phonemeDiff = "phoneme_diff"
        case sifatErrors = "sifat_errors"
        case phonemesByWord = "phonemes_by_word"
    }
    
    // Custom initializer with default values for optional properties
    init(
        phonemesText: String,
        phonemes: PhonemeUnit,
        sifat: [SifaItem],
        reference: Reference,
        expectedSifat: [ExpectedSifaItem]? = nil,
        phonemeDiff: [PhonemeDiffItem]? = nil,
        sifatErrors: [SifatComparisonError]? = nil,
        phonemesByWord: [WordPhonemes]? = nil
    ) {
        self.phonemesText = phonemesText
        self.phonemes = phonemes
        self.sifat = sifat
        self.reference = reference
        self.expectedSifat = expectedSifat
        self.phonemeDiff = phonemeDiff
        self.sifatErrors = sifatErrors
        self.phonemesByWord = phonemesByWord
    }
}

// MARK: - Word Phonemes (word-by-word breakdown from server)

/// Server-provided mapping of words to their phonemes and sifat index ranges.
/// This eliminates the need for complex client-side word mapping!
struct WordPhonemes: Codable, Identifiable {
    var id: Int { wordIndex }
    
    let wordIndex: Int
    let word: String
    let phonemes: String
    let sifatStart: Int
    let sifatEnd: Int
    let sifatCount: Int
    
    enum CodingKeys: String, CodingKey {
        case wordIndex = "word_index"
        case word, phonemes
        case sifatStart = "sifat_start"
        case sifatEnd = "sifat_end"
        case sifatCount = "sifat_count"
    }
    
    /// Check if a given sifat index belongs to this word
    func containsIndex(_ index: Int) -> Bool {
        return index >= sifatStart && index <= sifatEnd
    }
}

// MARK: - Expected Sifa (from phonetizer reference)

struct ExpectedSifaItem: Codable, Identifiable {
    var id: Int { index }
    
    let index: Int
    let phonemes: String
    let hamsOrJahr: String?
    let shiddaOrRakhawa: String?
    let tafkheemOrTaqeeq: String?
    let itbaq: String?
    let safeer: String?
    let qalqla: String?
    let tikraar: String?
    let tafashie: String?
    let istitala: String?
    let ghonna: String?
    
    enum CodingKeys: String, CodingKey {
        case index, phonemes
        case hamsOrJahr = "hams_or_jahr"
        case shiddaOrRakhawa = "shidda_or_rakhawa"
        case tafkheemOrTaqeeq = "tafkheem_or_taqeeq"
        case itbaq, safeer, qalqla, tikraar, tafashie, istitala, ghonna
    }
}

// MARK: - Phoneme Diff

struct PhonemeDiffItem: Codable, Identifiable {
    var id: String { "\(type)-\(text)" }
    
    let type: String  // "equal", "insert", "delete"
    let text: String
}

// MARK: - Sifat Comparison Error

struct SifatComparisonError: Codable, Identifiable {
    var id: Int { index }
    
    let index: Int
    let phoneme: String
    let expectedPhoneme: String
    let errors: [SifaAttributeError]
    
    enum CodingKeys: String, CodingKey {
        case index, phoneme
        case expectedPhoneme = "expected_phoneme"
        case errors
    }
}

struct SifaAttributeError: Codable, Identifiable {
    var id: String { attribute }
    
    let attribute: String
    let attributeAr: String
    let expected: String
    let actual: String
    let prob: Double
    
    enum CodingKeys: String, CodingKey {
        case attribute
        case attributeAr = "attribute_ar"
        case expected, actual, prob
    }
}

struct PhonemeUnit: Codable {
    let text: String
    let probs: [Double]
    let ids: [Int]
}

struct SifaItem: Codable, Identifiable {
    var id: Int { index }
    
    let phonemesGroup: String
    let index: Int
    let hamsOrJahr: SingleUnit?
    let shiddaOrRakhawa: SingleUnit?
    let tafkheemOrTaqeeq: SingleUnit?
    let itbaq: SingleUnit?
    let safeer: SingleUnit?
    let qalqla: SingleUnit?
    let tikraar: SingleUnit?
    let tafashie: SingleUnit?
    let istitala: SingleUnit?
    let ghonna: SingleUnit?
    
    enum CodingKeys: String, CodingKey {
        case phonemesGroup = "phonemes_group"
        case index
        case hamsOrJahr = "hams_or_jahr"
        case shiddaOrRakhawa = "shidda_or_rakhawa"
        case tafkheemOrTaqeeq = "tafkheem_or_taqeeq"
        case itbaq, safeer, qalqla, tikraar, tafashie, istitala, ghonna
    }
}

struct SingleUnit: Codable {
    let text: String
    let prob: Double
    let idx: Int
}

struct Reference: Codable {
    let sura: Int?
    let aya: Int?
    let uthmaniText: String
    let moshaf: Moshaf
    let phoneticScript: PhoneticScript
    
    enum CodingKeys: String, CodingKey {
        case sura, aya
        case uthmaniText = "uthmani_text"
        case moshaf
        case phoneticScript = "phonetic_script"
    }
}

struct Moshaf: Codable {
    let rewaya: String
    let maddMonfaselLen: Int
    let maddMottaselLen: Int
    let maddMottaselWaqf: Int
    let maddAaredLen: Int
    
    enum CodingKeys: String, CodingKey {
        case rewaya
        case maddMonfaselLen = "madd_monfasel_len"
        case maddMottaselLen = "madd_mottasel_len"
        case maddMottaselWaqf = "madd_mottasel_waqf"
        case maddAaredLen = "madd_aared_len"
    }
}

struct PhoneticScript: Codable {
    let phonemesText: String
    
    enum CodingKeys: String, CodingKey {
        case phonemesText = "phonemes_text"
    }
}

// MARK: - Error Response

struct APIError: Codable, Error {
    let detail: String
}

