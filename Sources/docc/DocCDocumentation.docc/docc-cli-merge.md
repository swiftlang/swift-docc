# merge

Merge a list of documentation archives into a combined archive.

## Overview

`docc merge <archive-path> ... [--landing-page-catalog <catalog-path>] [--output-path <output-path>]`

### Options

- term `<archive-path>`:          A list of paths to '.doccarchive' documentation archive directories to combine
                        into a combined archive.
- term `--landing-page-catalog <catalog-path>`:
                        Path to a '.docc' documentation catalog directory with content for the landing
                        page.
- term `-o, --output-path <output-path>`:
                        The location where the documentation compiler writes the combined documentation
                        archive.
