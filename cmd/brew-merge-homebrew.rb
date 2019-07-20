#:  * `merge-homebrew` [`--core`|`--tap=user/repo`] [<commit>]:
#:   Merge branch homebrew/master into origin/master.
#:
#:   If `--core` is passed, merge Homebrew/homebrew-core into Homebrew/linuxbrew-core.
#:   If `--tap=user/repo` is passed, merge Homebrew/tap into user/tap.
#:   If `--skip-style` is passed, skip running brew style.
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

  def mergetool?
    @mergetool = system "git config merge.tool >/dev/null 2>/dev/null" if @mergetool.nil?
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
    if mergetool?
      safe_system "git", "mergetool"
    else
      safe_system *editor, *conflicts
    end
    safe_system HOMEBREW_BREW_FILE, "style", *conflicts unless ARGV.include? "--skip-style"
    safe_system git, "diff", "--check"
    safe_system git, "add", "--", *conflicts
    conflicts
  end

  def merge_tap(tap)
    oh1 "Merging Homebrew/#{tap.repo} into #{tap.name.capitalize}"
    cd(Tap.fetch(tap).path) { git_merge }
  end

  # Open a pull request using hub.
  def hub_pull_request(branch, message)
    hub_version = Utils.popen_read("hub", "--version")[/hub version ([0-9.]+)/, 1]
    odie "Please install hub\n  brew install hub" unless hub_version
    odie "Please upgrade hub\n  brew upgrade hub" if Version.new(hub_version) < "2.3.0"
    remote = ENV["HOMEBREW_GITHUB_USER"] || ENV["USER"]
    safe_system git, "push", remote, "HEAD:#{branch}"
    safe_system "hub", "pull-request", "-f", "-h", "#{remote}:#{branch}", "-m", message,
      "-a", remote, "-l", "merge",
      *("--browse" if ARGV.include? "--browse")
  end

  def merge_core
    oh1 "Merging Homebrew/homebrew-core into Homebrew/linuxbrew-core"
    cd(CoreTap.instance.path) do
      git_merge
      conflict_files = resolve_conflicts
      safe_system git, "commit" unless conflict_files.empty?
      conflicts = conflict_files.map { |s| s.gsub(%r{^Formula/|\.rb$}, "") }
      sha1 = Utils.popen_read(git, "rev-parse", "--short", homebrew_commits.last).chomp
      branch = "merge-#{Date.today}-#{sha1}"
      message = "Merge #{Date.today} #{sha1}\n\nMerge Homebrew/homebrew-core into Homebrew/linuxbrew-core\n\n" + conflicts.map { |s| "+ [ ] #{s}\n" }.join
      hub_pull_request branch, message
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
    tap = ARGV.value "tap"
    repos = ARGV
    odie "Specify --core as an argument to merge homebrew-core" if !tap && repos.empty?
    merge_core if ARGV.include? "--core"
    merge_tap tap if tap
  end
end

Homebrew.merge_homebrew
