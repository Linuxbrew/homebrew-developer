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
      named 1
    end
  end

  def get_failed_lines(file, args:)
    # Border lines indexes
    brew_index = -1
    pairs = []

    # Find indexes of border lines
    content = File.read(file).lines
    content.each_with_index do |line, index|
      case line
      when /.*==> .*FAILED.*/
        pairs << [brew_index, index]
      when /.*==>.* .*brew .+/
        brew_index = index
      end
    end

    # One of the border lines weren't found
    return [] if pairs.empty?

    # Remove timestamp prefix on every line and optionally control codes
    strip_ansi = args.markdown? || !Tty.color?
    content.map! do |line|
      line = Tty.strip_ansi(line) if strip_ansi
      line.split(" ")[1..]&.join(" ")
    end

    # Print only interesting lines
    pairs.map do |first, last|
      headline = content[first]
      contents = content[(first + 1)..last]
      [headline, contents]
    end
  end

  def fetch_failed_logs
    args = fetch_failed_logs_args.parse

    formula = args.resolved_formulae.first
    event = args.dispatched? ? "repository_dispatch" : "pull_request"
    tap_name = args.tap || CoreTap.instance.name
    repo = Tap.fetch(tap_name).full_name

    # First get latest workflow runs
    url = "https://api.github.com/repos/#{repo}/actions/runs?status=failure&event=#{event}&per_page=100"
    response = GitHub.open_api(url, request_method: :GET, scopes: ["repo"])
    workflow_runs = response["workflow_runs"]

    # Then iterate over them and find the matching one...
    workflow_run = workflow_runs.find do |run|
      # If the workflow run was triggered by a repository dispatch event, then
      # check if any step name in all its jobs is equal to formula
      case run["event"]
      when "repository_dispatch"
        url = run["jobs_url"]
        response = GitHub.open_api(url, request_method: :GET, scopes: ["repo"])
        jobs = response["jobs"]
        jobs.find do |job|
          steps = job["steps"]
          steps.find do |step|
            step["name"].match(formula.name)
          end
        end
      # If the workflow run was triggered by a pull request event, then
      # fetch the head commit, determine which file changed and
      # check if equal to formula
      when "pull_request"
        url = "https://api.github.com/repos/#{repo}/commits/#{run["head_sha"]}"
        response = GitHub.open_api(url, request_method: :GET, scopes: ["repo"])
        commit_files = response["files"].map { |f| f["filename"] }
        odebug "Run ##{run["id"]} - #{commit_files.join ", "}"
        commit_files.find do |file|
          file[%r{Formula/(.+)\.rb}, 1] == formula.name
        end
      end
    end

    odie "No workflow run matching the criteria was found" unless workflow_run

    unless args.quiet?
      oh1 "Workflow details:"
      puts JSON.pretty_generate(workflow_run.slice("id", "event", "status", "conclusion", "created_at"))
    end

    # Download logs zipball,
    # create a temporary directory,
    # extract it there and print
    url = workflow_run["logs_url"]
    response = GitHub.open_api(url, request_method: :GET, scopes: ["repo"], parse_json: false)
    Mktemp.new("brewlogs-#{formula.name}", retain: args.keep_tmp?).run do |context|
      tmpdir = context.tmpdir
      file = "#{tmpdir}/logs.zip"
      File.write(file, response)
      safe_system("unzip", "-qq", "-d", tmpdir, file)
      Dir["#{tmpdir}/*.txt"].each do |f|
        get_failed_lines(f, args: args).each do |command, contents|
          if args.markdown?
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
