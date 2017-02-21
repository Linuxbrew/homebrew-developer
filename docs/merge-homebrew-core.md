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

```bash
brew merge-homebrew --core
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

Of course, conflicts will be different every merge. You have to resolve these conflicts either manually in a text editor, or by using tools like `diffuse`, `tkdiff`, or `meld`, all of which are available in Linuxbrew (the latter one is provided in `homebrew/gui` tap: `homebrew/gui/meld`). Frequently, conflicts are caused by the new versions of Mac bottles and look like:

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

Remember to mark conflicts as resolved by executing

```bash
git add Formula/<formula-name>.rb
```
for each formula that encountered a conflict during the merge.

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

Once all the conflicts have been resolved, check that there are no obvious stylistic offenses that will prevent bottles from beeing built successfully:

```bash
brew style
```

Fix all the offenses, if any, and add changed files to the staging area by executing

```bash
git add Formula/<formula-name>.rb
```

Finish the merge by running:

```bash
git commit
```
This will open a text editor with pre-populated commit message title and body that will look like this:

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

The merge is now recorded in our local branch `master`. Before these changes can make their way into Linuxbrew, we have to run basic checks on Travis and Circle CIs. This requires a GitHub pull request. To do that, we have to push our local branch `master` to a new branch in your GitHub fork:

```bash
git push your-fork master:merge-YYYY-MM-DD
```
where `YYYY`, `MM` and `DD` are current year, month, and date. Now we are ready to submit a PR. We can do so either from a web browser or *via* `hub pull-request`. To submit a PR using `hub` command, we have to first switch to the `merge-YYY-MM-DD` branch of `your-fork`:

```bash
git checkout merge-YYYY-MM-DD
hub pull-request -m 'Merge YYYY-MM-DD'
```
If you decided to submit a PR from a web browser, make sure to use *`Merge YYYY-MM-DD`* title.

Please add one or two Linuxbrew developers to check the PR.

Once the PR successfully passes the tests and/or is approved by other Linuxbrew developers, you can finalize the merge by pushing your local branch `master` to Linuxbrew:
```bash
git checkout master
git push origin master
```

The merge is now complete. Don't forget to update your GitHub fork:
```bash
git push your-fork master
```

Now, create PRs to build bottles for formulae that encountered a conflict. Here is a simple code snippet that does that by parsing the log message of the last commit:

```bash
brew build-bottle-pr --remote=your-fork $(git log -1 | grep "Formula/" | sed 's|^\s\+Formula/\(.*\).rb|\1|g')
```

## That's it!
