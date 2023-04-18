/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

// A type that sorts and filters a list of strings based on how "similar" they are to a given string.
//
// This is meant mainly for diagnostics that wan't to offer meaning full suggestions to the end-user.
enum NearMiss {
    
    /// Returns the "best matches" among a list of possibilities based on how "similar" they are to a given string.
    static func bestMatches<Possibilities: Sequence>(for possibilities: Possibilities, against authored: String) -> [String] where Possibilities.Element == String {
        // There is no single right or wrong way to score changes. This implementation is completely arbitrary.
        // It's chosen because the relative scores that it computes provide "best match" results that are close
        // to what a person would expect. See ``NearMissTests``.
        
        let goodMatches = possibilities.lazy
            .map { (text: String) -> (text: String, score: Double) in
                (text, NearMiss.score(CollectionChanges(from: authored, to: text)))
            }
            .filter {
                // A negative score is not considered very "similar" in this implementation.
                0 < $0.score
            }
            .sorted(by: { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.text < rhs.text // Sort same score alphabetically
                }
                return lhs.score > rhs.score // Sort by high score
            })
        
        // Some common prefixes result in a large number of matches. For example, many types in Swift-DocC have
        // a "Documentation" prefix which yields a fairly high score in this implementation. To counteract this
        // we additionally filter out any match with a score that's less than 25% of the highest match's score.
        guard let bestScore = goodMatches.first?.score else {
            return []
        }
        let matchThreshold = bestScore / 4
        
        return goodMatches
            .prefix(while: { matchThreshold < $0.score })
            // More than 10 results are likely not helpful to the user.
            .prefix(10)
            .map { $0.text }
    }
    
    /// Computes the "score" for a collection of change segments.
    private static func score(_ changes: CollectionChanges) -> Double {
        // Again, there is no right or wrong way to score changes and this implementation is completely arbitrary.
        
        // Give the first segment a bit more weight to its contribution to the total score
        guard let first = changes.segments.first else { return 0 }
        var score = NearMiss.score(first) * 1.75
        
        for segment in changes.segments.dropFirst() {
            score += NearMiss.score(segment)
        }
        return score
    }
        
    /// Computes the "score" for a single collection change segments.
    private static func score(_ segment: CollectionChanges.Segment) -> Double {
        // Again, there is no right or wrong way to score changes and this implementation is completely arbitrary.
        
        // This implementation is built around a few basic ideas:
        //
        //  - Common segments _add_ to a change collection's score,
        //  - Inserted and removed segments _subtract from_ a change collection's score.
        //  - Short "common segments" occur in differences that are very different ("orange" and "lemon" both contain a "e").
        //  - A long sequence of common elements should contribute more than an equal length sequence of different characters.
        //    In other words; a 50% match is still "good".
        //  - The longer a common segment is, the more "similar" to two strings are.
        //  - A removed segment contribute more than an inserted segment (since the author had written those characters).
        
        switch segment.kind {
        case .common:
            if segment.count < 3 {
                // 1, or 2 common characters are too few to be what a person would consider a similarity.
                return 0.0
            } else {
                // To produce higher contributions for longer common sequences, this implementation sums the sequence (1...length)
                // and adds an arbitrary constant factor.
                return Double((1...segment.count).sum()) + 3
            }
            
        // Segments of removed or inserted characters contribute to the score no matter the segment length.
        //
        // The score is linear to the length with scale factors that are tweaked to provide "best match" results that are close
        // to what a person would expect. See ``NearMissTests``.
        case .insert:
            return -Double(segment.count) * 1.5
        case .remove:
            // Removed characters contribute more than inserted characters since they represent something that the author wrote
            // that is missing in this match.
            return -Double(segment.count) * 3.0
        }
    }
}

private extension ClosedRange where Bound == Int {
    func sum() -> Int {
        return (lowerBound + upperBound) * count / 2
    }
}
