//
//  FuzzyMatcher.swift
//  Offline_Mission_Control
//
//  Matches a spoken transcript against a state's `expected_indication`. The indications are long
//  natural phrases, so we score on significant-keyword overlap (recall of the expected phrase's
//  key words in the heard text) rather than whole-string edit distance — robust to reordering,
//  partial transcripts, and filler words. Digits are folded to words so "4 of 4" ≈ "four of four".
//

import Foundation

enum FuzzyMatcher {
    /// True when the heard text covers enough of the expected phrase's significant keywords.
    /// `minHits` is the floor on absolute keyword matches (so a single shared word can't confirm
    /// at strict levels); lower it for more lenient matching.
    static func matches(heard: String, expected: String?, threshold: Double = 0.5, minHits: Int = 2) -> Bool {
        guard let expected else { return false }
        let expectedKeywords = keywords(in: expected)
        guard !expectedKeywords.isEmpty else { return false }
        let heardTokens = Set(tokens(in: heard))
        let hits = expectedKeywords.filter { heardTokens.contains($0) }.count
        let recall = Double(hits) / Double(expectedKeywords.count)
        return hits >= min(minHits, expectedKeywords.count) && recall >= threshold
    }

    /// Recall of expected keywords present in the heard text (0...1) — for logging/debug.
    static func score(heard: String, expected: String) -> Double {
        let expectedKeywords = keywords(in: expected)
        guard !expectedKeywords.isEmpty else { return 0 }
        let heardTokens = Set(tokens(in: heard))
        let hits = expectedKeywords.filter { heardTokens.contains($0) }.count
        return Double(hits) / Double(expectedKeywords.count)
    }

    // MARK: - Normalization

    private static let stopwords: Set<String> = [
        "the","and","for","you","your","with","that","this","then","than","into","onto","each",
        "both","not","does","done","will","was","were","are","has","have","its","from","off","out",
        "of","on","to","in","at","it","is","be","as","by","up","we","he","or","an","no","do","a","i"
    ]

    private static let numberWords: [String: String] = [
        "0":"zero","1":"one","2":"two","3":"three","4":"four","5":"five","6":"six","7":"seven",
        "8":"eight","9":"nine","10":"ten","11":"eleven","12":"twelve"
    ]

    /// Lowercased, punctuation-stripped tokens with digits folded to words.
    private static func tokens(in text: String) -> [String] {
        let scalars = text.lowercased().unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        return String(scalars)
            .split(separator: " ")
            .map { numberWords[String($0)] ?? String($0) }
    }

    /// Significant keywords: not stopwords, length ≥ 2.
    private static func keywords(in text: String) -> Set<String> {
        Set(tokens(in: text).filter { $0.count >= 2 && !stopwords.contains($0) })
    }
}
