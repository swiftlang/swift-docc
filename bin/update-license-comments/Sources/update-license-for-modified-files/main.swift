/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

// Determine what changes to consider

enum DiffStrategy {
    case stagedFiles
    case comparingTo(treeish: String)
}

let arguments = ProcessInfo.processInfo.arguments.dropFirst()
let diffStrategy: DiffStrategy
switch arguments.first {
    case "-h", "--help":
        print("""
        OVERVIEW: Update the year in the license comment of modified files

        USAGE: swift run update-license-for-modified-files [--staged | <tree-ish>]

        To update the year for staged, but not yet committed files, run:
            swift run update-license-for-modified-files --staged
        
        To update the year for all already committed changes that are different from the 'main' branch, run:
            swift run update-license-for-modified-files
        
        To update the year for the already committed changes in the last commit, run:
            swift run update-license-for-modified-files HEAD~
        
        You can specify any other branch or commit for this argument but I don't know if there's a real use case for doing so.
        """)
        exit(0)
        
    case nil:
        diffStrategy = .comparingTo(treeish: "main")
    case "--staged", "--cached":
        diffStrategy = .stagedFiles
    case let treeish?:
        diffStrategy = .comparingTo(treeish: treeish)
}

// Find which files are modified

let repoURL: URL = {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // main.swift
        .deletingLastPathComponent() // update-license-for-modified-files
        .deletingLastPathComponent() // Sources
        .deletingLastPathComponent() // update-license-comments
        .deletingLastPathComponent() // bin
    guard FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) else {
        fatalError("The path to the Swift-DocC source root has changed. This should only happen if the 'update-license-comments' sources have moved relative to the Swift-DocC repo.")
    }
    return url
}()

let modifiedFiles = try findModifiedFiles(in: repoURL, strategy: diffStrategy)

// Update the years in the license comment where necessary

//                                        An optional lower range of years for the license comment (including the hyphen)
//                                        │            The upper range of years for the license comment
//                                        │            │                The markdown files don't have a "." but the Swift files do
//                                        │            │                 │                 The markdown files capitalize the P but the Swift files don't
//                                        │            │                 │                 │
//                                  ╭─────┴──────╮╭────┴─────╮          ╭┴╮               ╭┴─╮
let licenseRegex = /Copyright \(c\) (20[0-9]{2}-)?(20[0-9]{2}) Apple Inc\.? and the Swift [Pp]roject authors/

let currentYear = Calendar.current.component(.year, from: .now)

for file in modifiedFiles {
    guard var content = try? String(contentsOf: file, encoding: .utf8),
          let licenseMatch = try? licenseRegex.firstMatch(in: content)
    else {
        // Didn't encounter a license comment in this file, do nothing
        continue
    }

    let upperYearSubstring = licenseMatch.2
    guard let upperYear = Int(upperYearSubstring) else {
        print("Couldn't find license year in \(content[licenseMatch.range])")
        continue
    }
    
    guard upperYear < currentYear else {
        // The license for this file is already up to date. No need to update it.
        continue
    }
    
    if licenseMatch.1 == nil {
        // The existing license comment only contains a single year. Add the new year after
        content.insert(contentsOf: "-\(currentYear)", at: upperYearSubstring.endIndex)
    } else {
        // The existing license comment contains both a start year and an end year. Update the second year.
        content.replaceSubrange(upperYearSubstring.startIndex ..< upperYearSubstring.endIndex, with: "\(currentYear)")
    }
    try content.write(to: file, atomically: true, encoding: .utf8)
}

// MARK: Modified files

private func findModifiedFiles(in repoURL: URL, strategy: DiffStrategy) throws -> [URL] {
    let diffCommand = Process()
    diffCommand.currentDirectoryURL = repoURL
    diffCommand.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    
    let comparisonFlag: String = switch strategy {
        case .stagedFiles:
            "--cached"
        case .comparingTo(let treeish):
            treeish
    }
    
    diffCommand.arguments = ["diff", "--name-only", comparisonFlag]

    let output = Pipe()
    diffCommand.standardOutput = output
    
    try diffCommand.run()
    
    guard let outputData = try output.fileHandleForReading.readToEnd(),
          let outputString = String(data: outputData, encoding: .utf8)
    else {
        return []
    }
    
    return outputString
        .components(separatedBy: .newlines)
        .compactMap { line in
            guard !line.isEmpty else { return nil }
            return repoURL.appendingPathComponent(line, isDirectory: false)
        }
}
