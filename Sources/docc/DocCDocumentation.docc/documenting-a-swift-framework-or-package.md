# Documenting a Swift Framework or Package

Create rich and engaging documentation from your in-source comments, and add a 
documentation catalog to your code base to provide additional content.

## Overview

DocC, or _Documentation Compiler_, makes it easy for you to produce 
documentation for your Swift frameworks and packages. The compiler builds your 
documentation by combining comments that you write in-source with extension files, 
articles, and other resources, 
allowing you to create rich and engaging documentation for developers.

With DocC, you provide a combination of reference and conceptual content, and 
connect it together using powerful organization and linking capabilities. Because you write 
documentation directly in source, you can use the tools you're already familiar 
with, such as Git, to track changes you make.

### Build Simple Documentation from Your Source Comments

For DocC to compile your documentation, the Swift compiler first builds your Swift framework 
or package, and stores additional information about its public APIs alongside 
the compiled artifacts. It then consumes that information and compiles your 
documentation into a DocC Archive. This process repeats for every Swift 
framework or package that your target depends on.

![A diagram showing how the Swift compiler turns code into a Swift framework and supplies information about the framework's public APIs to the documentation compiler, which generates a DocC Archive using that information.](docc-compilation-default)

To build documentation for your Swift framework or package, use the DocC command-line interface in preview mode and specify a location. On macOS, DocC monitors the files in the location and recompiles when you make changes. On other platforms, you need to quit and restart DocC to recompile the documentation.

![A screenshot showing the Sloth structure documentation in its rendered form.](1_sloth)

DocC uses the comments that you write in your source code as the content for the 
documentation pages it generates. At a minimum, add basic documentation 
comments to the framework's public symbols so that DocC can use this information as the symbols'
single-sentence abstracts or summaries. You can also add thorough 
documentation comments to provide further detail, including information about 
parameters, return values, and errors. For more information, see 
<doc:writing-symbol-documentation-in-your-source-files>.

### Create Documentation for a Swift Package

By default, DocC compiles only your in-source symbol documentation and then 
groups those symbols together by their kind, such as protocols, classes, 
enumerations, and so forth. When you want to provide additional content or 
customize the organization of your framework's symbols, use a documentation 
catalog.

DocC combines the public API information from the Swift compiler with the 
contents of the documentation catalog to generate a richer DocC Archive.

![A diagram showing how the Swift compiler turns code into a Swift framework and supplies information about the framework's public APIs to the documentation compiler, which combines that with a documentation catalog to generate a rich DocC Archive.](docc-compilation-catalog)

Use a documentation catalog when you want to include:

* A landing page that introduces your framework and arranges its top-level 
symbols, as well as extension files that provide custom organization for your 
symbols' properties and methods. For more information, see 
<doc:adding-structure-to-your-documentation-pages>.
* Extension files that supplement your in-source comments, and articles that 
provide supporting conceptual content. For more information, see 
<doc:adding-supplemental-content-to-a-documentation-catalog>.
* Tutorials that allow you to teach developers your framework's APIs through 
step-by-step, interactive content. For more information, see 
<doc:building-an-interactive-tutorial>.
* Resource files to use in your documentation, such as images and videos.

> Important: To use a documentation catalog in a Swift package, make sure the 
manifest's Swift tools version is set to `5.5` or later. 

To use DocC to create documentation for an existing example package, follow these steps from the command line:

1. Check out the DeckOfPlayingCards Swift package.
    ```
    git clone https://github.com/apple/example-package-deckofplayingcards.git
    ```

2. Run the following commands to create a folder for the documentation catalog.

    ```shell
    cd example-package-deckofplayingcards
    mkdir DeckOfPlayingCards.docc
    ```

2. Use a text editor to create a file named `DeckOfPlayingCards.md` under the `DeckOfPlayingCards.docc` folder.

    ```
    # Deck Of Playing Cards
    
    Add the ability to use a deck of cards in your app.
    ```

3. Run the following command to compile the package.

    ```shell 
    swift build --target DeckOfPlayingCards -Xswiftc -emit-symbol-graph -Xswiftc -emit-symbol-graph-dir -Xswiftc .build
    ```
 
    The `-emit-symbol-graph` option tells the Swift compiler to emit the symbol graph that DocC ingests to create documentation from source code.

4. Launch DocC in preview mode.

    ```shell
    docc preview DeckOfPlayingCards.docc --fallback-display-name DeckOfPlayingCards --fallback-bundle-identifier com.example.DeckOfPlayingCards --fallback-bundle-version 1 --additional-symbol-graph-dir .build
    ```

DocC advertises a URL that you use to preview the documentation. In preview mode on macOS, DocC monitors the documentation catalog for changes and automatically updates its preview. On other platforms, you need to quit and restart DocC to recompile the documentation. 

## See Also

- <doc:writing-symbol-documentation-in-your-source-files>

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
