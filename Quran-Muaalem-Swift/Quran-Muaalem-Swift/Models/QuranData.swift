//
//  QuranData.swift
//  Quran-Muaalem-Swift
//
//  Created by Tarek Mansour on 11/29/25.
//

import Foundation

struct Sura: Identifiable, Hashable {
    let id: Int
    let name: String
    let arabicName: String
    let ayaCount: Int
    
    var displayName: String {
        "\(id). \(arabicName)"
    }
}

// MARK: - Aya Entry from hafs_smart_v8.json

struct AyaEntry: Codable {
    let id: Int
    let jozz: Int
    let suraNo: Int
    let suraNameEn: String
    let suraNameAr: String
    let page: Int
    let line: Int
    let ayaNo: Int
    let ayaText: String
    let ayaTextEmlaey: String
    
    enum CodingKeys: String, CodingKey {
        case id, jozz, page, line
        case suraNo = "sura_no"
        case suraNameEn = "sura_name_en"
        case suraNameAr = "sura_name_ar"
        case ayaNo = "aya_no"
        case ayaText = "aya_text"
        case ayaTextEmlaey = "aya_text_emlaey"
    }
}

// MARK: - Quran Data

enum QuranData {
    
    // MARK: - Data Loading
    
    /// Cached aya entries from hafs_smart_v8.json
    private static var ayaEntries: [AyaEntry]? = {
        guard let url = Bundle.main.url(forResource: "hafs_smart_v8", withExtension: "json") else {
            print("⚠️ [QuranData] Could not find hafs_smart_v8.json")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let entries = try JSONDecoder().decode([AyaEntry].self, from: data)
            print("✅ [QuranData] Loaded \(entries.count) aya entries from hafs_smart_v8.json")
            return entries
        } catch {
            print("❌ [QuranData] Failed to load hafs_smart_v8.json: \(error)")
            return nil
        }
    }()
    
    /// List of Suras derived from the JSON data
    static var suras: [Sura] = {
        guard let entries = ayaEntries else { return [] }
        
        let grouped = Dictionary(grouping: entries, by: { $0.suraNo })
        let sortedKeys = grouped.keys.sorted()
        
        return sortedKeys.map { suraNo in
            let suraEntries = grouped[suraNo]!
            let first = suraEntries.first!
            return Sura(
                id: suraNo,
                name: first.suraNameEn,
                arabicName: first.suraNameAr,
                ayaCount: suraEntries.count
            )
        }
    }()
    
    static func sura(byId id: Int) -> Sura? {
        suras.first { $0.id == id }
    }
    
    // MARK: - Helper Methods
    
    /// Get the Uthmani text (with smart font codes) for a specific aya
    static func getAyaText(sura: Int, aya: Int) -> String? {
        ayaEntries?.first(where: { $0.suraNo == sura && $0.ayaNo == aya })?.ayaText
    }
    
    /// Get the simple Imla'i text for a specific aya
    /// Returns words like ["ذلك", "الكتاب", "لا", "ريب", "فيه", "هدى", "للمتقين"]
    /// instead of complex Uthmani ["ذَٰلِكَ", "ٱلْكِتَـٰبُ", ...]
    static func getEmlaeyWords(sura: Int, aya: Int) -> [String]? {
        guard let entries = ayaEntries else { return nil }
        
        if let entry = entries.first(where: { $0.suraNo == sura && $0.ayaNo == aya }) {
            let words = entry.ayaTextEmlaey.components(separatedBy: " ").filter { !$0.isEmpty }
            return words
        }
        
        return nil
    }
}

