module Homebrew
  module_function

  def on_master?
    `git rev-parse HEAD` == `git rev-parse master`
  end

  def head_is_merge_commit?
    `git log --merges -1 --format=%H`.chomp == `git rev-parse HEAD`.chomp &&
      `git log --oneline --format=%s -1`.chomp == "Merge branch homebrew/master into linuxbrew/master"
  end

  def head_has_conflict_lines?
    @latest_merge_commit_message.include?("Conflicts:") ||
      @latest_merge_commit_message.include?("Formula/")
  end

  def assemble_list_of_formulae_to_bottle
    @latest_merge_commit_message.each_line do |line|
      line.strip!
      next if line.empty? || line == "Conflicts:"

      @formulae_to_bottle.push(line.split('/')[1].split('.')[0])
    end
  end

  odie "You need to be on the master branch to run this." unless on_master?

  @formulae_to_bottle = []
  @latest_merge_commit_message = `git log --format=%b -1`.chomp

  if head_is_merge_commit?
    if head_has_conflict_lines?
      assemble_list_of_formulae_to_bottle
      puts @formulae_to_bottle
    else
      puts "HEAD does not have any bottles to build for new versions, aborting."
      exit 1
    end
  else
    puts "HEAD is not a merge commit, aborting."
    exit 1
  end
end
