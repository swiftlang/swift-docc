# Tabs

Showing how language tabs only render the primary language, but other tabs render all instances.

## Overview

@TabNavigator {
    @Tab("Objective-C") {
        ```objc
        I am an Objective-C code block
        ```
    }
    @Tab("Swift") {
        ```swift
        I am a Swift code block
        ```
    }
}

@TabNavigator {
    @Tab("Left") {
        Left text
    }
    @Tab("Right") {
        Right text
    }
}

<!-- Copyright (c) 2025 Apple Inc and the Swift Project authors. All Rights Reserved. -->
