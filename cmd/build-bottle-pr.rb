require "cli/parser"
require "English"

module Homebrew
  module_function

  def build_bottle_pr_args
    Homebrew::CLI::Parser.new do
      usage_banner <<~EOS
        `build-bottle-pr` [`--remote=<user>`] [`--dry-run`] [`--verbose`] [`--tap-dir`] [`--force`]
        Submit a pull request to build a bottle for a formula.
      EOS
      flag "--remote",
           description: "Use the specified GitHub remote. Otherwise, use `origin`."
      flag "--tap-dir",
           description: "Use the specified full path to a tap. Otherwise, use the Homebrew on Linux standard install location."
      switch "--browse",
             description: "Open a web browser for the pull request."
      switch "--dry-run",
             description: "Do not actually raise any pull requests."
      switch "--force",
             description: "Delete local and remote 'bottle-<formula>' branches if they exist. Use with care."
      switch :verbose
    end
  end

  def formula
    @formula ||= ARGV.last.to_s
  end

  def remote
    @remote ||= Homebrew.args.remote || ENV["HOMEBREW_GITHUB_USER"] || origin
  end

  def tap_dir
    @tap_dir ||= Homebrew.args.tap_dir || "/home/linuxbrew/.linuxbrew/Homebrew/Library/Taps/homebrew/homebrew-core"
  end

  # Check if pull request is already opened.
  def hub_pr_already_opened?(title)
    `hub pr list --format '%t%n'`.each_line do |line|
      return true if line.chomp == title
    end
    false
  end

  # Open a pull request using hub.
  def hub_pull_request(formula, remote, branch, message)
    ohai "#{formula}: Using remote '#{remote}' to submit Pull Request" if Homebrew.args.verbose?
    safe_system "git", "push", remote, branch
    args = []
    hub_version = Version.new(Utils.popen_read("hub", "--version")[/hub version ([0-9.]+)/, 1])
    if hub_version >= Version.new("2.3.0")
      args += ["-a", ENV["HOMEBREW_GITHUB_USER"] || ENV["USER"], "-l", "bottle"]
    else
      opoo "Please upgrade hub\n  brew upgrade hub"
    end
    args << "--browse" if Homebrew.args.browse?
    safe_system "hub", "pull-request", "-b", "develop", "-h", "#{remote}:#{branch}", "-m", message, *args
  end

  def build_bottle(formula)
    title = "#{formula}: Build a bottle for Linux"
    message = <<~EOS
      #{title}

      This is an automated pull request to build a new bottle for linuxbrew-core
      based on the existing bottle block from homebrew-core.
    EOS
    oh1 title

    branch = "bottle-#{formula}"
    cd tap_dir do
      formula_path = "Formula/#{formula}.rb"
      return odie "#{formula}: PR already exists" if hub_pr_already_opened?(title)

      unless Utils.popen_read("git", "branch", "--list", branch).empty?
        return odie "#{formula}: Branch #{branch} already exists" unless Homebrew.args.force?

        ohai "#{formula}: Removing branch #{branch} in #{tap_dir}" if Homebrew.args.verbose?
        safe_system "git", "branch", "-D", branch
      end
      safe_system "git", "checkout", "-b", branch, "master"
      File.open(formula_path, "r+") do |f|
        s = f.read
        f.rewind
        f.write "# #{title}\n#{s}" unless Homebrew.args.dry_run?
      end
      unless Homebrew.args.dry_run?
        safe_system "git", "commit", formula_path, "-m", title
        unless Utils.popen_read("git", "branch", "-r", "--list", "#{remote}/#{branch}").empty?
          return odie "#{formula}: Remote branch #{remote}/#{branch} already exists" unless Homebrew.args.force?

          ohai "#{formula}: Removing branch #{branch} from #{remote}" if Homebrew.args.verbose?
          safe_system "git", "push", "--delete", remote, branch
        end
        hub_pull_request formula, remote, branch, message
      end
      safe_system "git", "checkout", "master"
      safe_system "git", "branch", "-D", branch
    end
  end

  def build_bottle_pr
    build_bottle_pr_args.parse

    ENV["HOMEBREW_DISABLE_LOAD_FORMULA"] = "1"

    odie "Please install hub (brew install hub) before proceeding" unless which "hub"
    odie "No formula has been specified" unless formula
    odie "No remote has been specified: use `--remote=origin` or `--remote=$HOMEBREW_GITHUB_USER`" unless remote

    build_bottle(formula)
  end
end
