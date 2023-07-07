# My Article

This is the abstract of my article. Nice!

@Metadata {
    @PageImage(source: "plus", alt: "A plus icon.", purpose: icon)
    @PageImage(source: "figure1", alt: "An example figure.", purpose: card)
    @CustomMetadata(key: "country", value: "Belgium")
    @PageColor(yellow)
    @TitleHeading("Book-Like Content")
}

@Row(numberOfColumns: 8) {
    @Column(size: 3) {
        ![A great image](figure1)
    }
    
    @Column(size: 5) {
        This is a great image. With a lot of describing text next to it.
        
        And a second *paragraph*.
        
        @Row(kjk: test) {
            @Column {
                Hello
                
                Hi
            }
            
            @Column {
                There
            }
        }
    }
}

@Snippet(path: "Snippets/Snippets/MySnippet", slice: "foo")

@Small {
    Copyright (c) 2022 Apple Inc and the Swift Project authors. All Rights Reserved.
}

<!-- Copyright (c) 2022 Apple Inc and the Swift Project authors. All Rights Reserved. -->
