# Specifying Availability Information

Show readers which platforms and versions support your API, and which versions deprecate it.

## Overview

When readers evaluate your API, they need to know whether it works on the platforms and versions their own projects support.
DocC can list those platforms on each symbol page, with the version that introduced the symbol and, when it applies, the version that deprecated it.
The page shows each platform as a version range, such as "iOS 16.0+" or "iOS 16.0–18.0", and adds a Deprecated or Beta badge where it applies.

DocC combines availability information from four inputs:

- term Default availability: A baseline in your documentation catalog's `Info.plist` file that applies to every symbol in your module.
- term In-source attributes: The availability annotations in your source code, such as `@available` in Swift.
- term The `@Available` directive: Availability that you write in a documentation extension file, a documentation comment, or an article.
- term The `--platform` option: A build option that describes the current release of each platform, including whether it's in beta.

Use in-source attributes whenever you can, so that your documentation matches what the compiler enforces.
Add the other inputs to fill in what your source code doesn't say.

### Specify Default Availability for Your Module

Most symbols in a module share the same minimum platform versions.
Instead of repeating them in every attribute, add a `CDAppleDefaultAvailability` key to your documentation catalog's `Info.plist` file.
Its value is an array with one dictionary per platform.
Each dictionary has a `name` and, optionally, either a `version` or an `unavailable` key:

```xml
<key>CDAppleDefaultAvailability</key>
<array>
    <dict>
        <key>name</key>
        <string>iOS</string>
        <key>version</key>
        <string>16.0</string>
    </dict>
    <dict>
        <key>name</key>
        <string>macOS</string>
        <key>version</key>
        <string>13.0</string>
    </dict>
    <dict>
        <key>name</key>
        <string>watchOS</string>
        <key>unavailable</key>
        <true/>
    </dict>
</array>
```

The `version` value needs two or three components, such as `16.0` or `16.0.1`.
If you omit the `version`, DocC lists the platform without a version.
To keep a platform off every page, set `unavailable` to `true` instead of providing a version.
You can also list a platform name that DocC doesn't know, such as the name of your package, and DocC shows it after the known platforms.

> Earlier Versions:
> DocC still reads a dictionary that groups the array of platforms under the module name, and it warns about that format.
> Support ends after Swift-DocC 6.6.

DocC applies these defaults to every symbol in your module and to your module's landing page.
An in-source attribute for a platform replaces the default version for that platform on that symbol's page.
If the attribute doesn't specify an introduced version, for example because it only deprecates the symbol, DocC keeps the default introduced version.

> Note: Articles don't display your module's default availability.
> To show availability on an article, use the ``Available`` directive.

### Annotate Availability in Your Source Code

When you annotate a declaration with an availability attribute, the compiler includes the information in the symbol graph that DocC reads.
For each platform the attribute names, DocC uses that information on the symbol's page instead of your module's default availability.
A platform the attribute doesn't name keeps the default. DocC copies iOS availability to iPadOS and Mac Catalyst when those platforms have no availability of their own.
The pages below use the module default from the example above, iOS 16.0 and macOS 13.0.
The following declarations show introduced versions, and a deprecation on one platform. They also show a symbol that is unavailable on a platform, and a symbol that is obsoleted on a platform:

```swift
@available(iOS 17.0, macOS 14.0, *)
public func sleep() { }

@available(iOS, introduced: 16.0, deprecated: 18.0)
public func climbQuietly() { }

@available(macOS, unavailable)
public func swim() { }

@available(iOS, introduced: 16.0, obsoleted: 17.0)
public func oldClimb() { }
```

The `sleep()` page lists "iOS 17.0+", "iPadOS 17.0+", and "macOS 14.0+".
The `climbQuietly()` page lists "iOS 16.0–18.0" and "iPadOS 16.0–18.0", each with a Deprecated badge, and "macOS 13.0+" from the module default.
DocC leaves a platform off the page when the attribute marks the symbol as unavailable or obsoleted on that platform.
The `swim()` page lists "iOS 16.0+" and "iPadOS 16.0+" from the module default, and leaves macOS off the page.
The `oldClimb()` page lists "macOS 13.0+" from the module default, and leaves iOS and iPadOS off the page.

An attribute can deprecate a symbol without naming a platform, for example `@available(*, deprecated)`.
In that case, DocC marks the whole page as deprecated, even when none of the listed platforms have a deprecated version.
If the attribute includes a `message`, DocC displays the message as the page's deprecation summary, unless you provide your own text with a ``DeprecationSummary`` directive.

DocC also recognizes availability domains other than operating systems.
For example, `@available(swift, introduced: 5.9)` appears as "Swift 5.9+" on the page.

### Add Availability with the Available Directive

If your source language doesn't have availability annotations, or if a page needs availability that the source code doesn't provide, add an ``Available`` directive inside the page's ``Metadata`` directive.
Each directive describes one platform, with an `introduced` version and an optional `deprecated` version:

```markdown
# Article with a Directive

An article that declares its availability with directives.

@Metadata {
    @Available(iOS, introduced: "17.0")
    @Available(macOS, introduced: "14.0", deprecated: "15.0")
}
```

You can add the directive to a documentation extension file, a symbol's documentation comment, an article, or your module's landing page.
DocC matches the platform names iOS, iPadOS, Mac Catalyst, macOS, tvOS, visionOS, and watchOS regardless of capitalization.
It displays other names as you write them.
Surround a name that contains spaces or punctuation with quotation marks, for example `@Available("Sloth Playground", introduced: "2.1")`.

> Important: When a symbol's page has any `@Available` directive, DocC ignores all of that symbol's in-source availability attributes and starts from your module's default availability instead.
> If you add a directive for one platform, add directives for the other platforms that the symbol's attributes describe.

A deprecated version in a directive adds a Deprecated badge to that platform on the page, but links to the page from other pages don't show a Deprecated badge.
To describe why you deprecated the API and what to use instead, add a ``DeprecationSummary`` directive.

### Mark Platform Releases as Beta

When you document an API for a platform release that's still in beta, pass the `--platform` option to `docc convert` once for each platform in beta:

```shell
docc convert SlothCreator.docc \
    --platform "name=iOS,version=18.0,beta=true" \
    --platform "name=macOS,version=15.0,beta=true"
```

Each value contains the platform's `name`, its current `version` with two or three components, and an optional `beta` component that's `true` or `false`.
A platform's entry gets a Beta badge when the platform is in beta and the API was introduced in that version or later.
If you mark iOS as in beta, DocC also treats iPadOS and Mac Catalyst as in beta, unless you pass separate values for them.

DocC marks a symbol page as beta only when every platform it lists is in beta, and only when the introduced versions come from in-source attributes.
For example, with the command above, a symbol annotated `@available(iOS 18.0, macOS 15.0, *)` lists "iOS 18.0+", "iPadOS 18.0+", and "macOS 15.0+", each with a Beta badge.
DocC marks that page as beta.
A symbol annotated `@available(iOS 18.0, *)` lists "iOS 18.0+" and "iPadOS 18.0+" with Beta badges, and "macOS 13.0+" from the module default.
DocC doesn't mark that page as beta.

### Precedence of Availability Information

DocC builds each symbol page's list of platforms in this order, where each step can replace what the previous step provided for a platform:

1. Start with the default availability from your documentation catalog's `Info.plist` file.
2. Apply the in-source availability attributes for the symbol.
3. If the page has any `@Available` directives, go back to the default availability and apply the directives.
4. Fill in iPadOS and Mac Catalyst from iOS. An in-source iOS version replaces a module default for those platforms. A platform keeps its own value when you mark it unavailable, or when you give it a version in source or with an `@Available` directive.
5. Mark the platforms that are in beta, based on the `--platform` values.

Articles skip the first two steps, so an article only lists the platforms from its own directives.
The iPadOS and Mac Catalyst entries copy iOS because apps for those platforms use the iOS SDK; visionOS doesn't copy iOS.

## See Also

- ``Available``
- ``DeprecationSummary``

<!-- Copyright (c) 2026 Apple Inc and the Swift Project authors. All Rights Reserved. -->
