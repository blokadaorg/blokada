#!/usr/bin/env ruby
# Verifies the decisions store-rollout.yml makes before it touches a store:
# which Play release an action changes and how, and which App Store states a
# phased-release action or a manual release may start from.
#
# Deliberately free of credentials and of the fastlane runtime, like
# test-release-state.rb, so PR CI covers every case without a store.
require_relative "play_rollout"
require_relative "../ios/fastlane/ios_rollout"

FAILURES = []

def check(name)
  ok = begin
    yield
  rescue StandardError => e
    puts("     #{e.class}: #{e.message}")
    false
  end
  puts(ok ? "ok   #{name}" : "FAIL #{name}")
  FAILURES << name unless ok
end

# Stands in for Google::Apis::AndroidpublisherV3::TrackRelease, which the real
# client returns and update_track takes back.
Release = Struct.new(:status, :user_fraction, :version_codes, keyword_init: true)

def staged(fraction = 0.01, code = 669_001_100)
  Release.new(status: "inProgress", user_fraction: fraction, version_codes: [code.to_s])
end

def halted(fraction = 0.01, code = 669_001_100)
  Release.new(status: "halted", user_fraction: fraction, version_codes: [code.to_s])
end

def live(code = 669_001_000)
  Release.new(status: "completed", user_fraction: nil, version_codes: [code.to_s])
end

def refused?(releases, **args)
  PlayRollout.apply!(releases, **args)
  false
rescue PlayRollout::Refusal
  true
end

# --- Play ---------------------------------------------------------------------

check("raise sets the new fraction on the staged release") do
  release = PlayRollout.apply!([live, staged(0.01)], action: "raise", fraction: "0.2")
  release.status == "inProgress" && release.user_fraction == 0.2
end

check("raise to 1 completes the rollout and clears the fraction") do
  release = PlayRollout.apply!([live, staged(0.5)], action: "raise", fraction: "1")
  release.status == "completed" && release.user_fraction.nil?
end

check("raise never lowers a rollout") do
  refused?([live, staged(0.2)], action: "raise", fraction: "0.1")
end

check("raise to the current fraction is a no-op") do
  PlayRollout.apply!([live, staged(0.2)], action: "raise", fraction: "0.2").nil?
end

check("raise refuses a halted rollout") do
  refused?([live, halted(0.05)], action: "raise", fraction: "0.2")
end

["", "abc", "0", "-0.1", "1.5", "20%", nil].each do |bad|
  check("raise refuses fraction #{bad.inspect}") do
    refused?([live, staged(0.01)], action: "raise", fraction: bad)
  end
end

check("halt keeps the fraction and halts") do
  release = PlayRollout.apply!([live, staged(0.05)], action: "halt")
  release.status == "halted" && release.user_fraction == 0.05
end

check("halt of an already halted rollout is a no-op") do
  PlayRollout.apply!([live, halted(0.05)], action: "halt").nil?
end

check("resume restores the halted fraction") do
  release = PlayRollout.apply!([live, halted(0.05)], action: "resume")
  release.status == "inProgress" && release.user_fraction == 0.05
end

check("resume of a rollout that is not halted is a no-op") do
  PlayRollout.apply!([live, staged(0.05)], action: "resume").nil?
end

%w[raise halt resume].each do |action|
  check("#{action} refuses a track with no staged rollout") do
    refused?([live], action: action, fraction: "0.5")
  end

  check("#{action} refuses a track with two staged rollouts") do
    refused?([staged(0.1, 1), halted(0.1, 2)], action: action, fraction: "0.5")
  end
end

check("drafts are not rollouts") do
  draft = Release.new(status: "draft", user_fraction: nil, version_codes: ["3"])
  refused?([live, draft], action: "halt")
end

check("an unknown action is refused") do
  refused?([live, staged], action: "complete")
end

# --- App Store ----------------------------------------------------------------

check("pause starts from an active phased release") do
  IosRollout.decide("pause", version_state: "READY_FOR_DISTRIBUTION", phased_state: "ACTIVE") == :apply
end

check("pause of a paused phased release is a no-op") do
  IosRollout.decide("pause", version_state: "READY_FOR_DISTRIBUTION", phased_state: "PAUSED") == :noop
end

check("resume starts from a paused phased release") do
  IosRollout.decide("resume", version_state: "READY_FOR_DISTRIBUTION", phased_state: "PAUSED") == :apply
end

check("resume of an active phased release is a no-op") do
  IosRollout.decide("resume", version_state: "READY_FOR_DISTRIBUTION", phased_state: "ACTIVE") == :noop
end

%w[pause resume].each do |action|
  [nil, "INACTIVE", "COMPLETE"].each do |state|
    check("#{action} refuses a phased release that is #{state.inspect}") do
      IosRollout.decide(action, version_state: "READY_FOR_DISTRIBUTION", phased_state: state).is_a?(String)
    end
  end

  check("#{action} refuses when no version is live") do
    IosRollout.decide(action, version_state: nil, phased_state: nil).is_a?(String)
  end
end

check("release starts from Pending Developer Release") do
  IosRollout.decide("release", version_state: "PENDING_DEVELOPER_RELEASE", phased_state: nil) == :apply
end

check("release refuses when nothing is waiting to be released") do
  IosRollout.decide("release", version_state: nil, phased_state: nil).is_a?(String)
end

check("an unknown iOS action is refused") do
  IosRollout.decide("halt", version_state: "READY_FOR_DISTRIBUTION", phased_state: "ACTIVE").is_a?(String)
end

abort("\nFAIL: #{FAILURES.size} check(s) failed: #{FAILURES.join(', ')}") unless FAILURES.empty?
puts "\nPASS: store rollout decisions"
