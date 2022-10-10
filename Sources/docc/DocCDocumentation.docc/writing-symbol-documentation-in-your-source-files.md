# Writing Symbol Documentation in Your Source Files

Add reference documentation to your symbols that explains how to use them.

## Overview

A common characteristic of a well-crafted API is that it's easy to read and 
practically self-documenting. However, an API alone can't convey important 
information like clear documentation does, such as:

* The overall architecture of a framework or package
* Relationships and dependencies between components in the API
* Boundary conditions, side effects, and errors that occur when using the API

For example, DocC generates an entry in the documentation for the following
method, but it doesn't convey any details about what happens when you call the
method, or whether there are any limits on the values you pass to it:

```swift
// Eat the provided specialty sloth food.
mutating public func eat(_ food: Food, quantity: Int) throws -> Int {
    ...
}
``` 

To help people who use your API better understand it, follow the steps in the sections below to 
add documentation comments to the public symbols in your code base. DocC compiles 
those comments and generates formatted documentation that you share with your users. 

### Add a Basic Description for Each Symbol

The first step toward writing great documentation is to add single-sentence abstracts or summaries, and 
where necessary, _Discussion_ sections, or additional details about a symbol and its use, to each of your framework's public 
symbols. Discussion sections are areas in documentation that provide additional detail about a symbol and its usage.

A summary describes a symbol and augments its name with additional 
details. Try to keep summaries short and precise; use a single sentence or 
sentence fragment that's ideally 150 characters or fewer. Use plain text, and 
avoid including links, technical terms, or other symbol names. Summaries appear in the documentation pages that DocC generates.

If a symbol already has a source comment that begins with two forward slashes 
(`//`), insert an additional forward slash (`/`) to convert it to a 
documentation comment. DocC uses the first line of a documentation comment as 
the summary.

```swift
/// Eat the provided specialty sloth food.
mutating public func eat(_ food: Food, quantity: Int) throws -> Int {
```

> Tip: DocC also supports multiline documentation comments. Begin a comment 
with a forward slash and two asterisks (`/**`), and terminate it with an asterisk 
and a forward slash (`*/`). Content you add in between becomes the 
documentation.

When you need to provide additional content for a symbol, add one 
or more paragraphs directly below a symbol's summary to create a Discussion 
section. The content you include depends on the type of symbol you're 
documenting:

* For a property, explain how it affects the behavior of its parent. 
Describe typical usage and any permitted or default values.
* For a method, describe its usage patterns and any side effects or additional 
behaviors. Highlight whether the method executes asynchronously or performs any 
expensive operations.
* For an enumeration case or constant, concisely describe what it represents.

Insert blank lines to break text into separate paragraphs. 

```swift
/// Eat the provided specialty sloth food.
///
/// Sloths love to eat while they move very slowly through their rainforest 
/// habitats. They are especially happy to consume leaves and twigs, which they 
/// digest over long periods of time, mostly while they sleep.
/// 
/// When they eat food, a sloth's `energyLevel` increases by the food's `energy`.
mutating public func eat(_ food: Food, quantity: Int) throws -> Int {
``` 

When writing content for a Discussion section, use documentation markup. For 
more information, see <doc:formatting-your-documentation-content>.

### Describe the Parameters of a Method

For methods that take parameters, document those parameters directly below the 
summary, or the Discussion section, if you include one. Describe each parameter 
in isolation. Discuss its purpose and, where necessary, the range of acceptable 
values.

DocC supports two approaches to document the parameters of a 
method. You can add a Parameters section, or one or more parameter fields. 
Both use Markdown's list syntax.

A Parameters section begins with a single list item that contains the 
`Parameters` keyword and terminates with a colon (`:`). Individual parameters 
appear as nested list items. A colon separates a parameter's name from its 
description.

```swift
/// - Parameters:
///   - food: The food for the sloth to eat.
///   - quantity: The quantity of the food for the sloth to eat.
mutating public func eat(_ food: Food, quantity: Int) throws -> Int {
```

Parameter fields omit the parent list item and include the `Parameter` 
keyword in each of the individual list items, between the list item marker and 
the name of the parameter.

```swift
/// - Parameter food: The food for the sloth to eat.
/// - Parameter quantity: The quantity of the food for the sloth to eat.
mutating public func eat(_ food: Food, quantity: Int) throws -> Int {
```

After you add documentation for a method’s parameters, preview it in a web browser to see the rendered content.

![A screenshot showing the rendered documentation for the eat(_:quantity:) method.](3_eat)


### Describe the Return Value of a Method

For methods that return a value, include a Returns section in your 
documentation comment to describe the returned value. If 
the return value is optional, provide information about when the method 
returns `nil`. 

There are no restrictions for where you add the Returns section in a 
documentation comment, other than it must come after the summary, and the 
Discussion section, if you include one. 

A Returns section contains a single list item that includes the `Returns` 
keyword. The description of the return value follows the colon (`:`).

```swift
/// - Returns: The sloth's energy level after eating.
mutating public func eat(_ food: Food, quantity: Int) throws -> Int {
```

> Note: DocC supports a single Returns section. Including more than one section results in 
undefined behavior. 

### Describe the Thrown Errors of a Method

If a method can throw an error, add a Throws section to your documentation 
comment. Explain the circumstances that cause the method to throw an error, and 
list the types of possible errors.

Similar to a Returns section, there are no restrictions for where you add a 
Throws section, other than it must come after the summary, and the Discussion 
section, if you include one.

A Throws section contains a single list item that includes the `Throws` 
keyword. Add the content that describes the errors after the colon (:).

```swift
/// - Throws: `SlothError.tooMuchFood` if the quantity is more than 100.
mutating public func eat(_ food: Food, quantity: Int) throws -> Int {
```

> Note: DocC supports a single Throws section. Including more than one section results in 
undefined behavior.

### Create a Richer Experience for Your Symbol Documentation

A documentation comment that includes each of the previously mentioned sections provides much more information to developers than a single-line source comment, as the following example shows: 

```swift
/// Eat the provided specialty sloth food.
///
/// Sloths love to eat while they move very slowly through their rainforest 
/// habitats. They're especially happy to consume leaves and twigs, which they 
/// digest over long periods of time, mostly while they sleep.
///
/// When they eat food, a sloth's `energyLevel` increases by the food's `energy`.
///
/// - Parameters:
///   - food: The food for the sloth to eat.
///   - quantity: The quantity of the food for the sloth to eat.
///
/// - Returns: The sloth's energy level after eating.
///
/// - Throws: `SlothError.tooMuchFood` if the quantity is more than 100.
mutating public func eat(_ food: Food, quantity: Int) throws -> Int {
 ```

In addition, DocC includes features that allow you to create even richer 
documentation for your symbols:

* Use symbol links instead of code voice when referring to other symbols in 
your framework. Symbol links allow you to quickly navigate your framework's 
documentation when viewing in a browser. For more information, see 
<doc:formatting-your-documentation-content>.
* Use extension files to provide additional content for your symbols, such as 
code examples and images, and to help keep the size of their in-source comments 
manageable. For more information, see 
<doc:adding-supplemental-content-to-a-documentation-catalog>.

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
