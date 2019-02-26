#:  * `pull_circle` [`--ci-upload`] [`--keep-going`] [`--keep-old`] patch-source
#:    Download bottles from Circle CI.
#:
#:    `--ci-upload` Upload the bottles to Bintray using `brew test-bot --ci-upload`
#:    `--keep-going` Continue  as  much  as  possible after an error
#:    `--keep-old` Build new bottles for a single platform
#:    `--overwrite` Overwrite published bottles on Bintray
#:    `--bintray-org=<bintray-org>` Upload to the given Bintray organisation.
#:    `--git-name=<git-name>` Set the Git author/committer names to the given name.
#:    `--git-email=<git-email>` Set the Git author/committer email to the given email.

require 'fileutils'

module Homebrew
  module_function

  def ci_upload(issue)
    env = { "CIRCLE_PR_NUMBER" => issue }
    bintray_org = ARGV.value("bintray-org") || "linuxbrew"
    git_name = ARGV.value("git-name") || "LinuxbrewTestBot"
    git_email= ARGV.value("git-email") || "testbot@linuxbrew.sh"
    args = []
    args << "--keep-going" if ARGV.include? "--keep-going"
    args << "--keep-old" if ARGV.include? "--keep-old"
    args << "--overwrite" if ARGV.include? "--overwrite"
    system env, HOMEBREW_BREW_FILE, "test-bot", "--ci-upload",
      "--bintray-org=#{bintray_org}", "--git-name=#{git_name}", "--git-email=#{git_email}",
      *args
  end

  # The GitHub slug of the {Tap}.
  # Not simply "#{user}/homebrew-#{repo}", because the slug of homebrew/core
  # may be either Homebrew/homebrew-core or Homebrew/linuxbrew-core.
  def slug(tap)
    if tap.remote.nil?
      "#{tap.user}/homebrew-#{tap.repo}"
    else
      x = tap.remote[%r{^https://github\.com/([^.]+)(\.git)?$}, 1]
      (tap.official? && !x.nil?) ? x.capitalize : x
    end
  end

  def pull(arg)
    if (url_match = arg.match HOMEBREW_PULL_OR_COMMIT_URL_REGEX)
      _url, user, repo, issue = *url_match
      tap = Tap.fetch(user, repo) if repo.match?(HOMEBREW_OFFICIAL_REPO_PREFIXES_REGEX)
    else
      odie "Not a GitHub pull request or commit: #{arg}"
    end

    oh1 "#{tap}##{issue}"
    api_url = "https://circleci.com/api/v1.1/project/github/#{slug tap}/latest/artifacts?branch=pull/#{issue}"
    puts api_url if ARGV.verbose?
    output, _errors, _status = curl_output api_url
    json = JSON.parse output
    odie json["message"] if json.is_a? Hash
    urls = json.map { |x| x["url"] }.uniq

    FileUtils::mkdir_p "#{tap}/#{issue}"
    FileUtils::cd "#{tap}/#{issue}" do
      urls.each do |url|
        filename = File.basename(url).gsub("%25", "%").gsub("%2B", "+").gsub("%40", "@")
        puts filename
        puts url if ARGV.verbose?
        if File.readable? filename
          opoo "Skipping existing file: #{filename}"
        else
          curl "-o", filename, url
        end
      end
      ci_upload issue if ARGV.include? "--ci-upload"
    end
  end

  def pull_circle
    ARGV.named.each { |arg| pull arg }
  end
end

Homebrew.pull_circle
