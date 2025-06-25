import { determineStatusState } from "./popup-logic.js";

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
    const result = determineStatusState(status);
    let message = browser.i18n.getMessage(result.messageKey);

    if (result.daysLeft) {
      message = message.replace("$1", result.daysLeft.toString());
    }

    setStatusState(result.state, message);
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
