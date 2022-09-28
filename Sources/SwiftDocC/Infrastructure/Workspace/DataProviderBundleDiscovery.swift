/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension DocumentationWorkspaceDataProvider where Self: FileSystemProvider {
    public func bundles(options: BundleDiscoveryOptions) throws -> [DocumentationBundle] {
        return try bundlesInTree(fileSystem, options: options)
    }
    
    /// Recursively traverses the file system, searching for documentation bundles.
    ///
    /// - Parameters:
    ///   - root: The directory in which to search for documentation bundles.
    ///   - options: Configuration that controls how the provider discovers documentation bundles.
    /// - Throws: A ``WorkspaceError`` if one of the found documentation bundle directories is an invalid documentation bundle.
    /// - Returns: A list of all the bundles that the provider discovered in the file system.
    private func bundlesInTree(_ root: FSNode, options: BundleDiscoveryOptions) throws -> [DocumentationBundle] {
        var bundles: [DocumentationBundle] = []
        
        guard case .directory(let rootDirectory) = root else {
            preconditionFailure("Expected directory object at path '\(root.url.absoluteString)'.")
        }
        
        if DocumentationBundleFileTypes.isDocumentationBundle(rootDirectory.url) {
            bundles.append(try createBundle(rootDirectory, rootDirectory.children, options: options))
        } else {
            // Recursively descend when the current root directory isn't a documentation bundle.
            for child in rootDirectory.children {
                if case .directory = child {
                    try bundles.append(contentsOf: bundlesInTree(child, options: options))
                }
            }
        }
        
        return bundles
    }
    
    /// Creates a documentation bundle from the content in a given documentation bundle directory.
    /// - Parameters:
    ///   - directory: The documentation bundle directory.
    ///   - bundleChildren: The top-level files and directories in the documentation bundle directory.
    ///   - options: Configuration that controls how the provider discovers documentation bundles.
    /// - Throws: A ``WorkspaceError`` if the content is an invalid documentation bundle or
    ///           a ``DocumentationBundle/PropertyListError`` error if the bundle's Info.plist file is invalid.
    /// - Returns: The new documentation bundle.
    private func createBundle(_ directory: FSNode.Directory, _ bundleChildren: [FSNode], options: BundleDiscoveryOptions) throws -> DocumentationBundle {
        let infoPlistData: Data?
        if let infoPlistRef = findInfoPlist(bundleChildren) {
            infoPlistData = try contentsOfURL(infoPlistRef.url)
        } else {
            infoPlistData = nil
        }
        let info = try DocumentationBundle.Info(
            from: infoPlistData,
            bundleDiscoveryOptions: options,
            derivedDisplayName: directory.url.deletingPathExtension().lastPathComponent
        )
        
        let markupFiles = findMarkupFiles(bundleChildren, recursive: true).map { $0.url }
        let miscResources = findNonMarkupFiles(bundleChildren, recursive: true).map { $0.url }
        let symbolGraphFiles = findSymbolGraphFiles(bundleChildren, recursive: true).map { $0.url } + options.additionalSymbolGraphFiles

        let customHeader = findCustomHeader(bundleChildren)?.url
        let customFooter = findCustomFooter(bundleChildren)?.url
        let themeSettings = findThemeSettings(bundleChildren)?.url
        
        return DocumentationBundle(
            info: info,
            symbolGraphURLs: symbolGraphFiles,
            markupURLs: markupFiles,
            miscResourceURLs: miscResources,
            customHeader: customHeader,
            customFooter: customFooter,
            themeSettings: themeSettings
        )
    }
    
    /// Performs a shallow search for the first Info.plist file in the given list of files and directories.
    /// - Parameter bundleChildren: The list of files and directories to check.
    /// - Returns: The first Info.plist file, or `nil` if none of the files is an Info.plist file.
    private func findInfoPlist(_ bundleChildren: [FSNode]) -> FSNode.File? {
        return bundleChildren.firstFile { DocumentationBundleFileTypes.isInfoPlistFile($0.url) }
    }
    
    /// Finds all the symbol-graph files in the given list of files and directories.
    /// - Parameters:
    ///   - bundleChildren: The list of files and directories to check.
    ///   - recursive: If `true`, this function will recursively check the files of all directories in the array. If `false`, it will ignore all directories.
    /// - Returns: A list of all the symbol-graph files.
    private func findSymbolGraphFiles(_ bundleChildren: [FSNode], recursive: Bool) -> [FSNode.File] {
        return bundleChildren.files(recursive: recursive) { DocumentationBundleFileTypes.isSymbolGraphFile($0.url) }
    }
    
    /// Finds all the markup files in the given list of files and directories.
    /// - Parameters:
    ///   - bundleChildren: The list of files and directories to check.
    ///   - recursive: If `true`, this function will recursively check the files of all directories in the array. If `false`, it will ignore all directories.
    /// - Returns: A list of all the markup files.
    private func findMarkupFiles(_ bundleChildren: [FSNode], recursive: Bool) -> [FSNode.File] {
        return bundleChildren.files(recursive: recursive) { DocumentationBundleFileTypes.isMarkupFile($0.url) }
    }
    
    /// Finds all the non-markup files in the given list of files and directories.
    /// - Parameters:
    ///   - bundleChildren: The list of files and directories to check.
    ///   - recursive: If `true`, this function will recursively check the files of all directories in the array. If `false`, it will ignore all directories.
    /// - Returns: A list of all the non-markup files.
    private func findNonMarkupFiles(_ bundleChildren: [FSNode], recursive: Bool) -> [FSNode.File] {
        return bundleChildren.files(recursive: recursive) { !DocumentationBundleFileTypes.isMarkupFile($0.url) }
    }

    private func findCustomHeader(_ bundleChildren: [FSNode]) -> FSNode.File? {
        return bundleChildren.firstFile { DocumentationBundleFileTypes.isCustomHeader($0.url) }
    }

    private func findCustomFooter(_ bundleChildren: [FSNode]) -> FSNode.File? {
        return bundleChildren.firstFile { DocumentationBundleFileTypes.isCustomFooter($0.url) }
    }

    private func findThemeSettings(_ bundleChildren: [FSNode]) -> FSNode.File? {
        return bundleChildren.firstFile { DocumentationBundleFileTypes.isThemeSettingsFile($0.url) }
    }
}

fileprivate extension Array where Element == FSNode {
    /// Returns the first file that matches a given predicate.
    /// - Parameter predicate: A closure that takes a file as its argument and returns a Boolean value indicating whether the file should be returned from this function.
    /// - Throws: Any error that the predicate closure raises.
    /// - Returns: The first file that matches the predicate.
    func firstFile(where predicate: (FSNode.File) throws -> Bool) rethrows -> FSNode.File? {
        for case .file(let file) in self where try predicate(file) {
            return file
        }
        return nil
    }
    
    /// Returns all the files that match s given predicate.
    /// - Parameters:
    ///   - recursive: If `true`, this function will recursively check the files of all directories in the array. If `false`, it will ignore all directories in the array.
    ///   - predicate: A closure that takes a file as its argument and returns a Boolean value indicating whether the file should be included in the returned array.
    /// - Throws: Any error that the predicate closure raises.
    /// - Returns: The first file that matches the predicate.
    func files(recursive: Bool, where predicate: (FSNode.File) throws -> Bool) rethrows -> [FSNode.File] {
        var matches: [FSNode.File] = []
        for node in self {
            switch node {
            case .directory(let directory):
                guard recursive else { break }
                try matches.append(contentsOf: directory.children.files(recursive: true, where: predicate))
            case .file(let file) where try predicate(file):
                matches.append(file)
            case .file:
                break
            }
        }
        
        return matches
    }
}

/// An issue discovering a bundle in a workspace.
enum WorkspaceError: DescribedError {
    /// The bundle was missing an Info.plist file.
    case missingInfoPlist(url: URL)
    /// The root element of the Info.plist file was an array rather than a dictionary.
    case notADictionaryAtRoot(url: URL)
    
    /// A plain-text representation of the error.
    var errorDescription: String {
        switch self {
        case .missingInfoPlist(let url):
            return "A bundle was found in the workspace at '\(url)' but it was missing an Info.plist."
        case .notADictionaryAtRoot(let url):
            return "A bundle was found in the workspace but its Info.plist at '\(url)' was not structured correctly: it contained a root array rather than a root dictionary."
        }
    }
}
