/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A collection of functions to check if a file is one of the documentation bundle files types.
public enum DocumentationBundleFileTypes {
    
    static let referenceFileExtension = "md"
    /// Checks if a file is a reference documentation file.
    /// - Parameter url: The file to check.
    /// - Returns: Whether or not the file at `url` is a reference documentation file.
    public static func isReferenceDocumentationFile(_ url: URL) -> Bool {
        return url.pathExtension.lowercased() == referenceFileExtension
    }
    
    private static let tutorialFileExtension = "tutorial"
    /// Checks if a file is a tutorial file.
    /// - Parameter url: The file to check.
    /// - Returns: Whether or not the file at `url` is a tutorial file.
    public static func isTutorialFile(_ url: URL) -> Bool {
        return url.pathExtension.lowercased() == tutorialFileExtension
    }
    
    private static let markupFileExtensions: Set = [referenceFileExtension, tutorialFileExtension]
    /// Checks if a file is a markup file; that is, either a reference documentation file or a tutorial file.
    /// - Parameter url: The file to check.
    /// - Returns: Whether or not the file at `url` is a markup file.
    public static func isMarkupFile(_ url: URL) -> Bool {
        return markupFileExtensions.contains(url.pathExtension.lowercased())
    }
    
    private static let symbolGraphFileExtension = ".symbols.json"
    /// Checks if a file is a symbol graph file.
    /// - Parameter url: The file to check.
    /// - Returns: Whether or not the file at `url` is a symbol graph file.
    public static func isSymbolGraphFile(_ url: URL) -> Bool {
        return url.lastPathComponent.hasSuffix(symbolGraphFileExtension)
    }
    
    private static let documentationBundleFileExtension = "docc"
    /// Checks if a folder is a documentation bundle.
    /// - Parameter url: The folder to check.
    /// - Returns: Whether or not the folder at `url` is a documentation bundle.
    public static func isDocumentationBundle(_ url: URL) -> Bool {
        return url.pathExtension.lowercased() == documentationBundleFileExtension
    }
    
    private static let infoPlistFileName = "Info.plist"
    /// Checks if a file is an Info.plist file.
    /// - Parameter url: The file to check.
    /// - Returns: Whether or not the file at `url` is an Info.plist file.
    public static func isInfoPlistFile(_ url: URL) -> Bool {
        return url.lastPathComponent == infoPlistFileName
    }

    private static let customHeaderFileName = "header.html"
    /// Checks if a file is a custom header.
    /// - Parameter url: The file to check.
    /// - Returns: Whether or not the file at `url` is a custom header.
    public static func isCustomHeader(_ url: URL) -> Bool {
        return url.lastPathComponent == customHeaderFileName
    }

    private static let customFooterFileName = "footer.html"
    /// Checks if a file is a custom footer.
    /// - Parameter url: The file to check.
    /// - Returns: Whether or not the file at `url` is a custom footer.
    public static func isCustomFooter(_ url: URL) -> Bool {
        return url.lastPathComponent == customFooterFileName
    }

    private static let themeSettingsFileName = "theme-settings.json"
    /// Checks if a file is `theme-settings.json`.
    /// - Parameter url: The file to check.
    /// - Returns: Whether or not the file at `url` is `theme-settings.json`.
    public static func isThemeSettingsFile(_ url: URL) -> Bool {
        return url.lastPathComponent == themeSettingsFileName
    }
}
