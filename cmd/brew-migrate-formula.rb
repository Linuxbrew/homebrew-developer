#:  * `migrate-formula` [--remote=<remote>] [--tap=<tap>] <formulae>:
#:    Migrate formulae to a new tap.
#:
#:    --remote=<remote> Use this GitHub remote, or $HOMEBREW_GITHUB_USER or $USER.
#:    --tap=<tap> Move formulae to this tap.

module Homebrew
  module_function

  def remote
    ARGV.value("remote") || ENV["HOMEBREW_GITHUB_USER"] || ENV["USER"]
  end

  def open_pull_request?(formula, tap)
    prs = GitHub.issues_for_formula(formula,
      type: "pr", state: "open", repo: tap.full_name)
    prs = prs.select { |pr| pr["title"].strip.start_with? "#{formula}: " }
    if prs.any?
      opoo "#{formula}: Skipping because a PR is open"
      prs.each { |pr| puts "#{pr["title"]} (#{pr["html_url"]})" }
    end
    prs.any?
  end

  def add_formula(formula, tap)
    dest = Pathname.new "#{tap.formula_dir}/#{formula.name}.rb"
    ohai "Migrating #{formula.full_name} to #{tap}"
    odie "Source and destination tap are the same." if formula.tap == tap
    unless Utils.popen_read("git", "-C", tap.path, "ls-files", dest).empty?
      opoo "Skipping new formula PR because formula already exists: #{dest}"
      return
    end

    if dest.exist?
      opoo "Formula already exists: #{dest}"
    else
      contents = formula.path.read
      if tap.user == "homebrew"
        contents.sub!(/^  # doi .+?\n/m, "")
      else
        contents.sub!(/^  # doi "/, "  # cite \"https://doi.org/")
      end
      contents.sub!(/^  # tag .+?\n/m, "")
      contents.sub!(/  bottle do.+?end\n\n?/m, "")
      dest.write contents
    end

    puts "Editing #{dest}"
    with_homebrew_path { safe_system *which_editor.split, dest }

    full_name = "#{tap}/#{formula.name}"
    safe_system HOMEBREW_BREW_FILE, "style", full_name unless ARGV.include? "--skip-style"
    safe_system HOMEBREW_BREW_FILE, "install", "-s", full_name unless ARGV.include? "--skip-install"
    safe_system HOMEBREW_BREW_FILE, "audit", "--new-formula", full_name unless ARGV.include? "--skip-audit"

    cd dest.dirname do
      branch = "migrate-#{formula.name}"
      safe_system "git", "checkout", "master"
      safe_system "git", "pull", "--ff-only"
      safe_system "git", "checkout", "-b", branch
      safe_system "git", "add", dest.basename
      message = "#{formula.name}: import from #{formula.tap}"
      safe_system "git", "commit", "-m", message, dest.basename
      safe_system "git", "push", remote, branch
      add_pr = Utils.popen_read "hub", "pull-request", "-a", remote, "-m", message, err: :err
      odie "hub pull-request failed" unless $CHILD_STATUS.success?
      puts add_pr
      safe_system "git", "checkout", "master"
      safe_system "git", "branch", "-D", branch
      return add_pr
    end
  end

  def remove_formula(formula, tap, add_pr)
    cd formula.tap.formula_dir do
      branch = "migrate-#{formula.name}"
      safe_system "git", "checkout", "master"
      safe_system "git", "pull", "--ff-only"
      safe_system "git", "checkout", "-b", branch
      safe_system "git", "rm", formula.path.basename
      message = "#{formula.name}: migrate to #{tap}\n"
      message += "\nSee #{add_pr}\n" if add_pr

      if tap.user == "homebrew" || tap.user == formula.tap.user
        tap_migrations_path = formula.tap.path/"tap_migrations.json"
        tap_migrations = tap_migrations_path.readlines.each &:chomp!
        tap_migrations.reject! { |s| %w[{ }].include? s }
        tap_migrations.each { |s| s.chomp! "," }
        tap_migrations << "  \"#{formula.name}\": \"#{tap}\""
        tap_migrations.sort!
        rm tap_migrations_path
        tap_migrations_path.write "{\n" + tap_migrations.join(",\n") + "\n}\n"
        safe_system "git", "-C", tap_migrations_path.dirname, "add", tap_migrations_path.basename
      end

      safe_system "git", "commit", "-m", message
      safe_system "git", "push", remote, branch
      safe_system "hub", "pull-request", "-a", remote, "-l", "migrate", "-m", message
      safe_system "git", "checkout", "master"
      safe_system "git", "branch", "-D", branch
    end
  end

  def migrate_formula(formula)
    tap = Tap.new *(ARGV.value("tap") || "homebrew/core").split("/")
    if formula.tap.to_s == tap.to_s
      opoo "#{formula.name} is already in #{tap}"
      return
    end
    return if open_pull_request? formula, tap

    add_pr = add_formula formula, tap
    remove_formula formula, tap, add_pr
  end

  def migrate_formulae
    raise FormulaUnspecifiedError if ARGV.named.empty?

    ARGV.resolved_formulae.each do |formula|
      migrate_formula formula
    end
  end
end

Homebrew.migrate_formulae
