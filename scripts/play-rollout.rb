#!/usr/bin/env ruby
# frozen_string_literal: true

# Raise, halt or resume the staged rollout on a Play production track.
#
# Not `supply --rollout`: supply's update_rollout only looks for inProgress and
# draft releases (supply/lib/supply/uploader.rb#update_rollout), so it cannot
# find a halted release to resume, and halting through it means restating the
# fraction. This reads the track with fastlane's own Play client, lets
# scripts/play_rollout.rb decide, and writes the one release back the way
# update_rollout does (track.releases = [release]); Play keeps serving the
# previous completed release to the users outside the rollout.
#
# Uses Supply::Client#tracks, #update_track, #begin_edit, #commit_current_edit!
# and #abort_current_edit, unchanged from fastlane 2.228.0 (the release
# promote.yml pins) through 2.241.1.
#
# Fails closed: every error path exits non-zero.

require 'optparse'
require_relative 'play_rollout'
require_relative '../ios/fastlane/ci_annotation'

begin
  # A plain require activates the newest fastlane installed, and the runner
  # image ships one newer than the release store-rollout.yml installs.
  pinned = ENV["PLAY_ROLLOUT_FASTLANE_VERSION"].to_s
  gem('fastlane', pinned) unless pinned.empty?
  require 'supply'
rescue LoadError => e
  warn("Error: could not load fastlane's supply library (#{e.message}).")
  warn("       Install the gem for this interpreter: gem install fastlane")
  exit(1)
end

TRACK = "production"

def fail_with(message)
  CiAnnotation.error(title: "Play rollout refused", message: message)
  warn("Error: #{message}")
  exit(1)
end

options = {}
parser = OptionParser.new do |opts|
  opts.banner = "Usage: play-rollout.rb --json-key KEY --package-name PKG --action raise|halt|resume [--fraction F]"
  opts.on("--json-key KEY", "Play service account JSON") { |v| options[:json_key] = v }
  opts.on("--package-name PKG", "Play package name") { |v| options[:package_name] = v }
  opts.on("--action ACTION", "raise, halt or resume") { |v| options[:action] = v }
  opts.on("--fraction F", "raise only: share of users, above 0 and at most 1") { |v| options[:fraction] = v }
end

begin
  parser.parse!
rescue OptionParser::ParseError => e
  fail_with("#{e.message}\n#{parser}")
end

%i[json_key package_name action].each do |key|
  fail_with("--#{key.to_s.tr('_', '-')} is required\n#{parser}") if options[key].nil?
end

package_name = options[:package_name]

begin
  Supply.config = FastlaneCore::Configuration.create(
    Supply::Options.available_options,
    {
      json_key: options[:json_key],
      package_name: package_name,
      # Fail rather than quietly commit with changes_not_sent_for_review when
      # the app holds other changes, same as promote-android.
      rescue_changes_not_sent_for_review: false
    }
  )
  client = Supply::Client.make_from_config(params: Supply.config)
  client.begin_edit(package_name: package_name)
rescue StandardError => e
  fail_with("could not open a Play edit for #{package_name}: #{e.message}")
end

committed = false
begin
  track = client.tracks(TRACK).first
  fail_with("#{package_name} has no #{TRACK} track") if track.nil?

  before = PlayRollout.describe([PlayRollout.staged_release(track.releases)])
  release = PlayRollout.apply!(track.releases, action: options[:action], fraction: options[:fraction])

  if release.nil?
    CiAnnotation.summary("#{package_name}: nothing to #{options[:action]} on #{TRACK}, #{before}")
  else
    track.releases = [release]
    client.update_track(TRACK, track)
    client.commit_current_edit!
    committed = true
    CiAnnotation.summary("#{package_name}: #{options[:action]} on #{TRACK}, #{before} -> #{PlayRollout.describe([release])}")
  end
rescue PlayRollout::Refusal => e
  fail_with("#{package_name}: #{e.message}")
rescue StandardError => e
  fail_with("could not #{options[:action]} the rollout of #{package_name}: #{e.message}")
ensure
  # Leave no open edit behind. This still runs when fail_with raises
  # SystemExit, and a cleanup failure must not mask the result.
  unless committed
    begin
      client.abort_current_edit
    rescue StandardError => e
      warn("Warning: could not delete the Play edit: #{e.message}")
    end
  end
end
