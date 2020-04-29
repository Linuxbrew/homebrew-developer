require "cli/parser"
require "date"

module Homebrew
  module_function

  def merge_homebrew_args
    Homebrew::CLI::Parser.new do
      usage_banner <<~EOS
        `merge-homebrew` (`--core` | `--tap=`<user>`/`<repo>) [<options>] [<commit>]

        Merge branch homebrew/master into origin/master.
        If <commit> is passed, merge only up to that upstream SHA-1 commit.
      EOS
      switch "--core",
             description: "Merge Homebrew/homebrew-core into Homebrew/linuxbrew-core."
      flag   "--tap=",
             description: "Merge Homebrew/tap into user/tap."
      switch "--browse",
             description: "Open a web browser for the pull request."
      switch "--skip-style",
             description: "Skip running `brew style` on merged formulae."
      conflicts "--core", "--tap"
      max_named 1
    end
  end

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
    puts "  End commit: #{end_sha1}"

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
      safe_system(*editor, *conflicts)
    end
    system HOMEBREW_BREW_FILE, "style", "--fix", *conflicts unless Homebrew.args.skip_style?
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
    odie "Please install hub:\n  brew install hub" unless hub_version
    odie "Please upgrade hub:\n  brew upgrade hub" if Version.new(hub_version) < "2.3.0"
    remote = ENV["HOMEBREW_GITHUB_USER"] || ENV["USER"]
    safe_system git, "push", remote, "HEAD:#{branch}"
    safe_system "hub", "pull-request", "-f", "-h", "#{remote}:#{branch}", "-m", message,
      "-a", remote, "-l", "merge",
      *("--browse" if Homebrew.args.browse?)
  end

  def added_files_after_merge
    Utils.popen_read(git, "diff", "--name-only", "--diff-filter=A", "HEAD~1..HEAD").split
  end

  def deleted_files_after_merge
    Utils.popen_read(git, "diff", "--name-only", "--diff-filter=D", "HEAD~1..HEAD").split
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
      merge_title = "Merge Homebrew/homebrew-core into Homebrew/linuxbrew-core"
      message = "Merge #{Date.today} #{sha1}\n\n#{merge_title}\n\n" + conflicts.map { |s| "+ [ ] #{s}\n" }.join

      added_files = added_files_after_merge
      unless added_files.empty?
        ohai "Added formulae"
        puts added_files
      end

      deleted_files = deleted_files_after_merge
      unless deleted_files.empty?
        ohai "Deleted formulae"
        puts deleted_files
      end

      safe_system("brew", "readall", "--aliases")

      hub_pull_request branch, message
    end
  end

  def homebrew_commits
    if Homebrew.args.named.empty?
      ["homebrew/master"]
    else
      Homebrew.args.named.each { |sha1| safe_system git, "rev-parse", "--verify", sha1 }
      Homebrew.args.named
    end
  end

  def merge_homebrew
    merge_homebrew_args.parse

    Utils.ensure_git_installed!

    if !Homebrew.args.core? && !Homebrew.args.tap
      odie "Specify --core as an argument to merge homebrew-core or --tap to merge to user/tap"
    elsif Homebrew.args.core?
      merge_core
    elsif Homebrew.args.tap
      merge_tap Homebrew.args.tap
    end
  end
end
