// ping.js: Relay a ping message to the page context on go.blokada.org
(async function () {
  async function ping() {
    if (typeof browser !== 'undefined' && browser.runtime && browser.runtime.sendMessage) {
      await browser.runtime.sendMessage({ message: 'status' });
      window.postMessage({ type: 'ping', url: window.location.href }, '*');
    } else {
      // Retry ping after a short delay if browser API isn't ready
      setTimeout(ping, 300);
    }
  }
  console.log('ping.js: posting ping message');
  if (document.readyState === 'complete' || document.readyState === 'interactive') {
    await ping();
  } else {
    document.addEventListener('DOMContentLoaded', () => {
      ping();
    });
  }
})();
