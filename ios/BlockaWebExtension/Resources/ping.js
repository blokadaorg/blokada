// ping.js: Relay a ping message to the page context on go.blokada.org
(async function () {
  async function ping() {
    window.postMessage({ type: 'ping', url: window.location.href }, '*');
    await browser.runtime.sendMessage({ message: 'status' });
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
