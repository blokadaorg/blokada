# Maps an App Store Connect version state onto what a promote run is allowed to
# do with it. Kept out of the Fastfile, and free of any network call, so PR CI
# can cover every state without store credentials.
#
# Fail closed. Apple has already replaced one of these enums once
# (appStoreState superseded by appVersionState), and a release that stalls with
# a legible message beats one that mutates a submission nobody was looking at.
module ReleaseState
  # No pending version at all: the live one, a superseded one, or a brand new
  # app. deliver creates the version it needs.
  IDLE = [nil, "READY_FOR_DISTRIBUTION", "REPLACED_WITH_NEW_VERSION"].freeze

  # A pending version App Store Connect still lets us edit.
  EDITABLE = %w[
    PREPARE_FOR_SUBMISSION
    DEVELOPER_REJECTED
    REJECTED
    METADATA_REJECTED
    INVALID_BINARY
  ].freeze

  # Submitted, undecided, and cancellable -- so a newer build can take its
  # place. Anything Apple has already approved is deliberately not here: once
  # the review submission is COMPLETE there is no API to undo it.
  CANCELLABLE = %w[
    WAITING_FOR_REVIEW
    IN_REVIEW
  ].freeze

  # What the operator has to do, per blocking state. Written as the tail of
  # "version X is STATE -- ...".
  BLOCKED = {
    "PENDING_DEVELOPER_RELEASE" =>
      "it is approved and waiting to be released by hand. Release it in App Store Connect " \
      "(or reject it there), then re-run this workflow.",
    "PENDING_APPLE_RELEASE" =>
      "it is approved and scheduled for release by Apple. Wait for it to go live in App Store " \
      "Connect, then re-run this workflow.",
    "PROCESSING_FOR_DISTRIBUTION" =>
      "it has been released and Apple is still processing it. Wait for it to go live in App " \
      "Store Connect, then re-run this workflow.",
    "ACCEPTED" =>
      "it is approved and on its way out. Wait for it to go live in App Store Connect, then " \
      "re-run this workflow.",
    "READY_FOR_REVIEW" =>
      "a review submission has been prepared for it in App Store Connect but never sent. Submit " \
      "or delete that submission, then re-run this workflow.",
    "WAITING_FOR_EXPORT_COMPLIANCE" =>
      "it is waiting on an export compliance answer in App Store Connect. Answer it, then " \
      "re-run this workflow."
  }.freeze

  UNKNOWN = "the release pipeline does not know this state. Check the version in App Store " \
            "Connect, then teach ios/fastlane/release_state.rb what to do with it."

  # Every state that means "a version is pending", for use as an
  # appVersionState filter. Asking App Store Connect for exactly these is the
  # only deterministic way to find the pending version: spaceship's
  # get_latest_app_store_version sorts client-side by Date.parse(created_date),
  # which has calendar-day granularity and is not a stable sort, so a live
  # version created on the same day as a pending one can win the sort and hide
  # it. Derived from the tables above, so a state added there is queried here.
  PENDING = (EDITABLE + CANCELLABLE + BLOCKED.keys).freeze

  # Most restrictive first. Used when App Store Connect reports more than one
  # pending version, so a blocked one is never masked by an editable one.
  SEVERITY = %i[blocked cancel proceed].freeze

  def self.strictest(actions)
    SEVERITY.find { |action| actions.include?(action) } || :proceed
  end

  # Returns [action, reason]:
  #   :proceed - deliver can create or edit the version; reason is nil
  #   :cancel  - a review submission has to be cancelled before deliver runs
  #   :blocked - the release cannot continue; reason says what a human must do
  def self.classify(state)
    return [:proceed, nil] if IDLE.include?(state)
    return [:proceed, nil] if EDITABLE.include?(state)
    return [:cancel, "it is in review and this build would replace it"] if CANCELLABLE.include?(state)

    [:blocked, BLOCKED.fetch(state, UNKNOWN)]
  end
end
