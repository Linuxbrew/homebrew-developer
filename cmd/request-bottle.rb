# frozen_string_literal: true

require "cli/parser"
require "utils/github"

module Homebrew
  module_function

  def request_bottle_args
    Homebrew::CLI::Parser.new do
      usage_banner <<~EOS
        `request-bottle` [<options>] <formula> [<formula> ...]

        Build bottles for these formulae with GitHub Actions.
      EOS
      switch "--ignore-errors",
             description: "Make the workflow action ignore e.g., audit errors and upload bottles if they exist."
      flag "--issue=",
           description: "If specified, post a comment to this issue number if the request-bottle job fails."
    end
  end

  def head_is_merge_commit?
    Utils.popen_read(Utils::Git.path, "log", "--merges", "-1", "--format=%H").chomp \
      == Utils.popen_read(Utils::Git.path, "rev-parse", "HEAD").chomp
  end

  def git_user
    if ENV["CI"] && head_is_merge_commit?
      Utils.popen_read(Utils::Git.path, "log", "-1", "--pretty=%an")
    else
      ENV["HOMEBREW_GIT_NAME"] ||
        ENV["GIT_AUTHOR_NAME"] ||
        ENV["GIT_COMMITTER_NAME"] ||
        Utils.popen_read(Utils::Git.path, "config", "--get", "user.name")
    end
  end

  def git_email
    if ENV["CI"] && head_is_merge_commit?
      Utils.popen_read(Utils::Git.path, "log", "-1", "--pretty=%ae")
    else
      ENV["HOMEBREW_GIT_EMAIL"] ||
        ENV["GIT_AUTHOR_EMAIL"] ||
        ENV["GIT_COMMITTER_EMAIL"] ||
        Utils.popen_read(Utils::Git.path, "config", "--get", "user.email")
    end
  end

  def tap_remote(tap)
    tap.remote.match(%r{github.com[/:]([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)}i)[1]
  end

  def request_bottle
    args = request_bottle_args.parse

    raise FormulaUnspecifiedError if args.named.empty?

    user = git_user.strip
    email = git_email.strip

    odie "User not specified" if user.empty?
    odie "Email not specified" if email.empty?

    args.named.to_resolved_formulae.each do |formula|
      # Always dispatch core formulae against Homebrew/linuxbrew-core,
      # even on macOS.
      remote = if formula.tap == CoreTap.instance
        "Homebrew/linuxbrew-core"
      else
        tap_remote(formula.tap)
      end

      event_name = formula.name.to_s
      event_name += " (##{args.issue})" if args.issue

      payload = { formula:       formula.name,
                  name:          user,
                  email:         email,
                  ignore_errors: args.ignore_errors?,
                  issue:         args.issue || 0 }
      data = { event_type: event_name, client_payload: payload }
      ohai "Dispatching request to #{remote} for #{formula}"
      url = "https://api.github.com/repos/#{remote}/dispatches"
      GitHub::API.open_rest(url, data: data, request_method: :POST, scopes: ["repo"])
    end
  end
end
