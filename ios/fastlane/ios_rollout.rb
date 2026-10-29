# What a store-rollout.yml action may do to an App Store app, from the states
# App Store Connect reports. Free of any network call, so PR CI covers every
# case (scripts/test-store-rollout.rb); the store_rollout lane does the I/O.
module IosRollout
  ACTIONS = %w[pause resume release].freeze

  # Phased release state each action starts from, and the one it leads to.
  PHASED = {
    "pause" => { from: "ACTIVE", to: "PAUSED" },
    "resume" => { from: "PAUSED", to: "ACTIVE" }
  }.freeze

  # Returns :apply, :noop when the app is already where the action would put
  # it, or a String saying why the action cannot start.
  #
  # version_state is the state of the version the action works on: the live
  # one for pause and resume, the approved one for release (nil when there is
  # none). phased_state is that version's phased release state, nil when it
  # has none.
  def self.decide(action, version_state:, phased_state:)
    return "unknown action '#{action}', expected one of #{ACTIONS.join(', ')}" unless ACTIONS.include?(action)

    if action == "release"
      return "no version is waiting in Pending Developer Release, so there is nothing to release." if version_state.nil?

      return :apply
    end

    return "no version is live, so there is no phased release to #{action}." if version_state.nil?

    step = PHASED.fetch(action)
    return :apply if phased_state == step[:from]
    return :noop if phased_state == step[:to]

    if phased_state.nil?
      return "the live version was released without a phased release, so it already reaches every user."
    end

    "the live version's phased release is #{phased_state}, and #{action} only applies to one that is #{step[:from]}."
  end
end
