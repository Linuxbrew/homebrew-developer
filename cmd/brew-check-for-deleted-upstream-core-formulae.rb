#:  * `check-for-deleted-upstream-core-formulae` [`--homebrew-repo-dir`] [`--linuxbrew-repo-dir`]:
#:    Outputs a list of formulae (with `.rb` suffix) for further `git rm` usage.
#:
#:    If no arguments are passed, use master branch of core tap as Homebrew/linuxbrew-core repo and homebrew/master branch as Homebrew/homebrew-core repo.
#:    If `--linuxbrew-repo-dir` is passed, use the specified full path to the Homebrew/linuxbrew-core repo. Otherwise, use the Homebrew on Linux standard install location.
#:    When `--homebrew-repo-dir` is passed, use the specified full path to the Homebrew/homebrew-core repo. Otherwise, use the Homebrew on Linux standard install location.

module Homebrew
  module_function

  def git?
    homebrew_repo_dir == linuxbrew_repo_dir
  end

  def linux_only?(formula)
    File.read("#{linuxbrew_repo_dir}/Formula/#{formula}").match("# tag \"linux\"")
  end

  def homebrew_repo_dir
    @homebrew_repo_dir ||= ARGV.value("homebrew-repo-dir") || CoreTap.instance.path
  end

  def linuxbrew_repo_dir
    @linuxbrew_repo_dir ||= ARGV.value("linuxbrew-repo-dir") || CoreTap.instance.path
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

  formulae_only_in_linuxbrew = linuxbrew_core_formulae - homebrew_core_formulae
  if formulae_only_in_linuxbrew.empty?
    ohai "No formulae need deleting."
  else
    ohai "These formulae need deleting from Homebrew/linuxbrew-core:"
    puts formulae_only_in_linuxbrew
  end
end
