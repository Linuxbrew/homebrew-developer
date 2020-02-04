require "cli/parser"
require "utils/github"

module Homebrew
  module_function

  def request_bottle_args
    Homebrew::CLI::Parser.new do
      usage_banner <<~EOS
        `request-bottle` <formula>

        Build a bottle for this formula with GitHub Actions.
      EOS
      max_named 1
    end
  end

  def request_bottle
    request_bottle_args.parse

    raise FormulaUnspecifiedError if Homebrew.args.named.empty?

    formula = Homebrew.args.resolved_formulae.last.full_name

    data = { event_type: "bottling", client_payload: { formula: formula } }
    url = "https://api.github.com/repos/Homebrew/linuxbrew-core/dispatches"
    GitHub.open_api(url, data: data, request_method: :POST, scopes: ["repo"])
  end
end
