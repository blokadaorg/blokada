// ping.js: Relay a ping message to the page context on go.blokada.org
(function () {
  function ping() {
    window.postMessage({ type: 'ping', url: window.location.href }, '*');
  }
  console.log('ping.js: posting ping message');
  if (document.readyState === 'complete' || document.readyState === 'interactive') {
    ping();
  } else {
    document.addEventListener('DOMContentLoaded', ping);
  }
})();
