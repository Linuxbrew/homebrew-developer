#:  * `announce` <formulae>:
#:    Create an announcement for new formulae.

module Homebrew
  module_function

  def announce_formula(formula)
    contents = formula.path.read
    cite = contents[/# cite .*"(.*)"/, 1]

    os = if contents =~ /depends_on :linux$/
      "Linux"
    elsif contents =~ /depends_on :macos$/
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
      🐧 http://linuxbrew.sh @linuxbrew #bioinformatics
    EOS
  end

  def announce_formulae
    raise FormulaUnspecifiedError if ARGV.named.empty?

    ARGV.resolved_formulae.each do |formula|
      announce_formula formula
    end
  end
end

Homebrew.announce_formulae
