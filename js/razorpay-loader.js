(function() {
  fetch('/api/payment-config')
    .then(function(r) { return r.json(); })
    .then(function(d) { window.__RZP_KEY_ID = d.key_id || ''; })
    .catch(function() { window.__RZP_KEY_ID = ''; });
})();
