# Homebrew/linux-dev

Tools for Homebrew on Linux developers

+ **announce**: Create an announcement for new formulae.
+ **check-for-deleted-upstream-core-formulae**: Check for formulae in [Homebrew/linuxbrew-core][linuxbrew-core] that have been deleted from homebrew-core.
+ **fetch-failed-logs**: Fetch failed part of a CI run for the specified formula.
+ **find-formulae-to-bottle**: Generate a list of formulae that encountered a conflict in the specified  merge.
+ **find-not-bottled**: Search for formulae in [Homebrew/linuxbrew-core][linuxbrew-core] that do not have a bottle for Linux.
+ **merge-homebrew**: Merge Homebrew/repo into Linuxbrew/repo.
+ **migrate-formula**: Migrate a formula to a new tap and open appropriate pull requests.
+ **request-bottle**: Trigger a GitHub Actions CI to build Linux bottle for the specified a formula(e).
+ **test-bot-docker**: Run `brew test-bot` in a Docker container.

## Installation

```sh
brew tap homebrew/linux-dev
```

## Adding new tools

Read the ["External Commands" documentation](https://docs.brew.sh/External-Commands) to see how to create Homebrew external commands.

[linuxbrew-core]: https://github.com/Homebrew/linuxbrew-core
