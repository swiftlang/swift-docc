/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit
import Markdown

final class ExternalPathHierarchyResolver {
    
    /// A hierarchy of path components used to resolve links in the documentation.
    private(set) var pathHierarchy: PathHierarchy!
    
    /// Map between resolved identifiers and resolved topic references.
    private(set) var resolvedReferenceMap = BidirectionalMap<ResolvedIdentifier, ResolvedTopicReference>()
    
    // TODO: Index from USR -> symbol (for symbol lookup)
    
    /// Attempts to resolve an unresolved reference.
    ///
    /// - Parameters:
    ///   - unresolvedReference: The unresolved reference to resolve.
    ///   - parent: The parent reference to resolve the unresolved reference relative to.
    ///   - isCurrentlyResolvingSymbolLink: Whether or not the documentation link is a symbol link.
    ///   - context: The documentation context to resolve the link in.
    /// - Returns: The result of resolving the reference.
    func resolve(_ unresolvedReference: UnresolvedTopicReference, fromSymbolLink isCurrentlyResolvingSymbolLink: Bool) -> TopicReferenceResolutionResult {
        do {
            let found = try pathHierarchy.find(path: Self.path(for: unresolvedReference), parent: nil, onlyFindSymbols: true)
            let foundReference = resolvedReferenceMap[found]!
            
            return .success(foundReference)
        } catch let error as PathHierarchy.Error {
            var originalReferenceString = unresolvedReference.path
            if let fragment = unresolvedReference.topicURL.components.fragment {
                originalReferenceString += "#" + fragment
            }
            
            return .failure(unresolvedReference, error.asTopicReferenceResolutionErrorInfo(originalReference: originalReferenceString) { node in node.name })
        } catch {
            fatalError("Only SymbolPathTree.Error errors are raised from the symbol link resolution code above.")
        }
    }
    
    private static func path(for unresolved: UnresolvedTopicReference) -> String {
        guard let fragment = unresolved.fragment else {
            return unresolved.path
        }
        return "\(unresolved.path)#\(urlReadableFragment(fragment))"
    }

    func entity(_ reference: ResolvedTopicReference) throws -> DocumentationNode {
        let id = resolvedReferenceMap[reference]!
        let node = pathHierarchy.lookup[id]!
        var symbol = node.symbol!
        return DocumentationNode(reference: reference, symbol: symbol, platformName: nil, moduleReference: reference, article: nil, engine: .init())
    }
    
    // MARK: Deserialization
    
    init(linkInformation fileRepresentation: SerializableLinkResolutionInformation) {
        self.pathHierarchy = PathHierarchy(fileRepresentation.pathHierarchy) { identifiers in
            // Read the serialized paths
            for (index, nodeData) in fileRepresentation.nodeData {
                let identifier = identifiers[index]
                let url = URL(string: nodeData.path!)! // The file currently always encodes a file
                self.resolvedReferenceMap[identifier] = ResolvedTopicReference(bundleIdentifier: fileRepresentation.bundleID, path: url.path, fragment: url.fragment, sourceLanguage: .swift)
            }
            
            // TODO: Compute the symbol paths dynamically to make the file smaller
        }
    }
    
    convenience init(linkFileURL: URL) throws {
        let linkInformation = try JSONDecoder().decode(SerializableLinkResolutionInformation.self, from: Data(contentsOf: linkFileURL))
        self.init(linkInformation: linkInformation)
    }
}
