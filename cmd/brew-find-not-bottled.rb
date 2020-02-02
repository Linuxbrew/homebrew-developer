#:  * `find-not-bottled` [`--must-find=pattern`] [`--must-not-find=pattern`]:
#:    Outputs a list of formulae that do not have a bottle.
#:
#:    If `--must-find=pattern` is passed, match only formulae that contain given pattern.
#:    If `--must-not-find=pattern` is passed, match only formulae that do not contain given pattern.

module Homebrew
  must_find = [
    ARGV.value("must-find"),
  ].compact

  must_not_find = [
    /bottle :unneeded/,
    /:x86_64_linux/,
    ARGV.value("must-not-find"),
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
