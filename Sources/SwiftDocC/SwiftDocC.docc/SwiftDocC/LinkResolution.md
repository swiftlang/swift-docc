# Linking Between Documentation

Connect documentation pages with documentation links.

## Overview

DocC uses links to connect documentation pages to each other. 

Some links are automatic or created by tools. For example symbol declarations in symbol graph files use `typeIdentifier` tokens with `preciseIdentifier` values to link to other types that are referenced in the declaration and symbol graph relationships are used to construct a default documentation hierarchy. These links use unique and exact identifiers to reference other symbols. 

All other documentation links are written in the documentation content; in symbol documentation comments or in markdown or tutorial files. These "authored" documentation links are used to associate documentation extension files with symbols, form links in the documentation content itself, customize the documentation hierarchy, and organize tutorials. 

Developers can write two types of documentation links:
 - Symbol links; a symbol path surrounded by two grave accents on each side: ` ``MyClass/myProperty`` `
 - General documentation links; markdown links with a "doc" scheme: `<doc:MyArticle>` or `<doc:MyClass/myProperty>`.

As the name suggest, symbol links can only link to symbols. General documentation links can link to all types of documentation content: symbols, articles, and tutorials. General documentation links can use the documentation catalogs identifier as the "hostname" of the documentation URI but links within the same catalog only need the path component of the URI. Optionally URI fragments can be used to reference specific headings/sections on a documentation page.

```
doc://com.example/path/to/documentation/page#optional-heading
    ╰─────┬─────╯╰────────────┬────────────╯╰───────┬───────╯
      bundle ID     path in docs hierarchy    heading name 
```

## Resolving a Documentation Link

To make authored documentation links easier to write and easier to read in plain text format all authored documentation links are relative links. The symbol links in documentation extension headers are written relative to the scope of modules. All other authored documentation links are written relative to the page where the link is written. 

These relative documentation links can specify path components from higher up in the documentation hierarchy to reference container symbols or container pages.

### Handling Ambiguous Links

It's possible for collisions to occur in documentation links (symbol links or otherwise) where more than one page are represented by the same path. A common cause for documentation link collisions are function overloads (functions with the same name but different arguments or different return values). It's also possible to have documentation link collisions in conceptual content if an article file name is the same as a tutorial file name (excluding the file extension in both cases).

If DocC encounters an ambiguous documentation link that could either resolve to an article (using its file name), a tutorial (using its file name), or a symbol (using the symbol's name in a lone path component) then DocC will prefer the article result over other two results and the tutorial result over the symbol result.

If DocC encounters an ambiguous link to a symbol (either written as a symbol link or as a general documentation link) then DocC will require that additional information is added to the link to disambiguate between the different symbol results. If the symbols are different kinds (for example a class, an enum, and a property) then DocC will disambiguate the links by appending the kind ID to the ambiguous path component. 

```
/path/to/Something-class
/path/to/Something-enum
/path/to/Something-property
```


If two or more symbol results have the same kind, then that information doesn't distinguish the results. In this case DocC will use a hashed version of each symbols's unique and exact identifiers to disambiguate the results. 

```
/path/to/someFunction-abc123
/path/to/someFunction-def456
```

Links with added disambiguation information is both harder to read and harder to write so DocC aims to require as little disambiguation as possible. 

### Handling Type Aliases

Members defined on a `typealias` cannot be linked to using the type alias' name, but must use the original name instead. Only the declaration of the `typealias` itself uses the alias' name.

```swift
struct A {}

/// This is referred to as ``B``
typealias B = A

extension B {
    /// This can only be referred to as ``A/foo()``, not `B/foo()`
    func foo() { }
}
```

## Resolving Links Outside the Documentation Catalog

If a ``DocumentationContext`` is configured with one or more ``DocumentationContext/externalReferenceResolvers`` it is capable of resolving links general documentation links via that ``ExternalReferenceResolver``. External documentation links need to be written with a bundle ID in the URI to identify which external resolver should handle the request.

<!-- Copyright (c) 2022 Apple Inc and the Swift Project authors. All Rights Reserved. -->
