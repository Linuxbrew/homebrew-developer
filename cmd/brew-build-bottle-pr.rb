#:  * `build-bottle-pr` [`--remote=<user>`] [`--tag=<tag>`] [`--limit=<num>`] [`--dry-run`] [`--verbose`] [`--force`]:
#:    Submit a pull request to build a bottle for a formula.
#:
#:    If `--remote` is passed, use the specified GitHub remote.
#:      Otherwise, check $GITHUB_USER followed by $USER.
#:    If `--tag` is passed, use the specified bottle tag. Defaults to x86_64_linux.
#:    If `--limit` is passed, make at most the specified number of PR's at once. Defaults to 10.
#:    If `--dry-run` is passed, do not actually make any PR's.
#:    If `--verbose` is passed, print extra information.
#:    If `--force` is passed, delete local and remote 'bottle-<name>' branches if they exist. Use with care.

module Homebrew
  # The GitHub slug of the {Tap}.
  # Not simply "#{user}/homebrew-#{repo}", because the slug of homebrew/core
  # may be either Homebrew/homebrew-core or Linuxbrew/homebrew-core.
  def slug(tap)
    if tap.remote.nil?
      "#{tap.user}/homebrew-#{tap.repo}"
    else
      x = tap.remote[%r{^https://github\.com/([^.]+)(\.git)?$}, 1]
      (tap.official? && !x.nil?) ? x.capitalize : x
    end
  end

  def open_pull_request?(formula)
    prs = GitHub.issues_matching(formula,
      type: "pr", state: "open", repo: slug(formula.tap))
    prs = prs.select { |pr| pr["title"].start_with? "#{formula}: " }
    if prs.any?
      ohai "#{formula}: Skipping because a PR is open"
      prs.each { |pr| puts "#{pr["title"]} (#{pr["html_url"]})" }
    end
    prs.any?
  end

  def limit
    @limit ||= (ARGV.value("limit") || "10").to_i
  end

  def determine_remote
    remotes = Utils.popen_read("git", "remote").split

    # if --remote has been specified, it has to be correct
    if !ARGV.value("remote").nil?
      return ARGV.value("remote") if remotes.include?(ARGV.value("remote"))
      onoe "No remote '#{ARGV.value("remote")}' was found in #{Dir.pwd}"
    else
      # Check GITHUB_USER and USER remotes
      [ENV["GITHUB_USER"], ENV["USER"]].each { |n| return n if remotes.include? n }

      # Nothing worked
      onoe "Please provide a valid remote name to use for Pull Requests"
      onoe "You can do so:"
      onoe " * on the command line via --remote=NAME"
      onoe " * by setting GITHUB_USER env. variable"
      onoe " * or by having a remote named as your USER env. variable"
    end

    onoe "Available remotes:"
    remotes.each do |f|
      url = `git remote get-url #{f}`.chomp
      onoe "* #{f.ljust(16)} #{url}"
    end
    exit 1
  end

  def check_remotes(formulae)
    dirs = []
    formulae.each { |f| dirs |= [f.tap.formula_dir] }
    dirs.each do |dir|
      cd dir do
        ohai "Checking that specified remote exists in #{Dir.pwd}" if ARGV.verbose?
        determine_remote
        unless `git status --porcelain 2>/dev/null`.chomp.empty?
          return ohai "Warning! You have uncommitted changes to #{Dir.pwd}"
        end
      end
    end
  end

  # The number of bottled formula.
  @n = 0

  def build_bottle(formula)
    tap = formula.tap
    tap_dir = tap.formula_dir
    remote = tap_dir.cd { determine_remote }
    odie "#{formula}: Failed to determine a remote to use for Pull Request" if remote.nil?
    tag = (ARGV.value("tag") || "x86_64_linux").to_sym
    return ohai "#{formula}: Skipping because a bottle is not needed" if formula.bottle_unneeded?
    return ohai "#{formula}: Skipping because bottles are disabled" if formula.bottle_disabled?
    return ohai "#{formula}: Skipping because it has a bottle already" if formula.bottle_specification.tag?(tag)
    return ohai "#{formula}: Skipping because #{tap} does not support Linux" if slug(tap)[/^Homebrew/] && tap.repo != "science"
    return if open_pull_request? formula

    @n += 1
    return ohai "#{formula}: Skipping because GitHub rate limits pull requests (limit = #{limit})." if @n > limit

    system HOMEBREW_BREW_FILE, "audit", "--strict", "--online", formula.path
    odie "Please fix audit failure for #{formula}" unless $?.success?

    message = "#{formula}: Build a bottle for Linuxbrew"
    oh1 "#{@n}. #{message}"

    branch = "bottle-#{formula}"
    cd tap_dir do
      unless Utils.popen_read("git", "branch", "--list", branch).empty?
        return ohai "#{formula}: Skipping because branch #{branch} already exists" unless ARGV.force?
        ohai "#{formula}: Removing branch #{branch} in #{tap_dir}" if ARGV.verbose?
        safe_system "git", "branch", "-D", branch
      end
      safe_system "git", "checkout", "-b", branch, "master"
      File.open(formula.path, "r+") do |f|
        s = f.read
        f.rewind
        f.write "# #{message}\n#{s}" unless ARGV.dry_run?
      end
      unless ARGV.dry_run?
        safe_system "git", "commit", formula.path, "-m", message
        unless Utils.popen_read("git", "branch", "-r", "--list", "#{remote}/#{branch}").empty?
          return ohai "#{formula}: Skipping because branch #{branch} already exists on remote #{remote}" unless ARGV.force?
          ohai "#{formula}: Removing branch #{branch} from #{remote}" if ARGV.verbose?
          safe_system "git", "push", "--delete", remote, branch 
        end
        safe_system "git", "push", remote, branch
        ohai "#{formula}: Using remote '#{remote}' to submit Pull Request" if ARGV.verbose?
        safe_system "hub", "pull-request",
          "-h", "#{remote}:#{branch}", "-m", message,
          *("--browse" unless ENV["BROWSER"].nil? && ENV["HOMEBREW_BROWSER"].nil?)
      end
      safe_system "git", "checkout", "master"
      safe_system "git", "branch", "-D", branch
    end
  end

  def shell(cmd)
    output = `#{cmd}`
    raise ErrorDuringExecution, cmd unless $?.success?
    output
  end

  def brew(args)
    shell "#{HOMEBREW_PREFIX}/bin/brew #{args}"
  end

  def build_bottle_pr
    odie "Please install hub (brew install hub) before proceeding" unless which "hub"
    odie "No formula has been specified" if ARGV.formulae.empty?

    formulae = ARGV.formulae
    unless ARGV.one?
      deps = brew("deps -n --union #{formulae.join " "}").split
      ohai "Adding following dependencies: #{deps.join ", "}" if ARGV.verbose? && !deps.empty?
      formulae = deps.map { |f| Formula[f] } + formulae
    end
    check_remotes formulae
    formulae.each { |f| build_bottle f }
  end
end

Homebrew.build_bottle_pr
