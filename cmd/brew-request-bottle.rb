#:  * `brew-request-bottle` <formula>
#:    Submit a request to GitHub actions to build a bottle for Homebrew on Linux

require "utils/github"

module Homebrew
  module_function

  def formula
    @formula ||= ARGV.last.to_s
  end

  def request_bottle
    data = { event_type: "bottling", client_payload: { formula: formula }}
    url = "https://api.github.com/repos/Homebrew/linuxbrew-core/dispatches"
    GitHub.open_api(url, data: data, request_method: :POST, scopes: ["repo"])
  end
end

Homebrew.request_bottle
