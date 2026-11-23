# frozen_string_literal: true

# When store-rollout.yml's `advance` may move Blokada 6 without a second human
# approval. Approving the promote approves the whole ramp, so `advance` only
# takes the next fixed step of a build with an approved go-live. Everything it
# cannot prove is refused; `raise` and `release` stay behind store-live.
#
# The proof is in tags, because workflow runs can disappear from GitHub:
#   golive/N/<store>  pushed by promote.yml after an approved go-live reached
#                     that store (android or ios)
#   ramp/N/<pct>      refreshed just before each store write that lands on that
#                     step, by advance, raise or resume, so its date is when the
#                     step last changed
require "json"
require "net/http"
require "time"
require "uri"

module RolloutPolicy
  class Refusal < StandardError; end

  LADDER = [0.01, 0.2, 0.5, 1.0].freeze
  MIN_STEP_SECONDS = 24 * 60 * 60
  PLAY_CODE_OFFSET = 669_000_000

  def self.next_fraction(current)
    index = LADDER.index { |step| current && (step - current).abs < 1e-9 }
    raise Refusal, "the rollout is at #{current.inspect}, which is not a step of #{LADDER.inspect}" if index.nil?
    raise Refusal, "the rollout is already complete" if index == LADDER.size - 1

    LADDER[index + 1]
  end

  def self.percent(fraction)
    (fraction * 100).round
  end

  # Returns the fraction to raise a Play release to, or raises Refusal.
  def self.authorize_play!(release, tags:, now:)
    raise Refusal, "the rollout is #{release.status}, and only an inProgress rollout can advance" unless release.status == "inProgress"

    build = play_build(release)
    target = next_fraction(release.user_fraction)
    go_live = tags.date("golive/#{build}/android")
    raise Refusal, "build #{build} has no approved Android go-live (golive/#{build}/android)" if go_live.nil?

    current_step = percent(release.user_fraction)
    step_tag = "ramp/#{build}/#{current_step}"
    last = [tags.date(step_tag), current_step == 1 ? go_live : nil].compact.max
    raise Refusal, "no record of the #{current_step}% step (#{step_tag}); continue this ramp by hand" if last.nil?

    wait = MIN_STEP_SECONDS - (now - last)
    if wait.positive?
      raise Refusal, "the last step was at #{last.utc.iso8601}; the next is allowed in #{(wait / 3600).ceil} hour(s)"
    end

    target
  end

  # Records the step a Blokada 6 release is about to be written at. A fraction
  # off the ladder has no step, and advance then refuses it.
  def self.record_step!(release, tags:)
    fraction = release.status == "completed" ? 1.0 : release.user_fraction
    return unless LADDER.any? { |step| fraction && (step - fraction).abs < 1e-9 }

    tags.record("ramp/#{play_build(release)}/#{percent(fraction)}")
  end

  def self.play_build(release)
    codes = release.version_codes || []
    raise Refusal, "expected one version code, got #{codes.inspect}" unless codes.size == 1

    build = Integer(codes.first.to_s, 10) - PLAY_CODE_OFFSET
    raise Refusal, "version code #{codes.first} is not a Blokada 6 build" unless build.positive?

    build
  rescue ArgumentError, TypeError
    raise Refusal, "could not read a build number from version code #{codes.first.inspect}"
  end

  # An App Store version waits in Pending Developer Release whether or not the
  # promote went live, so the go-live tag is what approves releasing it.
  def self.authorize_ios!(version_string:, phased_state:, tags:)
    build = version_string.to_s[/\A\d+\.\d+\.(\d+)\z/, 1]
    raise Refusal, "could not read a build number from version #{version_string.inspect}" if build.nil?
    if phased_state.nil?
      raise Refusal, "#{version_string} has no phased release, so it would reach every user at once. " \
                     "Use `release`, which waits for a maintainer."
    end
    if tags.date("golive/#{build}/ios").nil?
      raise Refusal, "build #{build} has no approved iOS go-live (golive/#{build}/ios)"
    end

    nil
  end

  # Reads and creates annotated tags with the run's token. Any failure refuses.
  class GitHubTags
    def initialize(repository: ENV["GITHUB_REPOSITORY"], token: ENV["GITHUB_TOKEN"], sha: ENV["GITHUB_SHA"])
      if [repository, token, sha].any? { |value| value.to_s.empty? }
        raise Refusal, "GITHUB_REPOSITORY, GITHUB_TOKEN and GITHUB_SHA are required"
      end

      @repository = repository
      @token = token
      @sha = sha
    end

    # The tag's creation time, nil when it does not exist. A lightweight tag
    # has no time and is not proof of anything, so it is refused.
    def date(name)
      response = call(Net::HTTP::Get, "git/ref/tags/#{name}")
      return nil if response.is_a?(Net::HTTPNotFound)

      ref = parse(response, name)
      object = ref.fetch("object")
      raise Refusal, "tag #{name} is not annotated" unless object["type"] == "tag"

      tag = parse(call(Net::HTTP::Get, "git/tags/#{object.fetch('sha')}"), name)
      Time.iso8601(tag.fetch("tagger").fetch("date"))
    rescue KeyError, ArgumentError => e
      raise Refusal, "could not read tag #{name}: #{e.message}"
    end

    # Creates the tag, or moves it to a new tag object dated now.
    def record(name)
      tag = parse(call(Net::HTTP::Post, "git/tags", {
                         tag: name, message: "Rollout step recorded by run #{ENV['GITHUB_RUN_ID']}",
                         object: @sha, type: "commit",
                         tagger: { name: "blokada-ci", email: "ci@blokada.org", date: Time.now.utc.iso8601 }
                       }), name)
      sha = tag.fetch("sha")
      response = call(Net::HTTP::Post, "git/refs", { ref: "refs/tags/#{name}", sha: sha })
      if response.is_a?(Net::HTTPUnprocessableEntity)
        response = call(Net::HTTP::Patch, "git/refs/tags/#{name}", { sha: sha, force: true })
      end
      parse(response, name)
      nil
    rescue KeyError => e
      raise Refusal, "could not record tag #{name}: #{e.message}"
    end

    private

    def parse(response, name)
      raise Refusal, "GitHub returned #{response.code} for tag #{name}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue JSON::ParserError => e
      raise Refusal, "unreadable GitHub response for tag #{name}: #{e.message}"
    end

    def call(method, path, body = nil)
      uri = URI("https://api.github.com/repos/#{@repository}/#{path}")
      request = method.new(uri)
      request["Authorization"] = "Bearer #{@token}"
      request["Accept"] = "application/vnd.github+json"
      request.body = JSON.generate(body) if body
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 30) do |http|
        http.request(request)
      end
    rescue SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError => e
      raise Refusal, "could not reach GitHub for #{path}: #{e.message}"
    end
  end
end
