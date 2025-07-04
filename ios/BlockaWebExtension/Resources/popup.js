import { determineStatusState } from "./popup-logic.js";

async function getAccountStatus() {
  const response = await browser.runtime.sendMessage({ message: "status" });
  return response?.status || null;
}

function createStatusMessage(status, includeDetails = false) {
  const result = determineStatusState(status);
  let messageKey = result.messageKey;
  
  // Use detailed version for detail view if available
  if (includeDetails && result.daysLeft && messageKey === "status_trial_active") {
    messageKey = "status_trial_active_detailed";
  }
  
  let message = browser.i18n.getMessage(messageKey);
  
  if (result.daysLeft && message.includes("{DAYS}")) {
    message = message.replace("{DAYS}", result.daysLeft.toString());
  }

  return { state: result.state, message };
}

function updateUI(statusElement, state, message, status) {
  statusElement.className = "status-button";
  statusElement.textContent = message;
  
  // Map logic states to UI display states
  let displayState = "inactive";
  
  switch (state) {
    case "active":
      displayState = "cloud"; // Blue for full premium (device-wide protection)
      break;
    case "essentials":
      displayState = "essentials"; // Green for Safari blocking only
      break;
    case "trial":
      displayState = "trial"; // Orange for active trial (time-limited)
      break;
    case "expiring":
      displayState = "trial"; // Orange for expiring soon (urgency)
      break;
    default:
      displayState = "inactive"; // Gray for inactive
  }
  
  statusElement.classList.add(`status-${displayState}`);
}

async function refreshStatus(statusElement) {
  try {
    const status = await getAccountStatus();

    if (status) {
      const { state, message } = createStatusMessage(status, false); // Don't include details on main view
      updateUI(statusElement, state, message, status);
    } else {
      updateUI(
        statusElement,
        "inactive",
        browser.i18n.getMessage("status_inactive"),
        null
      );
    }
  } catch (error) {
    updateUI(
      statusElement,
      "inactive",
      browser.i18n.getMessage("status_inactive"),
      null
    );
  }
}

function showDetailView(status) {
  const mainView = document.getElementById("main-view");
  const detailView = document.getElementById("detail-view");
  const detailTitle = document.getElementById("detail-status-title");
  const detailFeatures = document.getElementById("detail-features");
  
  // Update detail view content first (include details like days)
  const { state, message } = createStatusMessage(status, true);
  detailTitle.textContent = message;
  
  // Create features list
  const features = getFeaturesList(status);
  detailFeatures.innerHTML = features.map(feature => 
    `<div class="feature-item">
      <span class="feature-icon ${feature.class}">${feature.icon}</span>
      <span>${feature.name}</span>
    </div>`
  ).join('');
  
  // Reset any transform/opacity from swipe gestures
  detailView.style.transform = "";
  detailView.style.opacity = "";
  detailView.style.transition = "";
  
  // Add transition class for animation
  mainView.style.transition = "all 0.3s ease";
  detailView.style.transition = "all 0.3s ease";
  
  // Animate transition
  detailView.classList.add("entering");
  detailView.style.display = "flex";
  
  // Trigger animation
  requestAnimationFrame(() => {
    mainView.style.transform = "translateX(-100%)";
    mainView.style.opacity = "0";
    detailView.classList.remove("entering");
    detailView.classList.add("active");
    
    setTimeout(() => {
      mainView.style.display = "none";
      // Clean up transitions
      mainView.style.transition = "";
      detailView.style.transition = "";
    }, 300);
  });
}

function showMainView() {
  const mainView = document.getElementById("main-view");
  const detailView = document.getElementById("detail-view");
  
  // Reset any transform/opacity from swipe gestures
  mainView.style.transform = "";
  mainView.style.opacity = "";
  mainView.style.transition = "";
  detailView.style.transform = "";
  detailView.style.opacity = "";
  detailView.style.transition = "";
  
  // Add transition class for animation
  mainView.style.transition = "all 0.3s ease";
  detailView.style.transition = "all 0.3s ease";
  
  // Animate transition back
  detailView.classList.remove("active");
  detailView.classList.add("exiting");
  
  mainView.style.display = "flex";
  mainView.style.transform = "translateX(-100%)";
  mainView.style.opacity = "0";
  
  requestAnimationFrame(() => {
    mainView.style.transform = "translateX(0)";
    mainView.style.opacity = "1";
    
    setTimeout(() => {
      detailView.style.display = "none";
      detailView.classList.remove("exiting");
      // Clean up all styles
      mainView.style.transition = "";
      mainView.style.transform = "";
      mainView.style.opacity = "";
      detailView.style.transition = "";
      detailView.style.transform = "";
      detailView.style.opacity = "";
    }, 300);
  });
}

function getFeatureState(isActive, isEnabled, hasTrialDays = false) {
  if (!isActive) return { icon: "❌", class: "feature-disabled" };
  if (isEnabled) return { icon: "✅", class: hasTrialDays ? "feature-trial" : "feature-enabled" };
  return { icon: "❌", class: "feature-disabled" };
}

function getFeaturesList(status) {
  const result = determineStatusState(status);
  const now = Date.now();
  const accountExpiry = typeof status?.timestamp === 'string' ? Date.parse(status.timestamp) : status?.timestamp || 0;
  const isAccountExpired = now > accountExpiry;
  const hasActiveFreemium = status?.freemium && status?.freemiumYoutubeUntil && now <= (typeof status.freemiumYoutubeUntil === 'string' ? Date.parse(status.freemiumYoutubeUntil) : status.freemiumYoutubeUntil);
  
  // Premium users (active subscription) have access to ALL features
  const isPremium = status?.active && !isAccountExpired;
  const hasYoutubeAccess = isPremium || hasActiveFreemium;
  const hasCookieAccess = isPremium || hasActiveFreemium; // Both premium and trial get cookie popups
  
  // Feature states
  const safariState = getFeatureState(status?.active, true);
  const deviceWideState = getFeatureState(status?.active, isPremium);
  const youtubeState = getFeatureState(status?.active, hasYoutubeAccess, hasActiveFreemium && !isPremium);
  const cookieState = getFeatureState(status?.active, hasCookieAccess, hasActiveFreemium && !isPremium);
  
  return [
    {
      name: browser.i18n.getMessage("feature_safari_blocking"),
      icon: safariState.icon,
      class: safariState.class
    },
    {
      name: browser.i18n.getMessage("feature_device_wide"),
      icon: deviceWideState.icon,
      class: deviceWideState.class
    },
    {
      name: (hasActiveFreemium && !isPremium)
        ? browser.i18n.getMessage("feature_youtube_ads_trial").replace("{DAYS}", result.daysLeft || 0)
        : browser.i18n.getMessage("feature_youtube_ads"),
      icon: youtubeState.icon,
      class: youtubeState.class
    },
    {
      name: browser.i18n.getMessage("feature_cookie_popups"),
      icon: cookieState.icon,
      class: cookieState.class
    }
  ];
}

// Touch handling for swipe-to-go-back
function setupSwipeNavigation() {
  const detailView = document.getElementById("detail-view");
  let startX = 0;
  let startY = 0;
  let isDragging = false;

  detailView.addEventListener("touchstart", (e) => {
    startX = e.touches[0].clientX;
    startY = e.touches[0].clientY;
    isDragging = false;
  });

  detailView.addEventListener("touchmove", (e) => {
    if (!isDragging) {
      const deltaX = e.touches[0].clientX - startX;
      const deltaY = e.touches[0].clientY - startY;
      
      // Only start dragging if horizontal swipe is dominant
      if (Math.abs(deltaX) > Math.abs(deltaY) && Math.abs(deltaX) > 10) {
        isDragging = true;
      }
    }
    
    if (isDragging) {
      e.preventDefault();
      const deltaX = e.touches[0].clientX - startX;
      
      // Only allow right swipe (positive deltaX)
      if (deltaX > 0) {
        const progress = Math.min(deltaX / 200, 1); // 200px for full swipe
        detailView.style.transform = `translateX(${deltaX}px)`;
        detailView.style.opacity = 1 - (progress * 0.3);
      }
    }
  });

  detailView.addEventListener("touchend", (e) => {
    if (isDragging) {
      const deltaX = e.changedTouches[0].clientX - startX;
      
      // If swiped more than 100px to the right, go back
      if (deltaX > 100) {
        // Reset any transform before calling showMainView
        detailView.style.transform = "";
        detailView.style.opacity = "";
        detailView.style.transition = "";
        showMainView();
      } else {
        // Snap back to original position
        detailView.style.transition = "all 0.3s ease";
        detailView.style.transform = "translateX(0)";
        detailView.style.opacity = "1";
        
        setTimeout(() => {
          detailView.style.transition = "";
          detailView.style.transform = "";
          detailView.style.opacity = "";
        }, 300);
      }
    }
    isDragging = false;
  });
}

document.addEventListener("DOMContentLoaded", () => {
  const statusText = document.getElementById("status-text");
  const openBtn = document.getElementById("open-app-btn");
  const backBtn = document.getElementById("back-btn");

  openBtn.textContent = browser.i18n.getMessage("open_app");
  backBtn.textContent = "← " + browser.i18n.getMessage("back_button");

  // Open app handler
  const openApp = () => window.open("six://go.blokada.org/six/", "_blank");
  openBtn.addEventListener("click", openApp);
  
  // Navigation handlers
  statusText.addEventListener("click", async () => {
    try {
      const status = await getAccountStatus();
      if (status) {
        const { state } = createStatusMessage(status, false);
        // Only show detail view for states that have meaningful information
        if (state !== "inactive") {
          showDetailView(status);
        }
      }
    } catch (error) {
      console.error("Failed to get status for detail view:", error);
    }
  });
  
  backBtn.addEventListener("click", showMainView);
  
  // Setup swipe navigation
  setupSwipeNavigation();

  refreshStatus(statusText);
});

// Export functions for testing
if (typeof window !== 'undefined') {
  window.popupTestExports = {
    refreshStatus,
    showDetailView,
    showMainView,
    getAccountStatus,
    createStatusMessage,
    updateUI
  };
}
