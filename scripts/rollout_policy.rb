# frozen_string_literal: true

# When store-rollout.yml's `advance` may move Blokada 6 without a second human
# approval. Approving the promote approves the whole ramp, so `advance` only
# takes the next fixed step of a build with an approved go-live. Everything it
# cannot prove is refused; `raise` and `release` stay behind store-live.
#
# The proof is in tags at build N's commit, because workflow runs can
# disappear from GitHub:
#   golive/N/<store>  pushed by promote.yml after an approved go-live reached
#                     that store (android or ios)
#   ramp/N/<pct>      refreshed just before each store write that lands on that
#                     step, by advance, raise or resume, so its date is when the
#                     step last changed
require "open3"
require "time"

module RolloutPolicy
  class Refusal < StandardError; end

  LADDER = [0.01, 0.2, 0.5, 1.0].freeze
  MIN_STEP_SECONDS = 24 * 60 * 60
  CODE_OFFSET = 669_000_000

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

    build = Integer(codes.first.to_s, 10) - CODE_OFFSET
    raise Refusal, "version code #{codes.first} is not a Blokada 6 build" unless build.positive?

    build
  rescue ArgumentError, TypeError
    raise Refusal, "could not read a build number from version code #{codes.first.inspect}"
  end

  # An App Store version waits in Pending Developer Release whether or not the
  # promote went live, so the go-live tag is what approves releasing it. The
  # version and its binary must both be build N's, so a go-live of one build
  # cannot release another that shares its last number.
  def self.authorize_ios!(version_string:, build_version:, phased_state:, tags:)
    build = version_string.to_s[/\A\d+\.\d+\.(\d+)\z/, 1]
    raise Refusal, "could not read a build number from version #{version_string.inspect}" if build.nil?

    build = Integer(build, 10)
    expected = tags.version(build)
    unless version_string == expected
      raise Refusal, "version #{version_string} is not build #{build}, which is #{expected}"
    end
    unless build_version.to_s == (CODE_OFFSET + build).to_s
      raise Refusal, "#{version_string} carries binary #{build_version.inspect}, not #{CODE_OFFSET + build}"
    end
    if phased_state.nil?
      raise Refusal, "#{version_string} has no phased release, so it would reach every user at once. " \
                     "Use `release`, which waits for a maintainer."
    end
    if tags.date("golive/#{build}/ios").nil?
      raise Refusal, "build #{build} has no approved iOS go-live (golive/#{build}/ios)"
    end

    nil
  end

  # Reads and pushes rollout tags with git, in a checkout whose origin is this
  # repository. A tag counts only if it is annotated, tagged by blokada-ci and
  # points at its build's commit; anything else is refused, never ignored.
  # This stops mistakes and casual edits, not someone with write access who
  # forges all three: only a tag ruleset on golive/** and ramp/** does that.
  class GitTags
    TAGGER = "blokada-ci <ci@blokada.org>"

    def initialize(dir: Dir.pwd, remote: "origin")
      @dir = dir
      @remote = remote
    end

    # The tag's date, nil when it does not exist.
    def date(name)
      return nil unless fetch(name)

      type, tagger, date, target = git("for-each-ref",
                                       "--format=%(objecttype)\t%(taggername) %(taggeremail)\t" \
                                       "%(taggerdate:iso-strict)\t%(*objectname)",
                                       "refs/tags/#{name}").chomp.split("\t")
      raise Refusal, "tag #{name} is not annotated" unless type == "tag"
      raise Refusal, "tag #{name} was made by #{tagger}, not #{TAGGER}" unless tagger == TAGGER

      build = build_of(name)
      raise Refusal, "tag #{name} does not point at build/#{build}" unless target == commit(build)

      Time.iso8601(date)
    rescue ArgumentError => e
      raise Refusal, "could not read tag #{name}: #{e.message}"
    end

    # The version string build N was tagged with, such as 26.12.1100.
    def version(build)
      commit(build)
      git("for-each-ref", "--format=%(contents:subject)", "refs/tags/build/#{build}").strip
    end

    # Creates the tag at its build's commit, or moves it to a new one dated now.
    def record(name)
      sha = commit(build_of(name))
      git("-c", "user.name=blokada-ci", "-c", "user.email=ci@blokada.org", "-c", "tag.gpgSign=false",
          "tag", "--annotate", "--force", name, sha,
          "--message", "Rollout step recorded by run #{ENV.fetch('GITHUB_RUN_ID', 'outside CI')}")
      git("push", "--force", @remote, "refs/tags/#{name}")
      nil
    end

    private

    def build_of(name)
      Integer(name.split("/")[1].to_s, 10)
    rescue ArgumentError
      raise Refusal, "tag #{name} names no build"
    end

    # The commit build/N points at. A build without its tag is refused.
    def commit(build)
      raise Refusal, "build/#{build} does not exist" unless fetch("build/#{build}")

      git("rev-parse", "refs/tags/build/#{build}^{commit}").strip
    end

    # Fetches one tag from the remote; false when the remote has no such tag.
    def fetch(name)
      _, _, status = run("ls-remote", "--exit-code", "--tags", @remote, "refs/tags/#{name}")
      return false if status.exitstatus == 2

      raise Refusal, "could not list tag #{name} on #{@remote}" unless status.success?

      git("fetch", "--quiet", "--force", "--no-tags", "--depth", "1", @remote,
          "+refs/tags/#{name}:refs/tags/#{name}")
      true
    end

    def git(*args)
      out, err, status = run(*args)
      raise Refusal, "git #{args.first} failed: #{err.strip}" unless status.success?

      out
    end

    def run(*args)
      Open3.capture3("git", *args, chdir: @dir)
    end
  end
end
