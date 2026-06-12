/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

// This file defines data constants for resource files that make up Swift-DocC's base "template" for static HTML output.
//
// We're defining these data constants like this ourselves to workaround restrictions with `.embedInCode()` package resources.
// https://github.com/swiftlang/swift-package-manager/issues/6969
//
// If we instead used real files in a subdirectory, we would need to handle them the same as the Swift-DocC Render template, meaning:
// - DocC would need to find these resources at runtime and handle the case when the resources are missing.
// - We would need to update the script that installs Swift-DocC into the Swift toolchain to copy these resources into a suitable location.
// - In order to support local development workflows would need to support a runtime override of this resource location.
//
// Conceptually these two groups of files are very alike but practically there are two big differences between them:
// - These resources for the static HTML output are defined and developed inside the Swift-DocC repo.
// - These resources for the static HTML output are about two orders of magnitude smaller than the Swift-DocC Render template.
// Thus, in order to facilitate easier development of the static HTML output, it makes sense to handle these resources differently, at least for now.

package import struct Foundation.Data

// When working with these resources, a decent workflow is to build some static HTML output and then in-place modify the copied resources in the output directory.
// This way, you can make adjustments to the CSS or add a new icon and refresh the page to see the changes reflected as you make quick iterations.
// If you're happy with your changes or if you need to make modifications to the static HTML that DocC outputs, you can copy the contents of the modified files back here.

/// The group of resource files that make up DocC's base "template" for static HTML output.
package enum StaticResources {
    // This type is only responsible for naming the blobs of data. It's the caller's responsibility to work with the file system to write these files into the output location.
    
    package struct File {
        package let filename: String
        package let data: Data
    }
    
    package static let allFiles = [
        referenceStyleSheet,
        // Page kind icons
        apiCollectionIcon,
        articleIcon,
        moduleIcon,
        // UI element icons
        anchorIcon,
        sidebarIcon,
    ]
    
    // MARK: Stylesheets
    
    // For the future; the idea is that tutorial documentation would have its own stylesheet so that each page's `<head>` can link to only the style information that it needs.
    
    /// The style sheet that DocC uses to define the layout and appearance of "reference" documentation (symbols and articles).
    static let referenceStyleSheet = File(filename: "reference.css", data: Data("""
:root {
  --color-header-text: #1d1d1f;
  --color-code-background: #f7f7f7;
  --color-secondary-label: #6e6e73;
  
  --color-grid: rgb(204, 204, 204);
  
  --color-fill-gray: #ccc;
  --color-fill-gray-quaternary: #f0f0f0;
  --color-fill-gray-secondary: #f5f5f5;
  --color-fill-gray-tertiary: #f0f0f0;
  
  --color-badge-deprecated: #bf4800;
  
  --color-standard-blue: #06c;
  --color-standard-gray: #afafaf;
  --color-standard-green: #509ca3;
  --color-standard-orange: #ff5a00;
  --color-standard-purple: #bf6af7;
  --color-standard-red: #d82797;
  --color-standard-yellow: #ff9f2c;
  
  --color-figure-gray-secondary: rgb(102, 102, 102);
  --color-figure-blue: rgb(51, 102, 255);
  
  --font-default: "Helvetica Neue", Helvetica, Arial, sans-serif;
  --font-mono: Menlo, monospace;
}

/* Hide and show language specific content by modifying these classes through JS */
.swift-only {
  display: unset;
}
.occ-only {
  display: none;
}

* {
  margin: 0;
}

body {
  font-family: var(--font-default);
  
  font-synthesis: none;
  -moz-font-feature-settings: 'kern';
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-align: start;
  overflow-wrap: break-word;
  
  /* Default margin for stacked elements. */
  --spacing-stacked-margin-small: 0.4em;

  /* Default margin-top for subsequent elements. */
  --spacing-stacked-margin-large: 0.8em;

  /* Default margin for elements that require extra spacing */
  --spacing-stacked-margin-xlarge: calc(var(--spacing-stacked-margin-large) * 2);

  /* Default param spacing */
  --spacing-param: 28px;

  /* Default margin for Code Listing in Declaration */
  --declaration-code-listing-margin: 30px 0 0 0;

  /* Default padding for Code Blocks */
  --code-block-style-elements-padding: 8px 14px;
}

section {
  max-width: 820px;
  margin: 0 auto;
  
  @media only screen and (max-width: 1250px) {
    padding-left: 80px;
    padding-right: 80px;
  }
  
  @media only screen and (max-width: 735px) {
    padding-left: 20px;
    padding-right: 20px;
  }
  
  @media only screen and (min-width: 1500px) {
    max-width: 920px;
  }
}

hr {
  max-width: 820px;
  margin: 0 auto;
  
  @media only screen and (max-width: 1250px) {
    max-width: 660px;
  }
  
  @media only screen and (max-width: 820px) {
    margin: 0 80px;
  }
  
  @media only screen and (max-width: 735px) {
    margin: 0 20px;
  }
  
  @media only screen and (min-width: 1500px) {
    max-width: 920px;
  }
}

section {
  box-sizing: border-box;

  padding-top: 40px;
  padding-bottom: 40px;
  
  @media print {
    padding-left: 80px;
    padding-right: 80px;
    max-width: none;
  }
}

section + section {
  /* avoid double padding between sections */
  padding-top: 0;
}

hr {
  border: none;
  background: var(--color-grid);
  height: 1px;
}

h1, h2, h3 {
  font-weight: 400;
}

h4, h5, h6 {
  font-weight: 600;
}

h1 {
  font-size: 40px;
  line-height: 44px;
  margin-top: 1.6em;
  
  @media only screen and (max-width: 1250px) {
    font-size: 32px;
    line-height: 36px;
  }
  
  @media only screen and (max-width: 735px) {
    font-size: 28px;
    line-height: 32px;
  }
}

h2 {
  font-size: 32px;
  line-height: 36px;
  margin-top: 1.6em;
  
  @media only screen and (max-width: 1250px) {
    font-size: 28px;
    line-height: 32px;
  }
  
  @media only screen and (max-width: 735px) {
    font-size: 24px;
    line-height: 28px;
  }
}

h3 {
  /* Note that this is different inside a Topics/SeeAlso section */
  font-size: 28px;
  line-height: 32px;
  padding-top: 36px;
  
  @media only screen and (max-width: 1250px) {
    font-size: 24px;
    line-height: 28px;
  }
  
  @media only screen and (max-width: 735px) {
    font-size: 21px;
    line-height: 25px;
  }
}

h4 {
  font-size: 24px;
  line-height: 28px;
  
  @media only screen and (max-width: 1250px) {
    font-size: 21px;
    line-height: 25px;
  }
}

h5 {
   font-size: 22px;
   line-height: 26px;
   
   @media only screen and (max-width: 1250px) {
     font-size: 20px;
     line-height: 24px;
   }
   
   @media only screen and (max-width: 735px) {
     font-size: 18px;
     line-height: 26px;
   }
}

h6 {
  font-size: 17px;
  line-height: 25px;
}

a {
  color: var(--color-figure-blue);
}

#eyebrow {
  font-size: 21px;
  line-height: 25px;
  margin: 0;
  margin-bottom: 15px;
  color: var(--color-figure-gray-secondary);
  
  @media only screen and (max-width: 1250px) {
    font-size: 19px;
    line-height: 23px;
  }
}

#breadcrumbs > ul {
  padding: 0;
  margin-bottom: 20px;
  display: flex;
  list-style-type: none;
  
  &>li {
    font-size: 14px;
    line-height: 20px;
    a {
      color: #000;
    }
    
    &:not(:first-child):before {
      content: "/";
      width: 5px;
      margin-inline: 5px;
    }
  }
}

#availability {
  padding: 0;
  margin-top: 15px;
  margin-bottom: 20px;
  display: flex;
  flex-wrap: wrap;
  gap: 11px;
  list-style-type: none;
  
  align-items: center;
  
  &>li {
    font-size: 14px;
    line-height: 20px;
    height: 20px;
    
    &:not(:last-child):after {
      content: "";
      display: inline-block;
      height: 14px;
      width: 1px;
      position: relative;
      top: 2px;
      margin-left: 10px;
      
      background-color: black; /* TODO: dark mode */
    }
  }
}

h1, h2, h3, h4, h5, h6 {
  padding-inline-end: 23px; /* for the hover icon */
  
  &> a {
    text-decoration: none;
    color: black; /* TODO: dark mode */
    &:hover {
      &:after {
        margin-left: 7px;
        content: url(anchor.svg)
      }
    }
  }
}

#hero {
  margin-bottom: 40px;
  
  position: relative;
  clip-path: inset(0 -50%);
  
  /* Draw the background in a pseudo element so that it can move behind the icon */
  &:before {
    content: "";
    background: #f0f0f0;
    
    position: absolute;
    top: 0;
    left: -50%;
    width: 200%;
    height: 100%;
    z-index: -2;
  }
}

/* Add background icons for articles, API collections, and module pages */

#hero.article:after {
  background: url(article.svg);
}

#hero.api-collection:after {
  background: url(api-collection.svg);
}

#hero.module:after {
  background: url(module.svg);
}

#hero.article:after, #hero.api-collection:after, #hero.module:after {
  content: "";
  --icon-size: 250px;
  
  position: absolute;
  top: calc(50% - var(--icon-size) / 2);
  right: 25px;
  opacity: 0.15;
  z-index: -1;
  
  width: var(--icon-size);
  height: var(--icon-size);
  background-size: var(--icon-size) var(--icon-size);
}

section :first-child {
  margin-top: 0;
}

/* Workaround some margin issues with H1 elements in the authored content. */
#eyebrow + h1 {
  margin-top: 0;
}

#abstract {
  font-size: 21px;
  line-height: 29px;
  
  margin-top: 12px;
  
  @media only screen and (max-width: 735px) {
    font-size: 19px;
    line-height: 27px;
  }
}

#declaration, pre {
  margin-top: 40px;
  
  background: var(--color-code-background);
  border-color: var(--color-grid);
  border-radius: 4px;
  border-style: solid;
  border-width: 1px;
  padding: var(--code-block-style-elements-padding);
  line-height: 25px;
  
  /* We probably don't need most of these colors because they don't appear in declarations */
  --color-syntax-attributes: rgb(148, 113, 0);
  --color-syntax-characters: rgb(39, 42, 216);
  --color-syntax-comments: rgb(112, 127, 140);
  --color-syntax-deletion: var(--color-figure-red);
  --color-syntax-documentation-markup: rgb(80, 99, 117);
  --color-syntax-documentation-markup-keywords: rgb(80, 99, 117);
  --color-syntax-heading: rgb(186, 45, 162);
  --color-syntax-highlighted: rgba(0, 113, 227, 0.2);
  --color-syntax-keywords: rgb(173, 61, 164);
  --color-syntax-marks: rgb(0, 0, 0);
  --color-syntax-numbers: rgb(39, 42, 216);
  --color-syntax-other-class-names: rgb(112, 61, 170);
  --color-syntax-other-constants: rgb(75, 33, 176);
  --color-syntax-other-declarations: rgb(4, 124, 176);
  --color-syntax-other-function-and-method-names: rgb(75, 33, 176);
  --color-syntax-other-instance-variables-and-globals: rgb(112, 61, 170);
  --color-syntax-other-preprocessor-macros: rgb(120, 73, 42);
  --color-syntax-other-type-names: rgb(112, 61, 170);
  --color-syntax-param-internal-name: rgb(64, 64, 64);
  --color-syntax-plain-text: rgb(0, 0, 0);
  --color-syntax-preprocessor-statements: rgb(120, 73, 42);
  --color-syntax-project-class-names: rgb(62, 128, 135);
  --color-syntax-project-constants: rgb(45, 100, 105);
  --color-syntax-project-function-and-method-names: rgb(45, 100, 105);
  --color-syntax-project-instance-variables-and-globals: rgb(62, 128, 135);
  --color-syntax-project-preprocessor-macros: rgb(120, 73, 42);
  --color-syntax-project-type-names: rgb(62, 128, 135);
  --color-syntax-strings: rgb(209, 47, 27);
  --color-syntax-type-declarations: rgb(3, 99, 140);
  --color-syntax-urls: rgb(19, 55, 255);
  
  &> code {
    display: block;
    
    font-size: 15px;
    line-height: 25px;
    
    .keyword, .attribute {
      color: var(--color-syntax-keywords);
    }
    .internalParam {
      color: var(--color-syntax-param-internal-name);
    }
    .typeIdentifier {
      color: var(--color-syntax-other-type-names);
      &:not(:hover) {
        text-decoration: none;
      }
    }
  }
}

pre {
  margin-top: 2.1em;
}

p {
  font-size: 17px;
  line-height: 24px;
  
  margin-top: 0.8em;
}

/* Parameter and term definition lists */

dl {
  margin-top: 0.85em;
  
  dt {
    font-weight: 600;
    font-size: 17px;
    line-height: 25px;
    font-family: var(--font-mono);
    padding-left: 17px;
    padding-top: var(--spacing-param);
    
    &:first-child {
      padding-top: 0;
    }
    
    @media only screen and (max-width: 735px) {
      padding-left: 0;
    }
  }
  
  dd {
    padding-left: 34px;
    
    p {
      margin: 0;
      line-height: 23px;
    }
    
    @media only screen and (max-width: 735px) {
      padding-left: 0;
    }
  }
}

#Topics, #See-Also {
  &> ul {
    padding: 0;
    &> li {
      margin-top: 15px;
      list-style: none;
      &> a {
        padding: 5px 0;
        display: inline-flex;
        
        text-decoration: none;
        font-size: 1rem;
        
        &:hover {
          text-decoration: underline;
        }
        
        &> code {
          font-size: 17px;
          line-height: 24px;
          
          
          &>.decorator {
            color: rgb(102, 102, 102);
          }
          &>.identifier {
            color: var(--color-figure-blue);
          }
        }
      }
      &> p {
        margin: 0;
        margin-inline-start: 2.294em; /* it's defined like this in DocC Render */
        line-height: 24px;
      }
      
      /* Display icons for articles and API collections */
      .api-collection, .article {
        margin-top: 0px; /* avoid the top padding of other paragraphs */
        
        &:before {
          margin-right: 20px;
          margin-left: 4px;
          width: 36px;
          position: relative;
          top: 2px;
          content: url(api-collection.svg);
        }
      }
      .article:before {
        content: url(article.svg)
      }
    }
  }
  &> h3 {
    font-size: 24px;
    line-height: 28px;
    padding-top: 39px;
    
    @media only screen and (max-width: 1250px) {
      font-size: 21px;
      line-height: 25px;
    }
  }
  &> h2 {
    margin-top: 0px;
  }
  &> p {
    margin-top: 15px;
  }
}

table {
  margin-top: 1.6em;
  margin-bottom: 1.6em;
  
  font-size: 17px;
  line-height: 25px;
  
  border-collapse: collapse;
  border-spacing: 0;
  
  th, td {
    text-align: start;
    padding: 10px;
    
    border: 1px solid #f0f0f0;
  }
  
  /* No border on the outside of the table */
  th {
    border-top: none;
  }
  th:first-of-type {
    border-left: none;
  }
  th:last-of-type {
    border-right: none;
  }
  tr:last-of-type > td {
    border-bottom: none;
  }
  
  tr {
    td:first-of-type {
      border-left: none;
    }
    td:last-of-type {
      border-right: none;
    }
  }
}

#Mentioned-In > ul {
  padding: 0;
  &> li {
    margin-top: 10px;
    list-style: none;
    &> a {
      padding: 5px 0;
      display: inline-flex;
      
      text-decoration: none;
      font-size: 17px;
      
      &:hover {
        text-decoration: underline;
      }
    }
    &> p {
      margin: 0;
      margin-inline-start: 2.294em; /* it's defined like this in DocC Render */
      line-height: 24px;
    }
    
    /* Display an article icons*/
    &:before {
      margin-right: 8px;
      margin-left: 2px;
      width: 36px;
      position: relative;
      top: 2px;
      content: url(article.svg);
    }
  }
}

/* Asides */

aside {
  background-color: rgb(245, 245, 245);
  border: 0px solid rgb(102, 102, 102);
  border-inline-start-width: 6px;
  
  border-radius: 4px;
  padding: 16px;
  
  margin-top: 27px;
  
  .label {
    font-weight: 600;
    margin-top: 0;
  }
  
  
  &> p:nth-of-type(2) {
    margin-top: 0.4em;
  }
}

/* Links */
a {
  color: var(--color-figure-blue);
}

/* Inline Elements */

b, strong {
  font-weight: 600;
}

em, i, cite, dfn {
  font-style: italic;
}

sup {
  font-size: .6em;
  vertical-align: top;
  position: relative;
  bottom: -.2em;
  
  h1 &,
  h2 &,
  h3 & {
    font-size: .4em;
  }
  
  a {
    vertical-align: inherit;
    color: inherit;
    
    &:hover {
      color: var(--color-figure-blue);
      text-decoration: none;
    }
  }
}

sub {
  line-height: 1;
}

abbr {
  border: 0;
}

code {
  font-weight: inherit;
  letter-spacing: 0;
}

/* Scroll the code inside of code blocks */
pre {
  overflow: auto;
  -webkit-overflow-scrolling: auto;
  white-space: pre;
  overflow-wrap: normal;
}

body > header {
  position: sticky;
  top: 0;
  width: 100%;
  height: 52px;
  z-index: 5;
  
  display: flex;
  align-items: center;
  justify-content: space-between;
  
  border-bottom: 1px solid var(--color-grid);
  line-height: 25px;
  
  /* Aim for a light visual effects appearance */
  backdrop-filter: saturate(1.8) blur(20px);
  background-color: rgba(255, 255, 255, 0.7);
  
  h2 {
    float: left;
    font-size: 21px;
    line-height: 25px;
    font-weight: 600;
    margin-top: 0;
    
    &:before {
      width: 30px;
      display: inline-block;
      content: url(sidebar.svg)
    }
    
    margin-left: 22px;
  }
  
  span {
    float: right;
    line-height: 18px;
    font-size: 14px;
    display: inline-block;
    
    margin-right: 22px;
  }
}

body > footer {
  width: 100%;
  height: 63px;
  
  display: flex;
  align-items: center;
  justify-content: space-between;
  
  border-top: 1px solid var(--color-grid);
  line-height: 25px;
  
  fieldset {
    legend {
      /* This is copied from Swift-DocC Render to make the legend "invisible" without display:none */
      position: absolute;
      clip: rect(1px,1px,1px,1px);
      clip-path: inset(0 0 99.9% 99.9%);
      overflow: hidden;
      height: 1px;
      width: 1px;
    }
    
    display: inline-flex;
    --color: rgb(0, 0, 255);
    
    border: 1px solid var(--color);
    border-radius: 4px;
    padding: 1px;
    
    position: absolute;
    right: 15%; /* FIXME: Position this properly */
    
    label {
      margin: 0;
      cursor: pointer;
      
      width: 42px;
      text-align: center;
      
      color: var(--color);
      font-size: 12px;
      padding: 2px 6px;
      line-height: 15px;
      border-radius: 2px;
      
      box-sizing: border-box;
      
      &:has(input:checked) {
        color: white;
        background-color: var(--color);
      }
      
      input {
        display: none;
      }
    }
  }
}
    
""".utf8))
    
    // MARK: Icons

    /// The icon that DocC displays for API collection pages and their references in curation or the navigation hierarchy.
    static let apiCollectionIcon = File(filename: "api-collection.svg", data: Data("""
<svg aria-hidden="true" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="14px" height="14px" viewBox="0 0 14 14" fill="#666">
  <path d="m1 1v12h12v-12zm11 11h-10v-10h10z"/>
  <path d="m3 4h8v1h-8zm0 2.5h8v1h-8zm0 2.5h8v1h-8z"/>
  <path d="m3 4h8v1h-8z"/>
  <path d="m3 6.5h8v1h-8z"/>
  <path d="m3 9h8v1h-8z"/>
</svg>
""".utf8))

    /// The icon that DocC displays for article pages and their references in curation or the navigation hierarchy.
    static let articleIcon = File(filename: "article.svg", data: Data("""
<svg aria-hidden="true" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="15px" height="15px" viewBox="0 0 14 14" fill="#666">
  <path d="M8.033 1l3.967 4.015v7.985h-10v-12zM7.615 2h-4.615v10h8v-6.574z"></path>
  <path d="M7 1h1v4h-1z"></path>
  <path d="M7 5h5v1h-5z"></path>
</svg>
""".utf8))

    /// The icon that DocC displays for module/framework pages and their references in curation or the navigation hierarchy.
    static let moduleIcon = File(filename: "module.svg", data: Data("""
<svg aria-hidden="true" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="15px" height="15px" viewBox="0 0 14 14" fill="#666">
  <path d="M3.39,9l3.16,1.84.47.28.47-.28L10.61,9l.45.26,1.08.63L7,12.91l-5.16-3,1.08-.64L3.39,9M7,0,0,4.1,2.47,5.55,0,7,2.47,8.44,0,9.9,7,14l7-4.1L11.53,8.45,14,7,11.53,5.56,14,4.1ZM7,7.12,5.87,6.45l-1.54-.9L3.39,5,1.85,4.1,7,1.08l5.17,3L10.6,5l-.93.55-1.54.91ZM7,10,3.39,7.9,1.85,7,3.4,6.09,4.94,7,7,8.2,9.06,7,10.6,6.1,12.15,7l-1.55.9Z"/>
</svg>
""".utf8))

    /// The icon that DocC uses for the button to show and hide the on-page sidebar / navigation hierarchy.
    static let sidebarIcon = File(filename: "sidebar.svg", data: Data("""
<svg aria-hidden="true" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="19px" height="19px" viewBox="0 -1 14 14">
  <path d="M6.533 1.867h-6.533v10.267h14v-10.267zM0.933 11.2v-8.4h4.667v8.4zM13.067 11.2h-6.533v-8.4h6.533z M1.867 5.133h2.8v0.933h-2.8z M1.867 7.933h2.8v0.933h-2.8z" />
</svg>

""".utf8))

    /// The icon that DocC displays, on-hover, next to headings that are links to themselves.
    static let anchorIcon = File(filename: "anchor.svg", data: Data("""
<svg aria-hidden="true" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="16px" height="16px" viewBox="0 0 20 20" fill="#666">
  <path d="M19.34,4.88L15.12,.66c-.87-.87-2.3-.87-3.17,0l-3.55,3.56-1.38,1.38-1.4,1.4c-.47,.47-.68,1.09-.64,1.7,.02,.29,.09,.58,.21,.84,.11,.23,.24,.44,.43,.63l4.22,4.22h0l.53-.53,.53-.53h0l-4.22-4.22c-.29-.29-.29-.77,0-1.06l1.4-1.4,.91-.91,.58-.58,.55-.55,2.9-2.9c.29-.29,.77-.29,1.06,0l4.22,4.22c.29,.29,.29,.77,0,1.06l-2.9,2.9c.14,.24,.24,.49,.31,.75,.08,.32,.11,.64,.09,.96l3.55-3.55c.87-.87,.87-2.3,0-3.17Z"/>
  <path d="M14.41,9.82s0,0,0,0l-4.22-4.22h0l-.53,.53-.53,.53h0l4.22,4.22c.29,.29,.29,.77,0,1.06l-1.4,1.4-.91,.91-.58,.58-.55,.55h0l-2.9,2.9c-.29,.29-.77,.29-1.06,0L1.73,14.04c-.29-.29-.29-.77,0-1.06l2.9-2.9c-.14-.24-.24-.49-.31-.75-.08-.32-.11-.64-.09-.97L.68,11.93c-.87,.87-.87,2.3,0,3.17l4.22,4.22c.87,.87,2.3,.87,3.17,0l3.55-3.55,1.38-1.38,1.4-1.4c.47-.47,.68-1.09,.64-1.7-.02-.29-.09-.58-.21-.84-.11-.22-.24-.44-.43-.62Z"/>
</svg>
""".utf8))

}
