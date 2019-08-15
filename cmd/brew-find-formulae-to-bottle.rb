module Homebrew
  module_function

  def on_master?
    Utils.popen_read("git", "rev-parse", "--abbrev-ref", "HEAD").chomp == "master"
  end

  def head_is_merge_commit?
    Utils.popen_read("git", "log", "--merges", "-1", "--format=%H").chomp == Utils.popen_read("git", "rev-parse", "HEAD").chomp
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

  def depends_on_macos?(formula)
    formula.requirements.any? { |req| (req.instance_of? MacOSRequirement) && !req.version_specified? }
  end

  def should_not_build_linux_bottle?(formula, tag)
    depends_on_macos?(formula) || formula.bottle_unneeded? || formula.bottle_disabled? || formula.bottle_specification.tag?(tag) || slug(formula.tap) == "Homebrew/homebrew-core"
  end

  formulae_to_bottle = []
  latest_merge_commit_message = Utils.popen_read("git", "log", "--format=%b", "-1").chomp

  odie "You need to be on the master branch to run this." unless on_master?
  odie "HEAD is not a merge commit." unless head_is_merge_commit?
  odie "HEAD does not have any bottles to build for new versions." unless head_has_conflict_lines?(latest_merge_commit_message)

  latest_merge_commit_message.each_line do |line|
    line.strip!
    formula = line[%r{Formula/(.*).rb$}, 1]
    formulae_to_bottle.push(formula) if formula
  end

  tag = (ARGV.value("tag") || "x86_64_linux").to_sym
  formulae_to_bottle.reject! do |formula|
    should_not_build_linux_bottle?(Formula[formula], tag)
  end

  puts formulae_to_bottle
end
