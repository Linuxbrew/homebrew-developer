# frozen_string_literal: true

require "cli/parser"

module Homebrew
  module_function

  def announce_args
    Homebrew::CLI::Parser.new do
      usage_banner <<~EOS
        `announce` <formulae>

        Create an announcement for new formulae.
      EOS
    end
  end

  def announce_formula(formula)
    contents = formula.path.read
    cite = contents[/# cite .*"(.*)"/, 1]

    os = case contents
    when /depends_on :linux$/
      "Linux"
    when /depends_on :macos$/
      "macOS"
    else
      "Linux and macOS"
    end

    ohai formula.full_name
    puts <<~EOS
      🎉 New formula #{formula.name} in #{formula.tap.name.capitalize} for #{os}!
      ℹ️ #{formula.desc}
      🍺 brew install #{formula.full_name}
      🏡 #{formula.homepage}
    EOS
    puts "📖 #{cite}" if cite
    puts <<~EOS
      🔬 #{formula.tap.remote}
      🐧 https://brew.sh #bioinformatics
    EOS
  end

  def announce
    args = announce_args.parse

    raise FormulaUnspecifiedError if args.named.empty?

    args.named.to_resolved_formulae.each do |formula|
      announce_formula formula
    end
  end
end
