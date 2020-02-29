require "cli/parser"
require "utils/github"

module Homebrew
  module_function

  def request_bottle_args
    Homebrew::CLI::Parser.new do
      usage_banner <<~EOS
        `request-bottle` <formula> [<formula> ...]

        Build bottles for these formulae with GitHub Actions.
      EOS
      switch "--ignore-errors",
             description: "Instruct the workflow action to ignore e.g., audit errors and upload bottles if they exist."
    end
  end

  def head_is_merge_commit?
    Utils.popen_read(Utils.git_path, "log", "--merges", "-1", "--format=%H").chomp == Utils.popen_read(Utils.git_path, "rev-parse", "HEAD").chomp
  end

  def git_user
    if ENV["CI"] && head_is_merge_commit?
      Utils.popen_read(Utils.git_path, "log", "-1", "--pretty=%an")
    else
      ENV["HOMEBREW_GIT_NAME"] || ENV["GIT_AUTHOR_NAME"] || ENV["GIT_COMMITTER_NAME"] || Utils.popen_read(Utils.git_path, "config", "--get", "user.name")
    end
  end

  def git_email
    if ENV["CI"] && head_is_merge_commit?
      Utils.popen_read(Utils.git_path, "log", "-1", "--pretty=%ae")
    else
      ENV["HOMEBREW_GIT_EMAIL"] || ENV["GIT_AUTHOR_EMAIL"] || ENV["GIT_COMMITTER_EMAIL"] || Utils.popen_read(Utils.git_path, "config", "--get", "user.email")
    end
  end

  def request_bottle
    request_bottle_args.parse

    raise FormulaUnspecifiedError if Homebrew.args.named.empty?

    user = git_user.strip
    email = git_email.strip

    odie "User not specified" if user.empty?
    odie "Email not specified" if email.empty?

    Homebrew.args.resolved_formulae.each do |formula|
      payload = { formula: formula.name, name: user, email: email, ignore_errors: Homebrew.args.ignore_errors? }
      data = { event_type: "bottling", client_payload: payload }
      url = "https://api.github.com/repos/Homebrew/linuxbrew-core/dispatches"
      GitHub.open_api(url, data: data, request_method: :POST, scopes: ["repo"])
    end
  end
end
