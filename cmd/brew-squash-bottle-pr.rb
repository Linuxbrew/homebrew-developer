require "formula"

module Homebrew
  # Squash the last two commits of build-bottle-pr.
  # Usage:
  #    brew build-bottle-pr foo
  #    brew pull --bottle 123
  #    brew squash-bottle-pr
  def squash_bottle_pr
    unless Utils.popen_read("git", "log", "-n1", "--pretty=%s", "HEAD~1") =~ /: Build a bottle for Linuxbrew$/
      opoo "No build-bottle-pr commit was found"
      return
    end

    head = `git rev-parse HEAD`.chomp
    formula = `git log -n1 --pretty=format:%s`.split(":").first
    file = Formula[formula].path
    marker = "Build a bottle for Linuxbrew"
    safe_system "git", "reset", "--hard", "HEAD~2"
    safe_system "git", "merge", "--squash", head
    # The argument to -i is required for BSD sed.
    safe_system "sed", "-iorig", "-e", "/^#.*: #{marker}$/d", file
    rm_f file.to_s + "orig"

    git_editor = ENV["GIT_EDITOR"]
    ENV["GIT_EDITOR"] = "sed -n -i -e 's/.*#{marker}//p;s/^    //p'"
    safe_system "git", "commit", file
    ENV["GIT_EDITOR"] = git_editor

    safe_system "git", "show" if ARGV.verbose?

    if Utils.popen_read("git", "log", "-n1", "--pretty=%s", "HEAD~1") =~ /^drop! /
      bottle_head = Utils.popen_read("git", "rev-parse", "HEAD").chomp
      safe_system "git", "reset", "--hard", "HEAD~2"
      safe_system "git", "cherry-pick", bottle_head
    end
  end
end

Homebrew.squash_bottle_pr
