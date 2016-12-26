#: * `travis-debug` [`--pull`]:
#:   Debug a formula on Travis CI.
#:   If `--pull` is passed, pull a fresh image from Docker Hub.

module Homebrew
  def travis_debug
    odie 'Please run "brew install docker".' unless which "docker"
    image_tag = "linuxbrew/travis"
    safe_system "docker", "pull", image_tag if ARGV.include? "--pull"
    exec "docker", "run", "-it", image_tag, "/bin/bash"
  end
end

Homebrew.travis_debug
