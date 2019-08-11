# Merging hombrew-core

## Introduction

Linuxbrew is Homebrew's fork and, therefore, it has to periodically merge changes made by Homebrew developers and contributors. Below we describe the steps required to merge `Homebrew/homebrew-core` into `Linuxbrew/homebrew-core`, possible conflicts and ways to resolve them. Note, that instructions below have been written for a "clean" environment and you might be able to skip some of the steps if you have done them in the past.

## Preparation

First of all, we want to enable developer commands and prevent automatic updates while we do the merge:

```bash
export HOMEBREW_DEVELOPER=1
export HOMEBREW_NO_AUTO_UPDATE=1
```

Once we've done that, we need to get access to the `merge-homebrew` command that will be used for the merge. To do that we have to tap `linuxbrew/homebrew-developer` repo:

```bash
brew tap linuxbrew/developer
```
Note, that we can omit the `homebrew-` prefix because `tap` command will add it to the repository name if it does not have it already.

Next, we have to navigate to the reposotory where we want to do the merge and make sure that there are 3 remotes:

* a remote named `origin` pointing to Linuxbrew,
* a remote named `homebrew` pointing to Homebrew, and
* a remote pointing to your GitHub fork of Linuxbrew.

Remote names `origin` and `homebrew` are hard-coded in `merge-homebrew`, while the remote pointing to your fork can have any name. We will call this remote `your-fork`. It will be used to submit a pull request for the merge.

```bash
brew install hub
cd $(brew --repo homebrew/core)
hub remote add homebrew
hub remote add your-fork
```

Now, let's make sure that our local branch `master` is clean and that your fork is up-to-date with Linuxbrew:

```bash
git checkout master
git fetch origin master
git reset --hard origin/master
git push --force your-fork master
```

Strictly speaking, there is no need for `git reset --hard origin/master` and simple `git merge origin master` would have been sufficient if you didn't mess with your local `master` branch. However, hard reset makes sure that these instructions are correct even if you did mess something up. The same is true for the `--force` flag for the `git push` command above.

Now we are ready to do the merge.

## The Merge

By default, the following command will attempt to merge all the changes that the upstream Homebrew developers have made.

```bash
brew merge-homebrew --core
```

Merging all the changes from upstream in one go is usually undesireable since our build servers will time out. Instead, attempt to only merge 8-10 modified formulae.

`git log --oneline master..homebrew/master` will show a list of all the upstream commits since the last merge, from oldest to newest.

Pick a commit sha that will merge between 8-10 formulae (16-20 commits including bottles). Once you're satisfied with the list of updated formulae, begin the merge:

```bash
brew merge-homebrew --core --skip-style <sha>
```

## Simple Conflicts

Once you issue the above command, the merge will begin and in the very end you will see the list of (conflicting) formulae that `merge-homebrew` could not merge automatically:

```bash
==> Conflicts
Formula/git-lfs.rb Formula/gnutls.rb Formula/godep.rb
```

Note, that you can also get a list of unmerged files (*i.e.* files with conflicts) using:
```sh
git diff --name-only --diff-filter=U
```

Of course, conflicts will be different every merge. You have to resolve these conflicts either manually in a text editor, or by using tools like `diffuse`, `tkdiff`, or `meld`, some of which are available from Linuxbrew. Frequently, conflicts are caused by the new versions of Mac bottles and look like:

```ruby
<<<<<<< HEAD
    sha256 "bd66be269cbfe387920651c5f4f4bc01e0793034d08b5975f35f7fdfdb6c61a7" => :sierra
    sha256 "7071cb98f72c73adb30afbe049beaf947fabfeb55e9f03e0db594c568d77d69d" => :el_capitan
    sha256 "c7c0fe2464771bdcfd626fcbda9f55cb003ac1de060c51459366907edd912683" => :yosemite
    sha256 "95d4c82d38262a4bc7ef4f0a10ce2ecf90e137b67df15f8bf8df76e962e218b6" => :x86_64_linux
=======
    sha256 "ee6db42174fdc572d743e0142818b542291ca2e6ea3c20ff6a47686589cdc274" => :sierra
    sha256 "e079a92a6156e2c87c59a59887d0ae0b6450d6f3a9c1fe14838b6bc657faefaa" => :el_capitan
    sha256 "c334f91d5809d2be3982f511a3dfe9a887ef911b88b25f870558d5c7e18a15ad" => :yosemite
>>>>>>> homebrew/master
```

For such conflicts, simply remove the "HEAD" (Linuxbrew's) part of the conflict along with `<<<<<<< HEAD`, `=======`, and `>>>>>>> homebrew/master` lines. Later, we will submit a request to rebuild bottles for Linuxbrew for such formulae.

The `merge-homebrew` script will stage resolved conflicts for you.

## Complex Conflicts

Of course, from time to time conflicts are more complicated and you have to look carefully into what's going on. An example of a slightly more complex conflict is below:

```ruby
<<<<<<< HEAD
    if OS.mac?
      lib.install "out-shared/libleveldb.dylib.1.19" => "libleveldb.1.19.dylib"
      lib.install_symlink lib/"libleveldb.1.19.dylib" => "libleveldb.dylib"
      lib.install_symlink lib/"libleveldb.1.19.dylib" => "libleveldb.1.dylib"
      system "install_name_tool", "-id", "#{lib}/libleveldb.1.dylib", "#{lib}/libleveldb.1.19.dylib"
    else
      lib.install Dir["out-shared/libleveldb.so*"]
    end
=======
    lib.install "out-shared/libleveldb.dylib.1.19" => "libleveldb.1.19.dylib"
    lib.install_symlink lib/"libleveldb.1.19.dylib" => "libleveldb.dylib"
    lib.install_symlink lib/"libleveldb.1.19.dylib" => "libleveldb.1.dylib"
    MachO::Tools.change_dylib_id("#{lib}/libleveldb.1.dylib", "#{lib}/libleveldb.1.19.dylib")
>>>>>>> homebrew/master
```

Note, that in the "HEAD" (Linuxbrew's) part we see previous code of the Homebrew's formula wrapped in `if OS.mac?`. To resolve such a conflict you have to replace the contents of `if OS.mac?` part up until `else` with the contents of the bottom part of the conflict ("homebrew/master"). You also have to check if there are any obvious modifications that have to be made to the `else` part of the code that deals with non-Mac-related code.


## Finishing the merge

Once all the conflicts have been resolved, a text editor will open with pre-populated commit message title and body:

```text
Merge branch homebrew/master into linuxbrew/master

# Conflicts:
#       Formula/git-lfs.rb
#       Formula/gnutls.rb
#       Formula/godep.rb
```

Leave the title of the message unchanged and uncomment all the conflicting files. Your final commit message should be:

```text
Merge branch homebrew/master into linuxbrew/master

Conflicts:
        Formula/git-lfs.rb
        Formula/gnutls.rb
        Formula/godep.rb
```

## Submitting a PR

The `merge-homebrew` command will create a pull-request for you, using `hub`.

Please add one or two Linuxbrew developers to check the PR.

Once the PR successfully passes the tests and/or is approved by other Linuxbrew developers, you can finalize the merge with:

```bash
brew pull --clean <PR-NUMBER>
git push origin master
```

The merge is now complete. Don't forget to update your GitHub fork by running `git push your-fork master`

# Creating PRs to build bottles for conflicting formulae

Now, create PRs to build bottles for formulae that encountered a conflict. A fast way to do this is to use `brew find-formulae-to-bottle` and a `for` loop in your shell:

```bash
for i in $(brew find-formulae-to-bottle); do
  brew build-bottle-pr $i
done
```

## Congratulations! All done!
