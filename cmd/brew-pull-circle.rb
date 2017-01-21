#:  * `pull_circle` [`--ci-upload`] patch-source
#:    Download bottles from Circle CI.
#:
#:    `--ci-upload` Upload the bottles to Bintray using test-bot --ci-upload

module Homebrew
  def ci_upload(issue)
    env = { "CIRCLE_PR_NUMBER" => issue }
    system env, HOMEBREW_BREW_FILE, "test-bot", "--ci-upload"
  end

  def pull(arg)
    if (url_match = arg.match HOMEBREW_PULL_OR_COMMIT_URL_REGEX)
      _url, user, repo, issue = *url_match
      tap = Tap.fetch(user, repo) if repo.start_with?("homebrew-")
    else
      odie "Not a GitHub pull request or commit: #{arg}"
    end

    oh1 "#{tap}##{issue}"
    api_url = "https://circleci.com/api/v1.1/project/github/#{tap.user}/homebrew-#{tap.repo}/latest/artifacts?branch=pull/#{issue}"
    puts api_url if ARGV.verbose?
    output, _errors, _status = curl_output api_url
    json = JSON.parse output
    urls = json.map { |x| x["url"] }

    mkdir "#{tap}/#{issue}" do
      urls.each do |url|
        puts File.basename(url)
        puts url if ARGV.verbose?
        curl "-O", url
      end
      ci_upload issue if ARGV.include? "--ci-upload"
    end
  end

  def pull_circle
    ARGV.named.each { |arg| pull arg }
  end
end

Homebrew.pull_circle
