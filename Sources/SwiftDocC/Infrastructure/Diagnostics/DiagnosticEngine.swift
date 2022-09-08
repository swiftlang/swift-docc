/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
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
    let consumers: Synchronized<[ObjectIdentifier: DiagnosticConsumer]> = .init([:])
    /// The diagnostics encountered by this engine.
    let diagnostics: Synchronized<[Problem]> = .init([])
    /// A flag that indicates whether this engine has emitted a diagnostics with a severity level of ``DiagnosticSeverity/error``.
    var didEncounterError: Synchronized<Bool> = .init(false)

    /// Determines which problems will be emitted to consumers.
    /// 
    /// This filter level is inclusive, i.e. if a level of ``DiagnosticSeverity/information`` is specified,
    /// diagnostics with a severity up to and including `.information` will be printed.
    public var filterLevel: DiagnosticSeverity {
        didSet {
            self.filter = { $0.diagnostic.severity.rawValue <= self.filterLevel.rawValue }
        }
    }
    
    /// Determines whether warnings will be treated as errors.
    private let treatWarningsAsErrors: Bool

    /// Determines which problems should be emitted.
    private var filter: (Problem) -> Bool

    /// A convenience accessor for retrieving all of the diagnostics this engine currently holds.
    public var problems: [Problem] {
        return diagnostics.sync { $0 }
    }

    /// Creates a new diagnostic engine instance with no consumers.
    public init(filterLevel: DiagnosticSeverity = .warning, treatWarningsAsErrors: Bool = false) {
        self.filterLevel = filterLevel
        self.treatWarningsAsErrors = treatWarningsAsErrors
        self.filter = { $0.diagnostic.severity.rawValue <= filterLevel.rawValue }
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
            if treatWarningsAsErrors, problem.diagnostic.severity == .warning {
                problem.diagnostic.severity = .error
            }
            return problem
        }
        let filteredProblems = mappedProblems.filter(filter)
        guard !filteredProblems.isEmpty else { return }

        if filteredProblems.containsErrors {
            didEncounterError.sync { $0 = true }
        }
        
        diagnostics.sync {
            $0.append(contentsOf: filteredProblems)
        }

        workQueue.async { [weak self] in
            // If the engine isn't around then return early
            guard let self = self else { return }
            for consumer in self.consumers.sync({ $0.values }) {
                consumer.receive(filteredProblems)
            }
        }
    }

    /// Subscribes a given consumer to the diagnostics emitted by this engine.
    /// - Parameter consumer: The consumer to subscribe to this engine.
    public func add(_ consumer: DiagnosticConsumer) {
        consumers.sync {
            $0[ObjectIdentifier(consumer)] = consumer
        }
    }

    /// Unsubscribes a given consumer
    /// - Parameter consumer: The consumer to remove from this engine.
    public func remove(_ consumer: DiagnosticConsumer) {
        consumers.sync {
            $0.removeValue(forKey: ObjectIdentifier(consumer))
        }
    }
}
