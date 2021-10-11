/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A type that can provide a collection of automatically generated task groups.
protocol AutomaticTaskGroupsProviding {
    
    /// The automatically created task groups this type provides.
    var automaticTaskGroups: [AutomaticTaskGroupSection] { get set }
}

/// A task group that is created automatically.
///
/// An automatic task group is not backed by markup in the same way that a ``TaskGroup`` is; it is
/// generated from a list of references and a given title.
struct AutomaticTaskGroupSection {
    enum PositionPreference {
        case top, bottom
    }
    
    let title: String
    var references: [ResolvedTopicReference]
    let renderPositionPreference: PositionPreference
}
