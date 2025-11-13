/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type that collects and dispatches diagnostics during compilation.
public final class DiagnosticEngine {

    /// The queue on which diagnostics are dispatched to consumers.
    private let workQueue = DispatchQueue(label: "org.swift.docc.DiagnosticsEngine.work-queue")

    /// The diagnostic consumers currently subscribed to this engine.
    let consumers: Synchronized<[ObjectIdentifier: any DiagnosticConsumer]> = .init([:])
    /// The diagnostics encountered by this engine.
    let diagnostics: Synchronized<[Problem]> = .init([])
    /// A flag that indicates whether this engine has emitted a diagnostics with a severity level of ``DiagnosticSeverity/error``.
    var didEncounterError: Synchronized<Bool> = .init(false)

    /// Determines which problems will be emitted to consumers.
    /// 
    /// This filter level is inclusive, i.e. if a level of ``DiagnosticSeverity/information`` is specified,
    /// diagnostics with a severity up to and including `.information` will be printed.
    public var filterLevel: DiagnosticSeverity
    
    /// Returns a Boolean value indicating whether the engine contains a consumer that satisfies the given predicate.
    /// - Parameter predicate: A closure that takes one of the engine's consumers as its argument and returns a Boolean value that indicates whether the passed consumer represents a match.
    /// - Returns: `true` if the engine contains a consumer that satisfies predicate; otherwise, `false`.
    public func hasConsumer(matching predicate: (any DiagnosticConsumer) throws -> Bool) rethrows -> Bool {
        try consumers.sync {
            try $0.values.contains(where: predicate)
        }
    }
    
    /// Determines whether warnings will be treated as errors.
    private let treatWarningsAsErrors: Bool
    /// A list of diagnostic identifiers that are explicitly lowered to a "warning" severity.
    package var diagnosticIDsWithWarningSeverity: Set<String>
    /// A list of diagnostic identifiers that are explicitly raised to an "error" severity.
    package var diagnosticIDsWithErrorSeverity: Set<String>
    
    /// Determines which problems should be emitted.
    private func shouldEmit(_ problem: Problem) -> Bool {
        problem.diagnostic.severity.rawValue <= filterLevel.rawValue
    }

    /// A convenience accessor for retrieving all of the diagnostics this engine currently holds.
    public var problems: [Problem] {
        return diagnostics.sync { $0 }
    }

    /// Creates a new diagnostic engine instance with no consumers.
    /// - Parameters:
    ///   - filterLevel: The lowers severity (inclusive) that the engine emits to its consumers.
    ///   - treatWarningsAsErrors: A Boolean value indicating whether the engine raises the severity of warnings to "error" (unless `warningGroupsWithWarningSeverity` explicitly lowers the severity of that diagnostic to a warning)
    ///   - diagnosticIDsWithWarningSeverity: A list of diagnostic identifiers that are explicitly lowered to a "warning" severity.
    ///   - diagnosticIDsWithErrorSeverity: A list of diagnostic identifiers that are explicitly raised to an "error" severity.
    public init(
        filterLevel: DiagnosticSeverity = .warning,
        treatWarningsAsErrors: Bool = false,
        diagnosticIDsWithWarningSeverity: Set<String> = [],
        diagnosticIDsWithErrorSeverity: Set<String> = []
    ) {
        self.filterLevel = filterLevel
        self.treatWarningsAsErrors = treatWarningsAsErrors
        self.diagnosticIDsWithWarningSeverity = diagnosticIDsWithWarningSeverity
        self.diagnosticIDsWithErrorSeverity   = diagnosticIDsWithErrorSeverity
    }

    /// Removes all of the encountered diagnostics from this engine.
    public func clearDiagnostics() {
        diagnostics.sync {
            $0.removeAll()
        }
        didEncounterError.sync { $0 = false }
    }

    /// Dispatches a diagnostic to all subscribed consumers.
    /// - Parameter problem: The diagnostic to dispatch to this engine's currently subscribed consumers.
    public func emit(_ problem: Problem) {
        emit([problem])
    }

    /// Dispatches multiple diagnostics to consumers.
    /// - Parameter problems: The array of diagnostics to dispatch to this engine's currently subscribed consumers.
    /// > Note: Diagnostics are dispatched asynchronously.
    public func emit(_ problems: [Problem]) {
        let mappedProblems = problems.map { problem -> Problem in
            var problem = problem
            updateDiagnosticSeverity(&problem.diagnostic)
            return problem
        }
        let filteredProblems = mappedProblems.filter(shouldEmit)
        guard !filteredProblems.isEmpty else { return }

        if filteredProblems.containsErrors {
            didEncounterError.sync { $0 = true }
        }
        
        diagnostics.sync {
            $0.append(contentsOf: filteredProblems)
        }

        workQueue.async { [weak self] in
            // If the engine isn't around then return early
            guard let self else { return }
            for consumer in self.consumers.sync({ $0.values }) {
                consumer.receive(filteredProblems)
            }
        }
    }
    
    public func flush() {
        workQueue.sync {
            for consumer in self.consumers.sync({ $0.values }) {
                try? consumer.flush()
            }
        }
    }

    /// Subscribes a given consumer to the diagnostics emitted by this engine.
    /// - Parameter consumer: The consumer to subscribe to this engine.
    public func add(_ consumer: any DiagnosticConsumer) {
        consumers.sync {
            $0[ObjectIdentifier(consumer)] = consumer
        }
    }

    /// Unsubscribes a given consumer
    /// - Parameter consumer: The consumer to remove from this engine.
    public func remove(_ consumer: any DiagnosticConsumer) {
        consumers.sync {
            $0.removeValue(forKey: ObjectIdentifier(consumer))
        }
    }
    
    private func updateDiagnosticSeverity(_ diagnostic: inout Diagnostic) {
        let identifier = diagnostic.identifier
        if diagnosticIDsWithErrorSeverity.contains(identifier) {
            diagnostic.severity = .error
        } else if diagnosticIDsWithWarningSeverity.contains(identifier) {
            diagnostic.severity = .warning
        } else if treatWarningsAsErrors, diagnostic.severity == .warning {
            diagnostic.severity = .error
        }
    }
}
