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

  formulae_to_bottle = []
  latest_merge_commit_message = Utils.popen_read("git", "log", "--format=%b", "-1").chomp

  odie "You need to be on the master branch to run this." unless on_master?
  odie "HEAD is not a merge commit." unless head_is_merge_commit?
  odie "HEAD does not have any bottles to build for new versions." unless head_has_conflict_lines?(latest_merge_commit_message)

  latest_merge_commit_message.each_line do |line|
    line.strip!
    next if line.empty? || line == "Conflicts:"

    formulae_to_bottle.push(line.split('/')[1].split('.')[0])
  end

  puts formulae_to_bottle
end
