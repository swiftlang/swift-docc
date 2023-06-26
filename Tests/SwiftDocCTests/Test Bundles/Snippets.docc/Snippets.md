# `Snippets`

This article tests the inclusion of snippets and snippet slices.

This is a snippet.

@Snippet(path: "Snippets/Snippets/MySnippet")

This is a slice of the above snippet, called "foo".

@Snippet(path: "Snippets/Snippets/MySnippet", slice: "foo")

This is a snippet nested inside a tab navigator.

@TabNavigator {
    @Tab("hi") {
        @Row {
            @Column {
                Hello!
            }

            @Column {
                Hello there!
            }
        }

        Hello there.
    }

    @Tab("hey") {
        Hey there.

        @Small {
            Hey but small.
        }

        @Snippet(path: "Snippets/Snippets/MySnippet", slice: "middle") {}
    }
}


<!-- Copyright (c) 2023 Apple Inc and the Swift Project authors. All Rights Reserved. -->
