#:  * `check-for-deleted-upstream-core-formulae` [`--homebrew-repo-dir`] [`--linuxbrew-repo-dir`]:
#:    Outputs a list of formulae (with `.rb` suffix) for further `git rm` usage.
#:
#:    If `--linuxbrew-repo-dir` is passed, use the specified full path to the Homebrew/linuxbrew-core tap. Otherwise, use the Homebrew on Linux standard install location.
#:    When `--homebrew-repo-dir` is passed, use the specified full path to the Homebrew/homebrew-core repo, or the `HOMEBREW_REPO_DIR` envvar.

module Homebrew
  module_function

  def homebrew_repo_dir
    @homebrew_repo_dir ||= ARGV.value("homebrew-repo-dir") || ENV["HOMEBREW_REPO_DIR"]
  end

  def linuxbrew_repo_dir
    @linuxbrew_repo_dir ||= ARGV.value("linuxbrew-repo-dir") || "/home/linuxbrew/.linuxbrew/Homebrew/Library/Taps/homebrew/homebrew-core"
  end

  def linux_only?(formula)
    File.open("#{linuxbrew_repo_dir}/Formula/#{formula}").grep("# tag \"linux").any?
  end

  def homebrew_core_formulae
    @homebrew_core_formulae ||= Dir.entries("#{homebrew_repo_dir}/Formula").reject! { |f| File.directory?(f) }.sort
  end

  def linuxbrew_core_formulae
    @linuxbrew_core_formulae ||= Dir.entries("#{linuxbrew_repo_dir}/Formula").reject! { |f| File.directory?(f) }.sort
  end

  def formulae_only_in_linuxbrew
    [linuxbrew_core_formulae - homebrew_core_formulae].flatten.reject! { |formula| linux_only?(formula) }
  end

  odie "Specify the location of Homebrew/homebrew-core on your machine with `--homebrew-repo-dir` or `HOMEBREW_REPO_DIR`." unless homebrew_repo_dir

  if formulae_only_in_linuxbrew
    ohai "These formulae need deleting from Homebrew/linuxbrew-core:"
    formulae_only_in_linuxbrew.each { |formula| puts formula }
  else
    ohai "No formulae need deleting."
  end
end
