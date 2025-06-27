import { determineStatusState } from "./popup-logic.js";

async function getAccountStatus() {
  const response = await browser.runtime.sendMessage({ message: "status" });
  return response?.status || null;
}

function createStatusMessage(status) {
  const result = determineStatusState(status);
  let message = browser.i18n.getMessage(result.messageKey);

  if (result.daysLeft) {
    message = message.replace("{DAYS}", result.daysLeft.toString());
  }

  return { state: result.state, message };
}

function updateUI(statusElement, state, message) {
  statusElement.className = "";
  statusElement.textContent = message;
  statusElement.classList.add(`status-${state}`);
}

async function refreshStatus(statusElement) {
  try {
    const status = await getAccountStatus();

    if (status) {
      const { state, message } = createStatusMessage(status);
      updateUI(statusElement, state, message);
    } else {
      updateUI(
        statusElement,
        "inactive",
        browser.i18n.getMessage("status_inactive"),
      );
    }
  } catch (error) {
    updateUI(
      statusElement,
      "inactive",
      browser.i18n.getMessage("status_inactive"),
    );
  }
}

document.addEventListener("DOMContentLoaded", () => {
  const statusText = document.getElementById("status-text");
  const openBtn = document.getElementById("open-app-btn");

  openBtn.textContent = browser.i18n.getMessage("open_app");

  openBtn.addEventListener("click", () => {
    window.open("six://go.blokada.org/six/", "_blank");
  });

  refreshStatus(statusText);
});
