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
    const { active, timestamp } = status;

    // Active might be false even if account isn't expired,
    // for example if the user has paused Blokada.
    if (!active) {
      setStatusState("inactive", browser.i18n.getMessage("status_inactive"));
      return;
    }

    // Parse the timestamp (account expiration date)
    const expirationDate = new Date(timestamp);
    const now = new Date();

    // Check if account has expired
    if (expirationDate <= now) {
      setStatusState(
        "expired",
        browser.i18n.getMessage("status_access_expired"),
      );
      return;
    }

    // Check if account is expiring within 7 days
    const sevenDaysFromNow = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
    if (expirationDate <= sevenDaysFromNow) {
      setStatusState(
        "expiring",
        browser.i18n.getMessage("status_expiring_soon"),
      );
      return;
    }

    // Account is active and not expiring soon
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
});
