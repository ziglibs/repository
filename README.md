# Zig Package Repository

This is one community-maintained repository of zig packages.

## Contributions
If you have an actively maintained package, feel free to create a PR that adds your package to the repository! If you feel like it, you're also free to add other peoples packages!

### Adding new packages

The repo provides a convenience tool to create new packages. Just run `zig build add` to get a prompt for package informations. The tool will verify that the entered information is vaguely correct and follows the format rules, also checks if a package with that name already exists and if the tags are all valid.

### Verification

![Repository Validation](https://github.com/ziglibs/repository/workflows/Repository%20Validation/badge.svg?event=push)

This repository will use the CI to verify if all PRs keep the database consistent. If you want to locally test this before doing the PR, just call `zig build verify` in the root folder.

## Repository structure

The repository contains two major data sets: *packages* and *tags*.

*Tags* are just groups of packages, each package can have zero or more tags assigned. *Packages* are basically a link to *any* git repository paired with a root source file which is required for the package to be imported.

### `packages/`
A folder containing a single file per package. Each file is a json file following this structure:
```json
{
  "author": "<author>",
  "description": "<description>",
  "git": "<url>",
  "root_file": "<path>",
  "tags": [
    "<tag>", "<tag>"
  ]
}
```

The fields have the following meaning:
- `author` is the name (or nickname) of the package author
- `description` is a short description of the package
- `git` is a path to the git repository where the package can be fetched
- `root_file` is an absolute path in unix style (path segments separated by `/`) to the root file of the package. This is what should be used for `std.build.Pkg.path`
- `tags` is an array of strings where each item is the name of a tag in the folder `tags/`. Tags are identified by their file name (without extension) and will group the packages

### `tags/`
A folder containing a single file per tag. Each file is a json file following this structure:
```json
{
  "description": "<text>"
}
```

The fields have the following meaning:
- `description` is a short description of what kind of packages can be found in this group.

### `tools/`

This folder contains the sources of the verification tools and other nice things.
