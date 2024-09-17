# `init`

Generate a documentation catalog from the selected template.

## Overview

`docc init --name <name> --output-dir <output-dir> --template <template-name>`

### Options

-term `--name <name>`:           Name to use as the catalog directory name
-term `-o, --output-dir <output-dir>`:
                        The location where the documention catalog will be written
-term `--template <template-name>`:
                        The catalog template to initialize.
      The provided templates are:

      - articleOnly: This template contains the minimal needed for creating article-only reference
      documentation not tied to symbols. It includes a catalog with just one markdown file and a
      references folder.

      - tutorial: This template contains the necessary structure and directives to get started on
      authoring tutorials.

