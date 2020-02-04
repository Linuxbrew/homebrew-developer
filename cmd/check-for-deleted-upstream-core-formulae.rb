require "cli/parser"

module Homebrew
  module_function

  def check_for_deleted_upstream_core_formulae_args
    Homebrew::CLI::Parser.new do
      usage_banner <<~EOS
        `check-for-deleted-upstream-core-formulae` [`--linuxbrew-repo-dir`] [`--homebrew-repo-dir`]

        Output a list of formulae (with `.rb` suffix) for further `git rm` usage.
        If no arguments are passed, use the `master` branch of the core tap as Homebrew/linuxbrew-core,
        and the `homebrew/master` branch as Homebrew/homebrew-core.
      EOS
      flag   "--linuxbrew-repo-dir=",
             description: "Full path to the Homebrew/linuxbrew-core repo on disk."
      flag   "--homebrew-repo-dir=",
             description: "Full path to the Homebrew/homebrew-core repo on disk."
      max_named 0
    end
  end

  def git?
    homebrew_repo_dir == linuxbrew_repo_dir
  end

  def linux_only?(formula)
    File.read("#{linuxbrew_repo_dir}/Formula/#{formula}").match("# tag \"linux\"")
  end

  def homebrew_repo_dir
    @homebrew_repo_dir ||= Homebrew.args.homebrew_repo_dir || CoreTap.instance.path
  end

  def linuxbrew_repo_dir
    @linuxbrew_repo_dir ||= Homebrew.args.linuxbrew_repo_dir || CoreTap.instance.path
  end

  def homebrew_core_formulae
    quiet_system("git", "-C", homebrew_repo_dir, "checkout", "homebrew/master") if git?
    formulae = Dir.entries("#{homebrew_repo_dir}/Formula").reject! { |f| File.directory?(f) }.sort
    quiet_system("git", "-C", homebrew_repo_dir, "checkout", "-") if git?
    formulae
  end

  def linuxbrew_core_formulae
    quiet_system("git", "-C", homebrew_repo_dir, "checkout", "master") if git?
    formulae = Dir.entries("#{linuxbrew_repo_dir}/Formula").reject! { |f| File.directory?(f) || linux_only?(f) }.sort
    quiet_system("git", "-C", homebrew_repo_dir, "checkout", "-") if git?
    formulae
  end

  def check_for_deleted_upstream_core_formulae
    check_for_deleted_upstream_core_formulae_args.parse

    formulae_only_in_linuxbrew = linuxbrew_core_formulae - homebrew_core_formulae
    if formulae_only_in_linuxbrew.empty?
      ohai "No formulae need deleting."
    else
      ohai "These formulae need deleting from Homebrew/linuxbrew-core:"
      puts formulae_only_in_linuxbrew
    end
  end
end
