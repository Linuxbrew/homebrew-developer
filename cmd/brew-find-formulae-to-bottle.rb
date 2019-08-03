module Homebrew
  module_function

  def head_is_merge_commit?
    `git log --merges -1 --format=%H`.chomp == `git rev-parse HEAD`.chomp &&
      `git log --oneline --format=%s -1`.chomp == "Merge branch homebrew/master into linuxbrew/master"
  end

  def head_has_conflict_lines?
    `git log --format=%b -1`.chomp.include?("Conflicts:") ||
      `git log --format=%b -1`.chomp.include?("Formula/")
  end

  def assemble_list_of_formulae_to_bottle
    `git log --format=%b -1`.each_line do |line|
      line.strip!
      next if line.empty? || line == "Conflicts:"

      @formulae_to_bottle.push(line.split('/')[1].split('.')[0])
    end
  end

  @formulae_to_bottle = []

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
