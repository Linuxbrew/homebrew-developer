Merging Brew
============

Long-term, Linuxbrew plans to move to using https://github.com/homebrew/brew directly, but we currently use our own fork which implements many changes necessary or convenient for running on Linux.

As such, we occasionally have to merge changes from Homebrew/brew into Linuxbrew/brew.

Merging Procedure
=================

Both Homebrew/brew and Linuxbrew/brew use Git tags to mark stable releases.

Only merge tags, and if we've missed some in-between merge the oldest tag we don't have first (and so on in release order).

If you identify merge conflicts and have to fix them, that can be a good opportunity (if you have the time and inclination) to push Linuxbrew changes upstream, but be aware that they have some strict rules about how you're supposed to separate Linux-specific code out to avoid cluttering the upstream codebase.

Once all the conflicts have been resolved, make sure to check the changes for any red flags of things that have to be fixed for Linux. Don't worry about any changes made to Homebrew Cask.

Finally, run `brew tests` and `brew style` and fix any failures. Also, do sanity tests of installing, uninstalling, upgrading, etc.

Once all this is done, create a PR for merging into Linuxbrew/master.

Once the PR is merged and pushed to master, *don't* tag it yet. Wait a couple of days for people to discover bugs if possible, because it's difficult (although not impossible) to issue hotfixes to Linuxbrew and non-developers are only upgraded to stable tags. If people do discover bugs after the merge but before the tag is released, commit them to the master branch as usual so they can be included in the new release.

Once you're confident that any issues have been sorted out, tag the master branch with the same name as the upstream tag and push that tag.  Also, post a message to [the Linuxbrew mailing list](https://github.com/linuxbrew/brew/issues/1) announcing the release, along with any particularly notable changes for Linux users. If there aren't any changes particularly relevant to Linuxbrew, you can just point to upstream Homebrew's release notes.

*Don't* use `git push --tags` to push the new tag to Linuxbrew. This will push the Homebrew tags to Linuxbrew.
