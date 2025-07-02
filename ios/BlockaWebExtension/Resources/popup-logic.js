/**
 * Determines the current status state of an account based on various conditions
 * (see popup-test.js)
 */
export function determineStatusState(status) {
  const { active, timestamp, freemium, freemiumYoutubeUntil } = status;

  if (!active) {
    return { state: "inactive", messageKey: "status_inactive" };
  }

  const now = new Date();
  const accountExpiry = new Date(timestamp);
  const isAccountExpired = isValidDate(accountExpiry)
    ? accountExpiry <= now
    : true;

  if (isAccountExpired && freemium && freemiumYoutubeUntil) {
    const freemiumExpiry = new Date(freemiumYoutubeUntil);

    if (!isValidDate(freemiumExpiry)) {
      // Invalid date, treat as essentials (basic freemium)
      return { state: "essentials", messageKey: "status_essentials_active" };
    }

    if (freemiumExpiry <= now) {
      // Trial expired, back to essentials (basic freemium)  
      return { state: "essentials", messageKey: "status_essentials_active" };
    }

    const daysLeft = Math.ceil((freemiumExpiry - now) / (24 * 60 * 60 * 1000));

    return {
      state: "trial",
      messageKey: "status_trial_active",
      daysLeft: daysLeft,
    };
  }

  if (isAccountExpired) {
    // If freemium is available, user has basic content blocking (essentials)
    if (freemium) {
      return { state: "essentials", messageKey: "status_essentials_active" };
    }
    // No freemium eligibility, truly inactive
    return { state: "inactive", messageKey: "status_inactive" };
  }

  if (isValidDate(accountExpiry)) {
    const sevenDaysFromNow = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
    if (accountExpiry <= sevenDaysFromNow) {
      return { state: "expiring", messageKey: "status_expiring_soon" };
    }
  }

  return { state: "active", messageKey: "status_blocking_active" };
}

export function isValidDate(date) {
  return date instanceof Date && !isNaN(date.getTime());
}
