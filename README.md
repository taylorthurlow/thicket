[![GitHub release](https://img.shields.io/github/release/taylorthurlow/thicket.svg)](https://github.com/taylorthurlow/thicket/releases)
[![Build Status](https://travis-ci.com/taylorthurlow/thicket.svg?branch=develop)](https://travis-ci.com/taylorthurlow/thicket)
![Specs](https://github.com/taylorthurlow/thicket/workflows/specs/badge.svg)
![Build](https://github.com/taylorthurlow/thicket/workflows/publish/badge.svg)

<p align="center">
    <img src="https://user-images.githubusercontent.com/761640/58450380-87fd1900-80c3-11e9-83b6-7fda621a15e2.png" />
</p>

`thicket` is a wrapper for `git log` which aims to make its output just a little more clean.

## Installing

Currently you must either download the binary provided in the most recent release, or clone the repository and build it from source. The next goal is to set up distribution through Homebrew.

### From a Released Binary

- Navigate to the [releases page](https://github.com/taylorthurlow/thicket/releases) and find the release you want to install.
- Download the binary associated with the release
- Move the binary downloaded into a directory which is included in your `$PATH`.

### Build from Source

- Make sure you have `crystal` installed.
- Clone the repository and run `crystal build src/thicket.cr --release`.
- Copy the generated binary which is located in the root of the project to a directory which is included in your $PATH.

## Usage

For help, run `thicket -h`:

```plain
$ thicket -h
Usage: thicket [options]
    -v, --version                    Print the version number
    -d, --directory=DIRECTORY        Path to the project directory
    -n, --commit-limit=LIMIT         Number of commits to parse before stopping
    -a, --all                        Displays all branches on all remotes
    -r, --refs                       Consolidate the refs list
    --main-remote=MAIN_REMOTE        The name of the primary remote, defaults to 'origin'
    -p, --color-prefixes             Adds coloring to commit message prefixes
    --git-binary=BINARY              Path to a git executable
```

## Contributing

Please open an issue regarding any changes you wish to make before starting to work on anything. I am always open to providing assistance, so if you need to ask any questions please don't hesitate to do so, whether it be how to approach solving a problem or questions regarding how I might prefer something be implemented.

### Building

```bash
shards install
crystal build --release src/thicket.cr -o bin/thicket
```
