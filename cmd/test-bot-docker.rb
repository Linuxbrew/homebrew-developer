#: `test-bot-docker` <formulae>...
#:
#:  Build a bottle for the specified formulae using a Docker container.
#:  See `test-bot` for further options accepted by this command.

require "cli/parser"

module Homebrew
  module_function

  def test_bot_docker_args
    Homebrew::CLI::Parser.new do
      usage_banner <<~EOS
        `test-bot-docker` <formulae>
        Build a bottle for the specified formulae using a Docker container.
        Runs `brew test-bot` with options.
      EOS
    end
  end

  def test_bot_docker
    test_bot_docker_args.parse

    if ENV["HOMEBREW_BINTRAY_USER"].nil? || ENV["HOMEBREW_BINTRAY_KEY"].nil?
      raise "Missing HOMEBREW_BINTRAY_USER or HOMEBREW_BINTRAY_KEY variables!"
    end

    formulae = Homebrew.args.named
    safe_system "docker", "run", "--name=linuxbrew-test-bot",
      "-e", "HOMEBREW_BINTRAY_USER", "-e", "HOMEBREW_BINTRAY_KEY",
      "homebrew/brew",
      "sh", "-c", <<~EOS
        git config --global user.name LinuxbrewTestBot
        git config --global user.email testbot@linuxbrew.sh
        brew tap linuxbrew/xorg
        mkdir linuxbrew-test-bot
        cd linuxbrew-test-bot
        brew test-bot #{formulae.join(" ")}
        status=$?
        ls
        brew test-bot --ci-upload --bintray-org=linuxbrew --git-name=LinuxbrewTestBot --git-email=testbot@linuxbrew.sh
        head *.json
        exit $status
      EOS

    safe_system "docker", "cp", "linuxbrew-test-bot:/home/linuxbrew/linuxbrew-test-bot", "."
    cd "linuxbrew-test-bot" do
      safe_system HOMEBREW_BREW_FILE, "bottle", "--merge", "--write", *Dir["*.json"]
    end

    oh1 "Done!"
    puts <<~EOS
      To clean up, run
        docker rm linuxbrew-test-bot
        rm -rf linuxbrew-test-bot
    EOS
  end
end
