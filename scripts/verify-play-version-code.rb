#!/usr/bin/env ruby
# frozen_string_literal: true

# Fail unless a Play store version code already exists as an uploaded artifact.
#
# `make promote-android` releases an existing build to alpha/beta by writing
# the target track with `--version_codes_to_retain`, without uploading
# anything. If the code was never uploaded, Play rejects the track update with
# a generic error that says nothing about where the code was supposed to come
# from. Check it up front so the failure names the code and the run that should
# have produced it.
#
# This uses fastlane's own Play client -- Supply::Client#aab_version_codes and
# #apks_version_codes (supply/lib/supply/client.rb:268-283) are exactly this
# read, and Supply::Client.make_from_config (client.rb:16-20) does the
# service-account auth. The check has to finish before supply opens its own
# edit, which is why it opens and deletes a throwaway edit of its own rather
# than sharing one.
#
# Fails closed: every error path exits non-zero.

require 'optparse'

begin
  require 'supply'
rescue LoadError => e
  warn("Error: could not load fastlane's supply library (#{e.message}).")
  warn("       This script runs under `ruby` from PATH, which is a different install")
  warn("       from the `fastlane` command `make promote-android` calls -- Homebrew's")
  warn("       fastlane formula wraps a private GEM_HOME and does not satisfy this.")
  warn("       Install the gem for this interpreter: gem install fastlane")
  exit(1)
end

def fail_with(message)
  warn("Error: #{message}")
  exit(1)
end

options = {}
parser = OptionParser.new do |opts|
  opts.banner = "Usage: verify-play-version-code.rb --json-key KEY --package-name PKG --version-code CODE"
  opts.on("--json-key KEY", "Play service account JSON") { |v| options[:json_key] = v }
  opts.on("--package-name PKG", "Play package name") { |v| options[:package_name] = v }
  opts.on("--version-code CODE", Integer,
          "Store version code (VERSION_CODE_OFFSET + raw build number)") { |v| options[:version_code] = v }
end

begin
  parser.parse!
rescue OptionParser::ParseError => e
  fail_with("#{e.message}\n#{parser}")
end

%i[json_key package_name version_code].each do |key|
  fail_with("--#{key.to_s.tr('_', '-')} is required\n#{parser}") if options[key].nil?
end

package_name = options[:package_name]
version_code = options[:version_code]

# Build a real supply configuration rather than a bare hash, so the client gets
# supply's own defaults (notably :timeout) and its json_key verify_block, which
# checks the file exists and is JSON before any network call.
begin
  Supply.config = FastlaneCore::Configuration.create(
    Supply::Options.available_options,
    {
      json_key: options[:json_key],
      package_name: package_name
    }
  )
rescue StandardError => e
  fail_with("could not configure the Play client: #{e.message}")
end

# Each stage gets its own rescue so the message names the stage that actually
# failed. Wrapping all three together reports an auth rejection as "could not
# list uploaded artifacts", which points at the wrong thing.
begin
  client = Supply::Client.make_from_config(params: Supply.config)
rescue StandardError => e
  fail_with("could not authenticate with Play for #{package_name}: #{e.message}")
end

begin
  client.begin_edit(package_name: package_name)
rescue StandardError => e
  fail_with("could not open a Play edit for #{package_name}: #{e.message}")
end

codes = nil
begin
  codes = (client.aab_version_codes + client.apks_version_codes).map(&:to_i)
rescue StandardError => e
  fail_with("could not list uploaded artifacts for #{package_name}: #{e.message}")
ensure
  # Read-only check: never leave the throwaway edit hanging around. A failure to
  # clean it up must not mask the result of the check itself. This still runs
  # when fail_with above raises SystemExit.
  begin
    client.abort_current_edit
  rescue StandardError => e
    warn("Warning: could not delete the throwaway Play edit: #{e.message}")
  end
end

unless codes.include?(version_code)
  newest = codes.empty? ? "none" : codes.max
  fail_with(
    "store version code #{version_code} has never been uploaded to #{package_name}, " \
    "so there is nothing to release.\n" \
    "       A build only becomes releasable once a ci-release run has uploaded " \
    "it to the internal track.\n" \
    "       Check that the ci-release run for this build number finished " \
    "successfully.\n" \
    "       Highest uploaded code for this package: #{newest}."
  )
end

puts("store version code #{version_code} is uploaded to #{package_name}")
