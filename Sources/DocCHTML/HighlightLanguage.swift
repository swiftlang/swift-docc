/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A known language that DocC supports syntax highlighting for in code blocks
package enum HighlightLanguage: String {
    case bash
    case c
    case cpp
    case css
    case diff
    case http
    case java
    case javascript
    case json
    case llvm
    case markdown
    case objectiveC = "objc"
    case perl
    case php
    case python
    case ruby
    case scss
    case shell
    case swift
    case typescript
    case xml
    case yaml
    
    init?(name: String) {
        // The list of languages that DocC supports and their aliases is documented here: https://www.swift.org/documentation/docc/formatting-your-documentation-content#Add-Code-Listings
        switch name.lowercased() {
            case "bash", "sh", "zsh":
                self = .bash
            case "c", "h":
                self = .c
            case "cpp", "cc", "c++", "h++", "hpp", "hh", "hxx", "cxx":
                self = .cpp
            case "css":
                self = .css
            case "diff", "patch":
                self = .diff
            case "http", "https":
                self = .http
            case "java", "jsp":
                self = .java
            case "javascript", "js", "jsx", "mjs", "cjs":
                self = .javascript
            case "json":
                self = .json
            case "llvm":
                self = .llvm
            case "markdown", "md", "mkdown", "mkd":
                self = .markdown
            case "objective-c", "mm", "objc", "obj-c", "objectivec":
                self = .objectiveC
            case "perl", "pl", "pm":
                self = .perl
            case "php":
                self = .php
            case "python", "py", "gyp", "ipython":
                self = .python
            case "ruby", "rb", "gemspec", "podspec", "thor", "irb":
                self = .ruby
            case "scss":
                self = .scss
            case "shell", "console", "shellsession":
                self = .shell
            case "swift":
                self = .swift
            case "typescript", "ts", "tsx", "mts", "cts":
                self = .typescript
            case "xml", "html", "xhtml", "rss", "atom", "xjb", "xsd", "xsl", "plist", "wsf", "svg":
                self = .xml
            case "yaml", "yml":
                self = .yaml
            default:
                return nil
        }
    }
}
