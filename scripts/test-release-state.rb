#!/usr/bin/env ruby
# Verifies the promote state table: every App Store Connect version state maps
# to exactly one action, and anything unrecognised blocks the release.
#
# Deliberately free of credentials and of the fastlane runtime -- the table is
# a pure function so PR CI can cover every state without touching a store.
require_relative "../ios/fastlane/release_state"
require_relative "../ios/fastlane/ci_annotation"
require "stringio"
require "tmpdir"

FAILURES = []

def check(name)
  ok = yield
  puts(ok ? "ok   #{name}" : "FAIL #{name}")
  FAILURES << name unless ok
end

# CiAnnotation writes to stdout, which is also where this script reports, so
# every annotation check has to run with stdout swapped out.
def capture_stdout
  original = $stdout
  $stdout = StringIO.new
  yield
  $stdout.string
ensure
  $stdout = original
end

# Mirrors Spaceship::ConnectAPI::AppStoreVersion::AppVersionState
# (spaceship/lib/spaceship/connect_api/models/app_store_version.rb).
ALL_STATES = %w[
  ACCEPTED
  DEVELOPER_REJECTED
  IN_REVIEW
  INVALID_BINARY
  METADATA_REJECTED
  PENDING_APPLE_RELEASE
  PENDING_DEVELOPER_RELEASE
  PREPARE_FOR_SUBMISSION
  PROCESSING_FOR_DISTRIBUTION
  READY_FOR_DISTRIBUTION
  READY_FOR_REVIEW
  REJECTED
  REPLACED_WITH_NEW_VERSION
  WAITING_FOR_EXPORT_COMPLIANCE
  WAITING_FOR_REVIEW
].freeze

check("every Apple state classifies") do
  ALL_STATES.all? { |s| %i[proceed cancel blocked].include?(ReleaseState.classify(s).first) }
end

check("no version means nothing is pending") { ReleaseState.classify(nil).first == :proceed }
check("live version does not block") { ReleaseState.classify("READY_FOR_DISTRIBUTION").first == :proceed }
check("superseded version does not block") { ReleaseState.classify("REPLACED_WITH_NEW_VERSION").first == :proceed }
check("editable version proceeds") { ReleaseState.classify("PREPARE_FOR_SUBMISSION").first == :proceed }
check("developer rejected proceeds") { ReleaseState.classify("DEVELOPER_REJECTED").first == :proceed }
check("apple rejected proceeds") { ReleaseState.classify("REJECTED").first == :proceed }
check("invalid binary proceeds") { ReleaseState.classify("INVALID_BINARY").first == :proceed }
check("waiting for review cancels") { ReleaseState.classify("WAITING_FOR_REVIEW").first == :cancel }
check("in review cancels") { ReleaseState.classify("IN_REVIEW").first == :cancel }
check("pending developer release blocks") { ReleaseState.classify("PENDING_DEVELOPER_RELEASE").first == :blocked }
check("pending apple release blocks") { ReleaseState.classify("PENDING_APPLE_RELEASE").first == :blocked }
check("processing for distribution blocks") { ReleaseState.classify("PROCESSING_FOR_DISTRIBUTION").first == :blocked }
check("unknown state fails closed") { ReleaseState.classify("BRAND_NEW_APPLE_STATE").first == :blocked }

check("blocked states explain themselves") do
  (ALL_STATES + ["BRAND_NEW_APPLE_STATE"]).all? do |s|
    action, reason = ReleaseState.classify(s)
    action != :blocked || (reason.is_a?(String) && !reason.empty?)
  end
end

check("pending developer release names the manual step") do
  ReleaseState.classify("PENDING_DEVELOPER_RELEASE").last.include?("App Store Connect")
end

check("PENDING covers every non-idle state the table knows") do
  ReleaseState::PENDING.sort ==
    (ReleaseState::EDITABLE + ReleaseState::CANCELLABLE + ReleaseState::BLOCKED.keys).sort
end

check("PENDING excludes the idle states") do
  (ReleaseState::PENDING & ReleaseState::IDLE.compact).empty?
end

check("PENDING is what a promote run must ask App Store Connect for") do
  ALL_STATES.all? { |s| ReleaseState.classify(s).first == :proceed || ReleaseState::PENDING.include?(s) }
end

check("strictest prefers blocked over everything") do
  ReleaseState.strictest(%i[proceed cancel blocked]) == :blocked
end

check("strictest prefers cancel over proceed") { ReleaseState.strictest(%i[proceed cancel]) == :cancel }
check("strictest of nothing is proceed") { ReleaseState.strictest([]) == :proceed }
check("strictest of proceed alone is proceed") { ReleaseState.strictest([:proceed]) == :proceed }

# Every annotation check runs with GITHUB_STEP_SUMMARY pointed at a scratch
# file. Under CI both GITHUB_ACTIONS and GITHUB_STEP_SUMMARY are already set to
# the real job summary, and CiAnnotation appends to whatever that variable
# names -- so without this, the test suite would write fabricated release
# refusals into every PR's run page, which is exactly the misleading output
# CiAnnotation exists to prevent.
was_actions = ENV["GITHUB_ACTIONS"]
was_summary = ENV["GITHUB_STEP_SUMMARY"]

Dir.mktmpdir do |dir|
  summary = File.join(dir, "summary.md")
  ENV["GITHUB_STEP_SUMMARY"] = summary

  check("annotation is silent off CI") do
    ENV.delete("GITHUB_ACTIONS")
    capture_stdout { CiAnnotation.error(title: "T", message: "M") }.empty? && !File.exist?(summary)
  end

  check("annotation is a workflow command on CI") do
    ENV["GITHUB_ACTIONS"] = "true"
    capture_stdout { CiAnnotation.error(title: "Cannot promote", message: "boom") }.strip ==
      "::error title=Cannot promote::boom"
  end

  check("annotation escapes newlines") do
    ENV["GITHUB_ACTIONS"] = "true"
    capture_stdout { CiAnnotation.error(title: "T", message: "a\nb") }.strip == "::error title=T::a%0Ab"
  end

  check("annotation appends to the step summary") do
    ENV["GITHUB_ACTIONS"] = "true"
    capture_stdout { CiAnnotation.error(title: "T", message: "boom") }
    File.exist?(summary) && File.read(summary).include?("boom")
  end
end

ENV["GITHUB_ACTIONS"] = was_actions
ENV.delete("GITHUB_ACTIONS") if was_actions.nil?
ENV["GITHUB_STEP_SUMMARY"] = was_summary
ENV.delete("GITHUB_STEP_SUMMARY") if was_summary.nil?

check("the suite leaves the real step summary untouched") do
  ENV["GITHUB_STEP_SUMMARY"] == was_summary && ENV["GITHUB_ACTIONS"] == was_actions
end

abort("\nFAIL: #{FAILURES.size} check(s) failed: #{FAILURES.join(', ')}") unless FAILURES.empty?
puts "\nPASS: release state table classifies every state, annotations are legible"
