# frozen_string_literal: true

# What a store-rollout.yml action does to the staged release on a Play
# production track. Free of any network call, so PR CI covers every case
# (scripts/test-store-rollout.rb); scripts/play-rollout.rb does the I/O.
#
# A track holds at most one staged rollout, so there is never a choice of
# release to make: anything other than exactly one inProgress or halted
# release is refused rather than guessed at.
module PlayRollout
  IN_PROGRESS = "inProgress"
  HALTED = "halted"
  COMPLETED = "completed"

  ACTIONS = %w[raise halt resume].freeze

  class Refusal < StandardError; end

  # Applies the action to the staged release in place and returns it, or
  # returns nil when the release is already where the action would put it.
  # Raises Refusal when the action cannot start from the track's state.
  def self.apply!(releases, action:, fraction: nil)
    raise Refusal, "unknown action '#{action}', expected one of #{ACTIONS.join(', ')}" unless ACTIONS.include?(action)

    release = staged_release(releases)

    case action
    when "halt"
      return nil if release.status == HALTED

      release.status = HALTED
    when "resume"
      return nil unless release.status == HALTED

      # A halted release keeps the fraction it was halted at, so resuming
      # reaches no more users than before the halt.
      release.status = release.user_fraction ? IN_PROGRESS : COMPLETED
    when "raise"
      return nil unless raise_to!(release, parse_fraction(fraction))
    end

    release
  end

  def self.staged_release(releases)
    staged = (releases || []).select { |r| [IN_PROGRESS, HALTED].include?(r.status) }
    if staged.empty?
      raise Refusal, "production has no staged rollout to change. A release that went out to " \
                     "100% can only be halted in Play Console (Production -> Releases -> Halt release)."
    end
    if staged.size > 1
      raise Refusal, "production has #{staged.size} staged releases (#{describe(staged)}); " \
                     "Play allows one. Resolve it in Play Console."
    end

    staged.first
  end

  # A bare number is a fraction ("1" already means complete the rollout), so
  # a percentage needs its "%": "20%" is 0.2, a bare "20" is refused.
  PERCENT = /\A(\d+(?:\.\d*)?|\.\d+)\s*%\z/

  def self.parse_fraction(text)
    input = text.to_s.strip
    # Exact decimal division, so "1.1%" is the same float as "0.011" and a
    # repeated raise stays a no-op.
    value = (m = PERCENT.match(input)) ? (Rational(m[1]) / 100).to_f : Float(input)
    raise ArgumentError unless value.positive? && value <= 1

    value
  rescue ArgumentError, TypeError
    raise Refusal, "fraction must be above 0 and at most 1, as a share or a percentage " \
                   "(use 0.2 or 20% for 20% of users), got '#{text}'"
  end

  # Returns false when the rollout is already at that fraction.
  def self.raise_to!(release, fraction)
    if release.status == HALTED
      raise Refusal, "the rollout of #{describe([release])} is halted. Resume it first, then raise it."
    end

    current = release.user_fraction.to_f
    return false if fraction == current

    if fraction < current
      raise Refusal, "the rollout of #{describe([release])} is already above #{fraction}; Play " \
                     "cannot take a rollout back to fewer users. Halt it instead."
    end

    if fraction == 1
      release.status = COMPLETED
      release.user_fraction = nil
    else
      release.user_fraction = fraction
    end
    true
  end

  def self.describe(releases)
    releases.map do |r|
      percent = r.user_fraction ? " at #{(r.user_fraction * 100).round(2)}%" : ""
      "version code #{(r.version_codes || []).join(', ')} #{r.status}#{percent}"
    end.join("; ")
  end
end
