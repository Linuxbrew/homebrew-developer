# frozen_string_literal: true

require "dev-cmd/pull"

module Homebrew
  module_function

  ENV["HOMEBREW_BOTTLE_DOMAIN"] = "https://homebrew.bintray.com"
  ENV["HOMEBREW_FORCE_HOMEBREW_ON_LINUX"] = "1"

  def pull_macos_args
    Homebrew.pull_args
  end

  def pull_macos
    Homebrew.pull
  end

  def merge_commit?(url)
    pr_number = url[%r{/pull\/([0-9]+)}, 1]
    return false unless pr_number

    safe_system "git", "fetch", "--quiet", "homebrew", "pull/#{pr_number}/head"
    Utils.popen_read("git", "rev-list", "--parents", "-n1", "FETCH_HEAD").count(" ") > 1
  end
end
