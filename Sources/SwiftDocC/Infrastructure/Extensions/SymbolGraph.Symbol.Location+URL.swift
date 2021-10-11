/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

extension SymbolGraph.Symbol.Location {
    /// Returns the URL for a symbol graph location.
    func url() -> URL? {
        // FIXME: Use URL.init(dataRepresentation:relativeTo:) because the URI provided in the symbol graph file may be
        // an invalid URL (rdar://77335208). We should remove this workaround as part of rdar://77336041.
        URL(dataRepresentation: Data(uri.utf8), relativeTo: nil)
    }
}
