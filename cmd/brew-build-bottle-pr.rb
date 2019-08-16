#:  * `build-bottle-pr` [`--remote=<user>`] [`--limit=<num>`] [`--dry-run`] [`--verbose`] [`--force`]:
#:    Submit a pull request to build a bottle for a formula.
#:
#:    If `--remote` is passed, use the specified GitHub remote. Otherwise, use `origin`.
#:    If `--limit` is passed, make at most the specified number of PR's at once. Defaults to 10.
#:    If `--dry-run` is passed, do not actually make any PR's.
#:    If `--verbose` is passed, print extra information.
#:    If `--force` is passed, delete local and remote 'bottle-<name>' branches if they exist. Use with care.
#:    If `--browse` is passed, open a web browser for the new pull request.

require "English"

module Homebrew
  module_function

  def limit
    @limit ||= (ARGV.value("limit") || "10").to_i
  end

  def remote
    @remote ||= ARGV.value("remote") || "origin"
  end

  # Open a pull request using hub.
  def hub_pull_request(formula, remote, branch, message)
    ohai "#{formula}: Using remote '#{remote}' to submit Pull Request" if ARGV.verbose?
    safe_system "git", "push", remote, branch
    args = []
    hub_version = Version.new(Utils.popen_read("hub", "--version")[/hub version ([0-9.]+)/, 1])
    if hub_version >= Version.new("2.3.0")
      args += ["-a", ENV["HOMEBREW_GITHUB_USER"] || ENV["USER"], "-l", "bottle"]
    else
      opoo "Please upgrade hub\n  brew upgrade hub"
    end
    args << "--browse" if ARGV.include? "--browse"
    safe_system "hub", "pull-request", "-h", "#{remote}:#{branch}", "-m", message, *args
  end

  # The number of bottled formula.
  @n = 0

  def build_bottle(formula)
    @n += 1
    return ohai "#{formula}: Skipping because GitHub rate limits pull requests (limit = #{limit})." if @n > limit

    system HOMEBREW_BREW_FILE, "audit", formula.path
    opoo "Please fix audit failure for #{formula}" unless $CHILD_STATUS.success?

    title = "#{formula}: Build a bottle for Linuxbrew"
    message = <<~EOS
      #{title}

      This is an automated pull request to build a new bottle for linuxbrew-core
      based on the existing bottle block from homebrew-core.
    EOS
    oh1 "#{@n}. #{title}"

    branch = "bottle-#{formula}"
    cd tap_dir do
      unless Utils.popen_read("git", "branch", "--list", branch).empty?
        return odie "#{formula}: Branch #{branch} already exists" unless ARGV.force?

        ohai "#{formula}: Removing branch #{branch} in #{tap_dir}" if ARGV.verbose?
        safe_system "git", "branch", "-D", branch
      end
      safe_system "git", "checkout", "-b", branch, "master"
      File.open(formula.path, "r+") do |f|
        s = f.read
        f.rewind
        f.write "# #{title}\n#{s}" if ARGV.value("dry_run").nil?
      end
      if ARGV.value("dry_run").nil?
        safe_system "git", "commit", formula.path, "-m", title
        unless Utils.popen_read("git", "branch", "-r", "--list", "#{remote}/#{branch}").empty?
          return odie "#{formula}: Remote branch #{remote}/#{branch} already exists" unless ARGV.force?

          ohai "#{formula}: Removing branch #{branch} from #{remote}" if ARGV.verbose?
          safe_system "git", "push", "--delete", remote, branch
        end
        hub_pull_request formula, remote, branch, message
      end
      safe_system "git", "checkout", "master"
      safe_system "git", "branch", "-D", branch
    end
  end

  def shell(cmd)
    output = `#{cmd}`
    raise ErrorDuringExecution, cmd unless $CHILD_STATUS.success?

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
    formulae.each { |f| build_bottle f }
  end
end

Homebrew.build_bottle_pr
