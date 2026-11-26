#!/usr/bin/env ruby
# Verifies the decisions store-rollout.yml makes before it touches a store:
# which Play release an action changes and how, and which App Store states a
# phased-release action or a manual release may start from.
#
# Deliberately free of credentials and of the fastlane runtime, like
# test-release-state.rb, so PR CI covers every case without a store.
require_relative "play_rollout"
require_relative "rollout_policy"
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

{ "20%" => 0.2, " 20 % " => 0.2, "100%" => 1.0, "0.5%" => 0.005, "1.1%" => 0.011, "0.2" => 0.2,
  "1" => 1.0, "1.0" => 1.0, "1e0" => 1.0, "100.0%" => 1.0 }.each do |text, want|
  check("fraction #{text.inspect} parses as #{want}") do
    PlayRollout.parse_fraction(text) == want
  end
end

check("raise to the current fraction given as a percentage is a no-op") do
  PlayRollout.apply!([live, staged(0.011)], action: "raise", fraction: "1.1%").nil?
end

check("raise to 100% completes the rollout") do
  release = PlayRollout.apply!([live, staged(0.5)], action: "raise", fraction: "100%")
  release.status == "completed" && release.user_fraction.nil?
end

["", "abc", "0", "-0.1", "1.5", "20", "0%", "100.1%", "100.0000000000000001%", "99.9999999999999999%", "0.99999999999999999", "-5%", "%", "abc%", "1/2%", "20%%", "0x10%", nil].each do |bad|
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

# --- advance ------------------------------------------------------------------

NOW = Time.utc(2026, 12, 2, 12)

class FakeTags
  attr_reader :recorded

  def initialize(dates)
    @dates = dates
    @recorded = []
  end

  def date(name)
    @dates[name]
  end

  def record(name)
    @recorded << name
  end

  def version(build)
    "26.12.#{build}"
  end
end

def go_live(hours_ago = 25)
  { "golive/1100/android" => NOW - hours_ago * 3600 }
end

def advance(release, tags)
  RolloutPolicy.authorize_play!(release, tags: tags, now: NOW)
end

def advance_refused?(release, dates)
  tags = FakeTags.new(dates)
  advance(release, tags)
  false
rescue RolloutPolicy::Refusal
  true
end

check("advance takes 1% to 20%") { advance(staged(0.01), FakeTags.new(go_live)) == 0.2 }
check("advance takes 20% to 50%") do
  advance(staged(0.2), FakeTags.new(go_live(72).merge("ramp/1100/20" => NOW - 25 * 3600))) == 0.5
end
check("advance takes 50% to 100%") do
  advance(staged(0.5), FakeTags.new(go_live(72).merge("ramp/1100/50" => NOW - 25 * 3600))) == 1.0
end
check("advance refuses a fraction off the ladder") { advance_refused?(staged(0.05), go_live) }
check("advance refuses a halted rollout") { advance_refused?(halted(0.2), go_live) }
check("advance refuses without an approved go-live") { advance_refused?(staged(0.01), {}) }
check("advance refuses a go-live of another build") do
  advance_refused?(staged(0.01), { "golive/1099/android" => NOW - 25 * 3600 })
end
check("advance refuses within 24 hours of the go-live") { advance_refused?(staged(0.01), go_live(23)) }
check("advance refuses within 24 hours of the last step") do
  advance_refused?(staged(0.2), go_live(72).merge("ramp/1100/20" => NOW - 3600))
end
check("advance refuses a step raised by hand, with no record") { advance_refused?(staged(0.2), go_live(72)) }
check("advance refuses when the tags cannot be read") do
  tags = FakeTags.new({})
  tags.define_singleton_method(:date) { |_name| raise RolloutPolicy::Refusal, "git fetch failed" }
  begin
    advance(staged(0.01), tags)
    false
  rescue RolloutPolicy::Refusal
    true
  end
end
check("advance refuses within 24 hours of a resume at 1%") do
  advance_refused?(staged(0.01), go_live(72).merge("ramp/1100/1" => NOW - 3600))
end
check("an iOS-only go-live does not approve Android") do
  advance_refused?(staged(0.01), { "golive/1100/ios" => NOW - 25 * 3600 })
end
check("a step on the ladder is recorded") do
  tags = FakeTags.new({})
  RolloutPolicy.record_step!(staged(0.2), tags: tags)
  tags.recorded == ["ramp/1100/20"]
end
check("a completed rollout is recorded as 100%") do
  tags = FakeTags.new({})
  RolloutPolicy.record_step!(Release.new(status: "completed", user_fraction: nil, version_codes: ["669001100"]), tags: tags)
  tags.recorded == ["ramp/1100/100"]
end
check("a fraction off the ladder is not recorded") do
  tags = FakeTags.new({})
  RolloutPolicy.record_step!(staged(0.05), tags: tags)
  tags.recorded.empty?
end

IOS_GO_LIVE = { "golive/1100/ios" => NOW - 3600 }.freeze

def ios_refused?(version, phased, dates, binary: nil)
  build = version[/\d+\z/].to_i
  RolloutPolicy.authorize_ios!(version_string: version, build_version: binary || (669_000_000 + build).to_s,
                               phased_state: phased, tags: FakeTags.new(dates))
  false
rescue RolloutPolicy::Refusal
  true
end

check("iOS advance releases an approved phased version") { !ios_refused?("26.12.1100", "INACTIVE", IOS_GO_LIVE) }
check("iOS advance refuses a version without a phased release") { ios_refused?("26.12.1100", nil, IOS_GO_LIVE) }
check("iOS advance refuses a version without an approved go-live") { ios_refused?("26.12.1101", "INACTIVE", IOS_GO_LIVE) }
check("an Android-only go-live does not approve iOS") { ios_refused?("26.12.1100", "INACTIVE", go_live) }
check("iOS advance refuses a version build N was not tagged with") do
  ios_refused?("27.1.1100", "INACTIVE", IOS_GO_LIVE)
end
check("iOS advance refuses a version carrying another build's binary") do
  ios_refused?("26.12.1100", "INACTIVE", IOS_GO_LIVE, binary: "669001099")
end
check("iOS advance refuses a version with no binary") do
  ios_refused?("26.12.1100", "INACTIVE", IOS_GO_LIVE, binary: "")
end

# --- GitTags against a real git remote ---------------------------------------

require "tmpdir"

def sh(dir, *args, env: {})
  out, err, status = Open3.capture3(env, "git", "-c", "tag.gpgSign=false", "-c", "commit.gpgSign=false",
                                    "-c", "init.defaultBranch=main", *args, chdir: dir)
  raise "git #{args.join(' ')}: #{err}" unless status.success?

  out.strip
end

CI = { "GIT_COMMITTER_NAME" => "blokada-ci", "GIT_COMMITTER_EMAIL" => "ci@blokada.org",
       "GIT_AUTHOR_NAME" => "blokada-ci", "GIT_AUTHOR_EMAIL" => "ci@blokada.org" }.freeze
SOMEONE = CI.transform_values { |v| v.sub("blokada-ci", "someone").sub("ci@", "someone@") }.freeze

# A remote with build/1100 at one commit and a later commit on main, and a
# shallow checkout of main without tags, as actions/checkout leaves it.
def with_remote
  Dir.mktmpdir do |root|
    origin = File.join(root, "origin.git")
    seed = File.join(root, "seed")
    checkout = File.join(root, "checkout")
    sh(root, "init", "--quiet", "--bare", origin)
    sh(root, "init", "--quiet", seed)
    sh(seed, "commit", "--quiet", "--allow-empty", "-m", "build 1100", env: CI)
    sh(seed, "tag", "-a", "build/1100", "-m", "26.12.1100", env: CI)
    sh(seed, "commit", "--quiet", "--allow-empty", "-m", "later", env: CI)
    sh(seed, "push", "--quiet", origin, "main", "refs/tags/build/1100")
    sh(root, "clone", "--quiet", "--depth", "1", "--no-tags", "file://#{origin}", checkout)
    yield RolloutPolicy::GitTags.new(dir: checkout), seed, origin
  end
end

def git_refused?
  yield
  false
rescue RolloutPolicy::Refusal
  true
end

check("a recorded tag is read back with its date") do
  with_remote do |tags, _, _|
    tags.record("golive/1100/android")
    (Time.now - tags.date("golive/1100/android")).abs < 60
  end
end
check("a recorded tag points at its build's commit, not the checkout") do
  with_remote do |tags, seed, origin|
    tags.record("ramp/1100/20")
    sh(seed, "ls-remote", origin, "refs/tags/ramp/1100/20^{}").split.first == sh(seed, "rev-parse", "build/1100^{commit}")
  end
end
check("recording an existing tag moves it") do
  with_remote do |tags, seed, origin|
    tags.record("ramp/1100/20")
    before = sh(seed, "ls-remote", origin, "refs/tags/ramp/1100/20").split.first
    sleep 1.1
    tags.record("ramp/1100/20")
    sh(seed, "ls-remote", origin, "refs/tags/ramp/1100/20").split.first != before
  end
end
check("a missing tag has no date") { with_remote { |tags, _, _| tags.date("golive/1100/android").nil? } }
check("the version is build N's tag subject") { with_remote { |tags, _, _| tags.version(1100) == "26.12.1100" } }
check("a build without its tag is refused") do
  with_remote { |tags, _, _| git_refused? { tags.record("ramp/1101/20") } }
end
check("a lightweight tag is refused") do
  with_remote do |tags, seed, origin|
    sh(seed, "tag", "golive/1100/android", "build/1100^{commit}")
    sh(seed, "push", "--quiet", origin, "refs/tags/golive/1100/android")
    git_refused? { tags.date("golive/1100/android") }
  end
end
check("a tag made by someone other than blokada-ci is refused") do
  with_remote do |tags, seed, origin|
    sh(seed, "tag", "-a", "golive/1100/android", "-m", "x", "build/1100^{commit}", env: SOMEONE)
    sh(seed, "push", "--quiet", origin, "refs/tags/golive/1100/android")
    git_refused? { tags.date("golive/1100/android") }
  end
end
check("a tag at another commit than its build is refused") do
  with_remote do |tags, seed, origin|
    sh(seed, "tag", "-a", "golive/1100/android", "-m", "x", "main", env: CI)
    sh(seed, "push", "--quiet", origin, "refs/tags/golive/1100/android")
    git_refused? { tags.date("golive/1100/android") }
  end
end
check("an unreachable remote is refused, not read as a missing tag") do
  with_remote do |_, _, origin|
    FileUtils.rm_rf(origin)
    git_refused? { RolloutPolicy::GitTags.new(dir: Dir.pwd, remote: "file://#{origin}").date("golive/1100/android") }
  end
end

abort("\nFAIL: #{FAILURES.size} check(s) failed: #{FAILURES.join(', ')}") unless FAILURES.empty?
puts "\nPASS: store rollout decisions"
