# Homebrew/linux-dev

Tools for Homebrew on Linux developers

+ **announce**: Create an announcement for new formulae that could be e.g., posted to Twitter.
+ **check-for-deleted-upstream-core-formulae**: Checks for formulae in linuxbrew-core that have been deleted from homebrew-core.
+ **find-formulae-to-bottle**: For a merge commit, generate a list of conflicting formulae.
+ **find-not-bottled**: Search for formulae in linuxbrew-core that do not have a bottle for Linux.
+ **merge-homebrew**: Merge a tap Homebrew/repo into Linuxbrew/repo.
+ **migrate-formula**: Migrates a formula to a new tap and opens the appropriate pull requests.
+ **pull-macos**: When running Homebrew on Linux, pull a bottle for macOS.
+ **request-bottle**: Triggers a Linux bottle build for a formula using GitHub Actions.
+ **test-bot-docker**: Runs `brew test-bot` for a formula in a Docker container.

## Installation

```
brew tap homebrew/linux-dev
```

## Adding new tools

Read the ["External Commands" documentation](https://docs.brew.sh/External-Commands) to see how to create Homebrew external commands.
