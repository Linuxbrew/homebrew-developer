require "style"
require "cli/parser"

module Homebrew
  module_function

  def is_uses_from_macos_args
    Homebrew::CLI::Parser.new do
      usage_banner <<~EOS
        `is-uses-from-macos` [<options>] <formula>

        Check if formula should be put in uses_from_macos stanza.
      EOS
    end
  end

  def is_uses_from_macos
    is_uses_from_macos_args.parse

    raise FormulaUnspecifiedError if Homebrew.args.named.empty?

    Homebrew.install_bundler_gems!
    require "rubocop"
    require "rubocops/uses_from_macos"
    include RuboCop::Cop::FormulaAudit

    formula = Homebrew.args.resolved_formulae.first
    allowed = UsesFromMacos::ALLOWED_USES_FROM_MACOS_DEPS

    ohai allowed.include?(formula.name)
  end
end
