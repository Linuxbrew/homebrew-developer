require "cli/parser"
require "utils/github"
require "utils/tty"
require "mktemp"

module Homebrew
  module_function

  def fetch_failed_logs_args
    Homebrew::CLI::Parser.new do
      usage_banner <<~EOS
        `fetch-failed-logs` [<options>] <formula>

        Fetch failed job logs from GitHub Actions workflow run.

        By default searches through workflow runs triggered by pull_request event.
      EOS
      flag "--tap=",
        description: "Search given tap."
      switch "--dispatched",
        description: "Search through workflow runs triggered by repository_dispatch event."
      switch "--quiet",
        description: "Print only the logs or error if occurred, nothing more."
      switch "--keep-tmp",
        description: "Retain the temporary directory containing the downloaded workflow."
      switch "--markdown",
        description: "Format the output using Markdown."
      switch :verbose
      switch :debug
      named 1
    end
  end

  def get_failed_lines(file)
    # Border lines indexes
    brew_index = -1
    pairs = []

    # Find indexes of border lines
    content = File.read(file).lines
    content.each_with_index do |line, index|
      if /.*==> .*FAILED.*/.match?(line)
        pairs << [brew_index, index]
      elsif /.*==>.* .*brew .+/.match?(line)
        brew_index = index
      end
    end

    # One of the border lines weren't found
    return [] if pairs.empty?

    # Remove timestamp prefix on every line and optionally control codes
    strip_ansi = Homebrew.args.markdown? || !Tty.color?
    content.map! do |line|
      line = Tty.strip_ansi(line) if strip_ansi
      line.split(" ")[1..-1]&.join(" ")
    end

    # Print only interesting lines
    pairs.map do |first, last|
      headline = content[first]
      contents = content[(first + 1)..last]
      [headline, contents]
    end
  end

  def find_dispatch_workflow(formula, repo)
    # If the workflow run was triggered by a repository dispatch event, then
    # check if any step name in all its jobs is equal to formula
    url = "https://api.github.com/repos/#{repo}/actions/runs?status=failure&event=repository_dispatch&per_page=100"
    GitHub.open_api(url, scopes: ["repo"])["workflow_runs"].find do |run|
      url = run["jobs_url"]
      response = GitHub.open_api(url, scopes: ["repo"])
      jobs = response["jobs"]
      jobs.find do |job|
        steps = job["steps"]
        steps.find do |step|
          step["name"].match(formula.name)
        end
      end
    end
  end

  def find_pull_request_workflow(formula, repo)
    # Find all open pull requests and the files they modify
    url = "https://api.github.com/graphql"
    owner, name = repo.split("/")
    data = {
      query: <<~EOS,
        {
          repository(name: "#{name}", owner: "#{owner}") {
            pullRequests(first: 100, states: OPEN, orderBy: {field: CREATED_AT, direction: DESC}) {
              edges {
                node {
                  number
                  files(first: 100) {
                    nodes {
                      path
                    }
                  }
                  headRefName
                }
              }
            }
          }
        }
      EOS
    }
    resp = GitHub.open_api(url, data: data, request_method: "POST")["data"]["repository"]["pullRequests"]["edges"]
    # Find pull requests that modified files we're interested in
    pr = resp.find do |r|
      r["node"]["files"]["nodes"].find do |f|
        f["path"][%r{Formula/(.+)\.rb}, 1] == formula.name
      end
    end
    # Find failed workflows associated with the pull request
    branch = pr["node"]["headRefName"]
    url = "https://api.github.com/repos/#{repo}/actions/runs?status=failure&event=pull_request&branch=#{branch}"
    GitHub.open_api(url, scopes: ["repo"])["workflow_runs"].first
  end

  def fetch_failed_logs
    fetch_failed_logs_args.parse

    formula = Homebrew.args.resolved_formulae.first
    event = Homebrew.args.dispatched? ? "repository_dispatch" : "pull_request"
    tap_name = Homebrew.args.tap || CoreTap.instance.name
    repo = Tap.fetch(tap_name).full_name

    workflow_run = if event == "repository_dispatch"
      find_dispatch_workflow formula, repo
    elsif event == "pull_request"
      find_pull_request_workflow formula, repo
    end

    odie "No workflow run matching the criteria was found" unless workflow_run

    unless Homebrew.args.quiet?
      oh1 "Workflow details:"
      puts JSON.pretty_generate(workflow_run.slice("id", "event", "status", "conclusion", "created_at"))
    end

    # Download logs zipball,
    # create a temporary directory,
    # extract it there and print
    url = workflow_run["logs_url"]
    response = GitHub.open_api(url, request_method: :GET, scopes: ["repo"], parse_json: false)
    Mktemp.new("brewlogs-#{formula.name}", retain: Homebrew.args.keep_tmp?).run do |context|
      tmpdir = context.tmpdir
      file = "#{tmpdir}/logs.zip"
      File.write(file, response)
      safe_system("unzip", "-qq", "-d", tmpdir, file)
      Dir["#{tmpdir}/*.txt"].each do |f|
        get_failed_lines(f).each do |command, contents|
          if Homebrew.args.markdown?
            puts <<~EOMARKDOWN
              <details>
              <summary>#{command}</summary>

              ```
              #{contents.join "\n"}
              ```

              </details>

            EOMARKDOWN
          else
            puts command
            puts contents
          end
        end
      end
    end
  end
end
