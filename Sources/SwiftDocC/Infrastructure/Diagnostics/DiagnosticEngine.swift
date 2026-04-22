/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

private import Foundation

/// A type that collects and dispatches diagnostics during compilation.
public final class DiagnosticEngine {

    /// The queue on which diagnostics are dispatched to consumers.
    private let workQueue = DispatchQueue(label: "org.swift.docc.DiagnosticsEngine.work-queue")

    /// The diagnostic consumers currently subscribed to this engine.
    let consumers: Synchronized<[ObjectIdentifier: any DiagnosticConsumer]> = .init([:])
    /// The diagnostics encountered by this engine.
    let _diagnostics: Synchronized<[Diagnostic]> = .init([])
    /// A flag that indicates whether this engine has emitted a diagnostics with a severity level of ``DiagnosticSeverity/error``.
    var didEncounterError: Synchronized<Bool> = .init(false)

    /// Determines which diagnostics will be reported to consumers.
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
    
    /// Determines whether or not the diagnostics engine will emit a diagnostic with the given ID or group ID.
    package func willEmitDiagnostic(id: String, defaultSeverity: DiagnosticSeverity) -> Bool {
        if diagnosticIDsWithErrorSeverity.contains(id) {
            true // Errors are always emitted
        } else if diagnosticIDsWithWarningSeverity.contains(id) {
            // `--Wwarning` can be used to lower severity even when `--warnings-as-errors` is passed to is needs to be checked first
            filterLevel <= .warning
        } else if treatWarningsAsErrors {
            true // Errors are always emitted
        } else {
            filterLevel <= defaultSeverity
        }
    }

    /// Determines whether or not the diagnostics engine should report the given diagnostic, that the caller already passed to ``emit(_:)-(Diagnostic)``.
    private func shouldReport(_ diagnostic: Diagnostic) -> Bool {
        diagnostic.severity.rawValue <= filterLevel.rawValue
    }

    @available(*, deprecated, renamed: "diagnostics", message: "Use 'diagnostics' instead. This deprecated API will be removed after 6.5 is released.")
    public var problems: [Problem] {
        _diagnostics.sync { diagnostics in
            diagnostics.map { Problem(diagnostic: $0) }
        }
    }
    
    /// A convenience accessor for retrieving all of the diagnostics this engine currently holds.
    public var diagnostics: [Diagnostic] {
        _diagnostics.sync { $0 }
    }

    /// Creates a new diagnostic engine instance with no consumers.
    /// - Parameters:
    ///   - filterLevel: The lowest severity (inclusive) that the engine emits to its consumers.
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
        _diagnostics.sync {
            $0.removeAll()
        }
        didEncounterError.sync { $0 = false }
    }

    @available(*, deprecated, renamed: "emit(_:)", message: "Use 'emit(_:)' instead. This deprecated API will be removed after 6.5 is released.")
    public func emit(_ problem: Problem) {
        emit(problem.diagnostic)
    }
    
    /// Dispatches a diagnostic to all subscribed consumers.
    /// - Parameter diagnostic: The diagnostic to dispatch to this engine's currently subscribed consumers.
    public func emit(_ diagnostic: Diagnostic) {
        emit([diagnostic])
    }

    @available(*, deprecated, renamed: "emit(_:)", message: "Use 'emit(_:)' instead. This deprecated API will be removed after 6.5 is released.")
    public func emit(_ problems: [Problem]) {
        emit(problems.map(\.diagnostic))
    }
    
    /// Dispatches multiple diagnostics to consumers.
    /// - Parameter diagnostics: The sequence of diagnostics to dispatch to this engine's currently subscribed consumers.
    /// - Note: The diagnostics are dispatched asynchronously.
    public func emit(_ diagnostics: some Sequence<Diagnostic>) {
        let mappedProblems = diagnostics.map { diagnostic -> Diagnostic in
            var diagnostic = diagnostic
            updateDiagnosticSeverity(&diagnostic)
            return diagnostic
        }
        let filteredProblems = mappedProblems.filter(shouldReport)
        guard !filteredProblems.isEmpty else { return }

        if filteredProblems.containsError {
            didEncounterError.sync { $0 = true }
        }
        
        _diagnostics.sync {
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
        func _severity(identifier: String) -> DiagnosticSeverity? {
            if      diagnosticIDsWithErrorSeverity.contains(identifier)   { .error }
            else if diagnosticIDsWithWarningSeverity.contains(identifier) { .warning }
            else                                                          { nil }
        }
        
        if let severity = _severity(identifier: diagnostic.identifier) ?? diagnostic.groupIdentifier.flatMap(_severity) {
            diagnostic.severity = severity
        } else if treatWarningsAsErrors, diagnostic.severity == .warning {
            diagnostic.severity = .error
        }
    }
}
