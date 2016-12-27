#: `pull-bottle` <patch-source>...
#:
#:  Merge a pull request and update both the Mac and Linux bottles.
#:  See `pull` for further options accepted by this command.

module Homebrew
  module_function

  def editor
    return @editor if @editor
    @editor = [which_editor]
    @editor += ["-f", "+/^<<<<"] if editor[0] == "gvim"
  end

  def git
    @git ||= Utils.git_path
  end

  def resolve_conflicts
    conflicts = Utils.popen_read(git, "diff", "--name-only", "--diff-filter=U").split
    return conflicts if conflicts.empty?
    oh1 "Conflicts"
    puts conflicts.join(" ")
    safe_system *editor, *conflicts
    safe_system HOMEBREW_BREW_FILE, "style", *conflicts
    safe_system git, "diff", "--check"
    safe_system git, "add", "--", *conflicts
    conflicts
  end

  def pull_bottle
    start_sha1 = Utils.popen_read(git, "rev-parse", "HEAD").chomp
    puts "Start commit: #{start_sha1}"

    # Update the Linux bottle.
    safe_system HOMEBREW_BREW_FILE, "pull-linux", "--bottle", *ARGV
    linux_sha1 = Utils.popen_read(git, "rev-parse", "HEAD").chomp
    puts "Linux commit: #{linux_sha1}"

    # Update the Mac bottle.
    safe_system git, "reset", "--hard", start_sha1
    system HOMEBREW_BREW_FILE, "pull", "--bottle", *ARGV

    # Merge the Linux bottle and resolve conflicts.
    safe_system git, "checkout", "-B", "master"
    system git, "rebase", "master", linux_sha1
    system git, "rebase", "--continue" until resolve_conflicts.empty?
    safe_system git, "checkout", "-B", "master"
  end
end

Homebrew.pull_bottle
