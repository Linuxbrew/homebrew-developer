#:  * `merge-homebrew` [`--brew`|`--core`] [<commit>]:
#:   Merge branch homebrew/master into linuxbrew/master.
#:
#:   If `--brew` is passed, merge Homebrew/brew into Linuxbrew/brew.
#:   If `--core` is passed, merge Homebrew/homebrew-core into Linuxbrew/homebrew-core.
#:   If <commit> is passed, merge only up to that upstream SHA-1 commit.

require "date"

module Homebrew
  module_function

  def editor
    return @editor if @editor
    @editor = [which_editor]
    @editor += ["-f", "+/^<<<<"] if %w[gvim nvim vim vi].include? File.basename(editor[0])
    @editor
  end

  def git
    @git ||= Utils.git_path
  end

  def git_merge_commit(sha1, fast_forward: false)
    start_sha1 = Utils.popen_read(git, "rev-parse", "HEAD").chomp
    end_sha1 = Utils.popen_read(git, "rev-parse", sha1).chomp

    puts "Start commit: #{start_sha1}"
    puts "End   commit: #{end_sha1}"

    args = []
    args << "--ff-only" if fast_forward
    system git, "merge", *args, sha1, "-m", "Merge branch homebrew/master into linuxbrew/master"
  end

  def git_merge(fast_forward: false)
    remotes = Utils.popen_read(git, "remote").split
    odie "Please add a remote with the name 'homebrew' in #{Dir.pwd}" unless remotes.include? "homebrew"
    odie "Please add a remote with the name 'origin' in #{Dir.pwd}" unless remotes.include? "origin"

    safe_system git, "pull", "--ff-only", "origin", "master"
    safe_system git, "fetch", "homebrew"
    homebrew_commits.each { |sha1| git_merge_commit sha1, fast_forward: fast_forward }
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

  def merge_brew
    oh1 "Merging Homebrew/brew into Linuxbrew/brew"
    cd(HOMEBREW_REPOSITORY) { git_merge }
  end

  def merge_core
    oh1 "Merging Homebrew/homebrew-core into Linuxbrew/homebrew-core"
    cd(CoreTap.instance.path) do
      git_merge
      conflict_files = resolve_conflicts
      safe_system git, "commit" unless conflict_files.empty?
      conflicts = conflict_files.map { |s| s.gsub(%r{^Formula/|\.rb$}, "") }
      sha1 = Utils.popen_read(git, "rev-parse", "--short", homebrew_commits.last).chomp
      message = "Merge #{Date.today} #{sha1}\n\n" + conflicts.map { |s| "+ [ ] #{s}\n" }.join
      File.write(".git/PULLREQ_EDITMSG", message)
      remote = ENV["GITHUB_USER"] || ENV["USER"]
      branch = "merge-#{Date.today}-#{sha1}"
      safe_system git, "push", remote, "HEAD:#{branch}"
      safe_system "hub", "pull-request", "-f", "-h", "#{remote}:#{branch}",
        *("--browse" unless ENV["BROWSER"].nil? && ENV["HOMEBREW_BROWSER"].nil?)
    end
  end

  def homebrew_commits
    if ARGV.named.empty?
      ["homebrew/master"]
    else
      ARGV.named.each { |sha1| safe_system git, "rev-parse", "--verify", sha1 }
      ARGV.named
    end
  end

  def merge_homebrew
    Utils.ensure_git_installed!
    repos = %w[--brew --core]
    odie "Specify one of #{repos.join " "}" if (ARGV & repos).empty?
    merge_brew if ARGV.include? "--brew"
    merge_core if ARGV.include? "--core"
  end
end

Homebrew.merge_homebrew
