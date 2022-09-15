/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

extension RenderNode {
    /// The rendering style of the topics section.
    public enum TopicsSectionStyle: String, Codable {
        /// A list of the page's topics, including their full declaration and abstract.
        case list
        
        /// A grid of items based on the card image for each page.
        ///
        /// Includes each page’s title and card image but excludes their abstracts.
        case compactGrid
        
        /// A grid of items based on the card image for each page.
        ///
        /// Unlike ``compactGrid``, this style includes the abstract for each page.
        case detailedGrid
        
        /// Do not show child pages anywhere on the page.
        case hidden
    }
}
