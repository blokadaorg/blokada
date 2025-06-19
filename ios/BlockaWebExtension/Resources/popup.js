document.addEventListener("DOMContentLoaded", () => {
  const statusText = document.getElementById("status-text");
  const openBtn = document.getElementById("open-app-btn");

  // Set localized button text
  openBtn.textContent = browser.i18n.getMessage("open_app");

  // Open main app when button clicked
  openBtn.addEventListener("click", () => {
    const appUrl = "six://go.blokada.org/six/";
    window.open(appUrl, "_blank");
  });

  // Request status from Safari extension handler
  requestAccountStatus();

  async function requestAccountStatus() {
    try {
      // Send message to Safari extension native handler
      // This will trigger SafariWebExtensionHandler.beginRequest in Swift
      const response = await browser.runtime.sendMessage({ message: "status" });

      if (response && response.status) {
        updateStatusDisplay(response.status);
      } else {
        // No valid response - show inactive state
        setStatusState("inactive", browser.i18n.getMessage("status_inactive"));
      }
    } catch (error) {
      console.log("Status check failed:", error);
      // On error, show inactive state
      setStatusState("inactive", browser.i18n.getMessage("status_inactive"));
    }
  }

  function updateStatusDisplay(status) {
    const { active, timestamp, freemium, freemiumYoutubeUntil } = status;

    // If app is paused, show inactive regardless of subscription status
    if (!active) {
      setStatusState("inactive", browser.i18n.getMessage("status_inactive"));
      return;
    }

    const now = new Date();
    const accountExpiry = new Date(timestamp);
    const isAccountExpired = isValidDate(accountExpiry)
      ? accountExpiry <= now
      : true;

    // Check freemium eligibility for expired accounts
    if (isAccountExpired && freemium && freemiumYoutubeUntil) {
      const freemiumExpiry = new Date(freemiumYoutubeUntil);

      if (!isValidDate(freemiumExpiry)) {
        setStatusState(
          "expired",
          browser.i18n.getMessage("status_trial_expired"),
        );
        return;
      }

      if (freemiumExpiry <= now) {
        // Freemium trial has expired
        setStatusState(
          "expired",
          browser.i18n.getMessage("status_trial_expired"),
        );
        return;
      }

      // Freemium trial is active
      const daysLeft = Math.ceil(
        (freemiumExpiry - now) / (24 * 60 * 60 * 1000),
      );
      setStatusState(
        "trial",
        browser.i18n
          .getMessage("status_trial_active")
          .replace("$1", daysLeft.toString()),
      );
      return;
    }

    // Regular subscription logic (unchanged)
    if (isAccountExpired) {
      setStatusState(
        "expired",
        browser.i18n.getMessage("status_access_expired"),
      );
      return;
    }

    if (isValidDate(accountExpiry)) {
      const sevenDaysFromNow = new Date(
        now.getTime() + 7 * 24 * 60 * 60 * 1000,
      );
      if (accountExpiry <= sevenDaysFromNow) {
        setStatusState(
          "expiring",
          browser.i18n.getMessage("status_expiring_soon"),
        );
        return;
      }
    }

    setStatusState("active", browser.i18n.getMessage("status_blocking_active"));
  }

  function setStatusState(state, message) {
    // Clear existing status classes
    statusText.className = "";

    // Set the message
    statusText.textContent = message;

    // Add the appropriate CSS class for visual styling
    statusText.classList.add(`status-${state}`);
  }

  function isValidDate(date) {
    return date instanceof Date && !isNaN(date.getTime());
  }
});
