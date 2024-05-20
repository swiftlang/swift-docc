# ``init``

Create a documentation catalog from a template.

@Metadata {
    @PageImage(purpose: icon, source: command-icon)
}

## Arguments, Flags, and Options

- term `--name <name>` **(required)**:           
  The base name for the created documentation catalog ('.docc') directory.

- term `-o, --output-dir <output-dir>` **(required)**:
  The location where the documentation catalog will be written.

- term `--template <template-name>` **(required)**:                       
  The template to use for the created catalog directory. Supported values are:

  - term `articleOnly`: This template contains a starting point for writing article-only reference documentation not tied to an API.

  - term `tutorial`: This template contains the necessary structure and directives to get started with writing tutorials.

- term `-h, --help`:              
  Show help information.

<!-- Copyright (c) 2024 Apple Inc and the Swift Project authors. All Rights Reserved. -->
