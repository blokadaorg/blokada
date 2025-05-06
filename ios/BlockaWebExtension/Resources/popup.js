document.addEventListener('DOMContentLoaded', () => {
  const statusText = document.getElementById('status-text');
  const openBtn = document.getElementById('open-app-btn');

  // Set localized static texts
  statusText.textContent = browser.i18n.getMessage('status_enabled');
  openBtn.textContent = browser.i18n.getMessage('open_app');

  // Open main app when button clicked
  openBtn.addEventListener('click', () => {
    const appUrl = 'https://go.blokada.org/six/onboard'; // TODO: replace with actual URL if needed
    window.open(appUrl, '_blank');
  });
});
