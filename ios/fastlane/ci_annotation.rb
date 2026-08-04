# Surfaces a release refusal on the GitHub Actions run page.
#
# UI.user_error! only reaches the job log. The annotation GitHub puts next to a
# failed job is "Process completed with exit code 2", which says nothing about
# which App Store Connect state stopped the release -- exactly the problem with
# the 2026-08-03 promote failures, where the reason was buried in a spaceship
# backtrace. A workflow command puts it at the top of the run instead.
module CiAnnotation
  # Workflow commands are single-line: an unescaped newline silently truncates
  # everything after it.
  # https://docs.github.com/actions/reference/workflow-commands-for-github-actions
  def self.escape(text)
    text.to_s.gsub("%", "%25").gsub("\r", "%0D").gsub("\n", "%0A")
  end

  # No-ops outside GitHub Actions so local `make promote-ios` runs stay clean.
  def self.error(title:, message:)
    return unless ENV["GITHUB_ACTIONS"]

    puts("::error title=#{escape(title)}::#{escape(message)}")

    summary = ENV["GITHUB_STEP_SUMMARY"]
    File.open(summary, "a") { |f| f.puts("- **#{title}** — #{message}") } if summary

    nil
  end
end
