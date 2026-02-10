# Adding user-facing diagnostics

Display information to the developer about actionable issues with their documentation.

## Overview

Swift-DocC uses its ``Problem`` type---which wraps a ``Diagnostic`` and a ``Solution`` list---to surface information to the developer about actionable issues with their documentation.

Before you add a new diagnostic to DocC, imagine yourself receiving the diagnostic you're about to add and think about what information you would find useful.
Think about what information you'd need to _both_ understand what's wrong and how to fix it.
Having though about the information you'd like to receive, strive to make the new diagnostic close to that imagined ideal. 

The code that checks for and identifies a given issue may run multiple times per page and need to take performance into consideration. 
For the majority of projects, the majority of elements won't suffer from the given issue and a lightweight check that can move on quickly is optimal.
However, once an issue has been identified; even if a bit of information is computationally expensive to provide, that computation is often worth it if it saves the developer time to understand and address the issue.


### Pick a suitable diagnostic severity

Issues in DocC are classified as either ``DiagnosticSeverity/error``, ``DiagnosticSeverity/warning``, or ``DiagnosticSeverity/information``.
There's a fourth (lower) severity but it is never used and often either a ``Solution`` or a ``DiagnosticNote`` is a better fit instead.

When deciding how severe an issue is, the first question to ask is: is it possible and is it meaningful for DocC to continue processing the rest of the documentation?
If the answer is "no"---meaning that this issue is considered "build breaking"---then you can classify this issue as an ``DiagnosticSeverity/error``.
In practice DocC very rarely uses error-severity diagnostics and many of the current error-severity diagnostics represent unexpected issues that would likely be better represented by a thrown `Swift.Error` type instead.

If the answer is "yes"---that it's both possible and meaningful to continue---then the other question to ask is: is the documentation output impacted by this issue? 
If the output is impacted---for example displaying an unresolved link, missing documentation for a parameter, or not organizing the documentation because of a syntax issue---then you should classify this issue as a ``DiagnosticSeverity/warning``.
If the output _isn't_ impacted---for example a Metadata directive that doesn't configure anything---then ``DiagnosticSeverity/information`` is likely the most appropriate severity but you _can_ also classify this issue as a ``DiagnosticSeverity/warning``.
DocC only displays errors and warnings by default, so even for issues that don't impact the output, it can sometimes be useful to classify them as warnings so that DocC presents them to developers by default. 


### Describe the issue

A ``Diagnostic`` has two places for textual information: a shorter ``Diagnostic/summary`` and a longer ``Diagnostic/explanation`` that can go into more detail.

> Important: 
> Not all contexts that display DocC diagnostics include the `Diagnostic/explanation`. 
> If you only include some critical information in the `explanation` it's possible that the some developers won't see that information.

DocC bases its recommendation for how to phrase diagnostic summaries on [Swift's contributor documentation about diagnostics](https://github.com/swiftlang/swift/blob/main/docs/Diagnostics.md).
Following these recommendations help your new diagnostic fit in with both DocC's other diagnostic and with the Swift compiler's diagnostics. 

- Write your `summary` in a terse abbreviated style similar to English newspaper headlines or recipes.
  Use a single phrase or sentence, with no period at the end and omit words that don't add information, such as grammatical words like "the".
  If it's important to include a second idea, use a semicolon to separate the two parts.
  For example:
  - "Level-3 heading 'See Also' cannot form a See Also section; did you mean to use a level-2 heading?"
  - "Organizing 'NAME' under itself forms a cycle"

- Include information that shows that DocC understands the documentation. 
  For example, referring to "level-2 heading 'Some Heading'" or "instance method 'someMethod()'" is usually unnecessary but the extra specificity can both help the developer pinpoint and reason about the issue and can increase implicit trust in the correctness of diagnostic.
  If there is a single plausible fix or likely intended meaning, include that in the summary using a "did you mean...?" phrase, even if there's a solution for it.
  For example:
  ```diff
  - Unexpected return value documentation 
  + Return value documented for instance method returning void 

  - This heading doesn't sequentially follow the previous heading
  + Level-4 heading doesn't sequentially follow the previous heading level (2); did you mean to use a level-3 heading?
  ```

- When applicable, phrase diagnostics as rules rather than reporting that DocC failed to do something. 
  Try to be specific about _what_ is and isn't allowed rather than saying that something is unsupported or not valid. 
  For example:
  ```diff
  - Unsupported symbol link to article
  + Symbol links can only resolve symbols

  - Invalid use of level-1 heading
  + Page title can only be specified once
  ```

- Lead with the information that's most specific about the issue and follow with information that provide context.
  IDEs and other environments sometimes present DocC diagnostics in space constrained elements, where summaries above a certain length become truncated. 
  Additionally, even if the 
  For example:
  ```diff
  - Missing documentation for parameter 'NAME'
  + Parameter 'NAME' is missing documentation
  
  - Snippet 'PATH' doesn't have a 'NAME' slice.
  + Slice 'NAME' doesn't exist in snippet 'PATH'
  
  - 'NAME' (at 'PATH') cannot be disambiguated using 'TEXT' 
  + 'TEXT' isn't a disambiguation for 'NAME' at 'PATH' 
  ```


### Provide solutions

If you can identify one or more possible actions that would address the issue, 
it can save the developer a lot of time if they can pick and chose from a list of suggested solutions rather than come up with and apply the fix by hand themselves.
That said, don't overwhelm the developer with far fetched or irrelevant solutions. 

If the developer specified an unsupported value but DocC knows the list of all possible values (for example, the names of all image assets in the catalog or the names of all top-level symbols). 
Use ``NearMiss.bestMatches(for:against:)`` to both filter and order the long list of possibilities based on how closely they match what the developer wrote.

If the solution requires some additional unknowable information that the developer needs to provide (for example, the value of a missing directive argument), use Xcode-syntax placeholders (`<#placeholder#>`) as necessary.
It's better to offer a solution with a placeholder in it than to offer no solution at all.


### Organize diagnostics into groups

Developers can configure the severity of individual diagnostics using the `--Wwarning <DIAGNOSTIC_ID>` and `--Werror <DIAGNOSTIC_ID>` flags.
In order to provide increasingly specific and actionable information about an issue, it's sometimes best to create multiple related diagnostics. 
For example: 
- A missing 'path' value for a `Snippet` directive.
- A 'slice' name that doesn't exist for the specified snippet.
- A repeated 'path' or 'slice' configuration for a snippet.
- An unrecognized or misspelled parameter for the `Snippet` directive.

For both implementation reasons and for unit test specificity, it can make sense to use different diagnostic identifiers for each of these issues, 
but a developer may see them as a collection of snippet parameter issues.

In this case you can specify a common ``Diagnostic/groupIdentifier`` for all these different diagnostics.
This allows the developer to configure the severity of all these related diagnostics together.

If you are refining an broad or less specific diagnostic into a collection of more specific diagnostics, 
it _can_ make sense to use the old diagnostic identifier as the group identifier.
This way, developers' custom severity configurations for the previous diagnostic identifier continues to apply to the collection of more specific diagnostics.


### Point to specific markup

In addition to the diagnostic's textual information, you can use the ``Diagnostic/range`` to refer the developer to the specific problematic documentation markup.
IDEs, terminal output, and other environments that display DocC diagnostic information either display the diagnostic inline or include the diagnostic's `start` location in the textual diagnostic output.
Many such environments also highlight the markup between the range's `start` and `end` locations. 
The more specific you can be with the diagnostic's `range`, the easier it will be for the developer to contextualize the diagnostic's textual information.
For example:
- A diagnostic about an unrecognized or misspelled directive should specify a `range` that's only the name portion of the directive markup, rather than the directive's full range which could span many lines.
- A diagnostic about an unsupported value for a known directive parameter should specify a `range` that's only the markup for that value, rather than the full range of directive parameters which would span many lines.
- A diagnostic about a long symbol link where some link components resolve but not the full link should specify a `range` that's the first link component that DocC can't resolve, rather than the full range the link. 
- A diagnostic about a symbol link with unrecognized disambiguation should specify a `range` that's only the unrecognized disambiguation, rather than the range that link component.


Diagnostics about duplicate or conflicting information (for example: a parameter being documented twice, duplicate directives or directive parameters, or multiple documentation extension for the same symbol) also have _another_ location to specify.
In these cases; add a ``DiagnosticNote``---which refers to the other markup---to the diagnostic.

If there's an inherit order between the duplicate information---primarily if one appears before the other in the same file---use a "... previously ... here" phrasing for the note.
If there's no order between the duplicate or conflicting information---for example if the information comes from different files---use a "... also ... here" phrasing instead for the note.
In a few exceptions there may be other "... here" phrases that read better. Use your best judgement.
For example:
- "Previously documented here"
- "Metadata directive also defined here"
- "Overview section starts here"

> Tip: 
> A ``DiagnosticNote`` is presented in the context of the diagnostic that the note is associated with.
> Because of this, you can sometimes omit information that's already present in the diagnostic. 
> For example, the note associated with the diagnostic about a parameter being documented more than once simply says "Previously documented here" rather than "Parameter 'NAME' previously documented here"


<!-- Copyright (c) 2026 Apple Inc and the Swift Project authors. All Rights Reserved. -->
