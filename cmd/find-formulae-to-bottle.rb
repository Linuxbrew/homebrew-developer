require "cli/parser"

module Homebrew
  module_function

  def find_formulae_to_bottle_args
    Homebrew::CLI::Parser.new do
      usage_banner <<~EOS
        `find-formulae-to-bottle` [`--verbose`]

        Find conflicting formulae from the latest merge commit.
        Outputs a list that can be passed to `brew request-bottle`.
      EOS
      switch :verbose,
             description: "Print debugging information, e.g. if a formula already has a bottle PR open."
      max_named 0
    end
  end

  def on_master?
    Utils.popen_read("git", "rev-parse", "--abbrev-ref", "HEAD").chomp == "master"
  end

  def head_is_merge_commit?
    Utils.popen_read("git", "log", "--merges", "-1", "--format=%H").chomp \
      == Utils.popen_read("git", "rev-parse", "HEAD").chomp
  end

  def head_has_conflict_lines?(commit_message)
    commit_message.include?("Conflicts:") || commit_message.include?("Formula/")
  end

  # The GitHub slug of the {Tap}.
  # Not simply tap.full_name, because the slug of homebrew/core
  # may be either Homebrew/homebrew-core or Homebrew/linuxbrew-core.
  def slug(tap)
    return tap.full_name unless tap.remote

    x = tap.remote[%r{^https://github\.com/([^.]+)(\.git)?$}, 1]
    (tap.official? && !x.nil?) ? x.capitalize : x
  end

  def should_not_build_linux_bottle?(formula, tag)
    formula.bottle_unneeded? || \
      formula.bottle_disabled? || \
      formula.bottle_specification.tag?(tag) || \
      slug(formula.tap) == "Homebrew/homebrew-core"
  end

  def reason_to_not_build_bottle(formula, tag)
    return opoo "#{formula}: Skipping because a bottle is not needed" if formula.bottle_unneeded?
    return opoo "#{formula}: Skipping because bottles are disabled" if formula.bottle_disabled?
    return opoo "#{formula}: Skipping because it has a bottle already" if formula.bottle_specification.tag?(tag)

    if slug(formula.tap) == "Homebrew/homebrew-core"
      opoo "#{formula}: Skipping because #{formula.tap} does not support Linux"
    end
  end

  def find_formulae_to_bottle
    args = find_formulae_to_bottle_args.parse

    formulae_to_bottle = []
    latest_merge_commit_message = Utils.popen_read("git", "log", "--format=%b", "-1").chomp

    odie "You need to be on the master branch to run this." unless on_master?
    odie "HEAD is not a merge commit." unless head_is_merge_commit?
    unless head_has_conflict_lines?(latest_merge_commit_message)
      odie "HEAD does not have any bottles to build for new versions."
    end

    latest_merge_commit_message.each_line do |line|
      line.strip!

      @formula = line[%r{Formula/(.*).rb$}, 1]
      formulae_to_bottle.push(@formula) if @formula
    end

    tag = "x86_64_linux".to_sym
    formulae_to_bottle.reject! do |formula|
      should_not_build_linux_bottle?(Formula[formula], tag)
    end

    reason_to_not_build_bottle(Formula[@formula], tag) if args.verbose?

    puts formulae_to_bottle
  end
end
