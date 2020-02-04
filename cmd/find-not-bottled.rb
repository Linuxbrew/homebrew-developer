require "cli/parser"

module Homebrew
  module_function

  def find_not_bottled_args
    Homebrew::CLI::Parser.new do
      usage_banner <<~EOS
        `find-not-bottled` [`--must-find=`<pattern>] [`--must-not-find=`<pattern>]

        Output a list of formulae that do not have a bottle.
      EOS
      flag   "--must-find=",
             description: "Match only formulae containing the given pattern."
      flag   "--must-not-find=",
             description: "Match only formulae that do not contain the given pattern."
      max_named 0
    end
  end

  def find_not_bottled
    find_not_bottled_args.parse

    must_find = [
      Homebrew.args.must_find,
    ].compact

    must_not_find = [
      /bottle :unneeded/,
      /:x86_64_linux/,
      Homebrew.args.must_not_find,
    ].compact

    formulae = Dir["#{CoreTap.instance.path}/Formula/*"].map do |formula|
      content = File.read(formula)

      found = 0
      must_not_find.each do |pattern|
        found += 1 if content.match?(pattern)
      end

      next if found.positive?

      found = must_find.length
      must_find.each do |pattern|
        found -= 1 if content.match?(pattern)
      end

      next if found.positive?

      formula.split("/").last.delete_suffix(".rb")
    end.compact.sort

    puts formulae
  end
end
