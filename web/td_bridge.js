// Thin JSON bridge between the Dart app and tdweb (TDLib compiled to WebAssembly).
// tdweb files (tdweb.js, *.worker.js, *.wasm) are copied next to index.html at build time.
(function () {
  'use strict';
  var client = null;
  var listener = null;

  function emit(obj) {
    if (listener) listener(JSON.stringify(obj));
  }

  function blobToBase64(blob) {
    return blob.arrayBuffer().then(function (buf) {
      var bytes = new Uint8Array(buf);
      var out = '';
      var step = 0x8000;
      for (var i = 0; i < bytes.length; i += step) {
        out += String.fromCharCode.apply(null, bytes.subarray(i, i + step));
      }
      return btoa(out);
    });
  }

  function ctor() {
    var m = window.tdweb;
    if (!m) return null;
    return m.default || m.TdClient || (typeof m === 'function' ? m : null);
  }

  window.erostreamTd = {
    available: function () {
      return !!ctor();
    },
    create: function (options, onMessage) {
      listener = onMessage;
      var o = JSON.parse(options);
      o.onUpdate = emit;
      var C = ctor();
      client = new C(o);
    },
    send: function (json) {
      if (!client) return;
      var q = JSON.parse(json);
      var extra = q['@extra'];
      client.send(q).then(
        function (r) {
          r = r || { '@type': 'ok' };
          r['@extra'] = extra;
          if (r.data instanceof Blob) {
            return blobToBase64(r.data).then(function (b64) {
              r.data = b64;
              emit(r);
            });
          }
          emit(r);
        },
        function (e) {
          var err = e && e['@type'] === 'error'
            ? e
            : { '@type': 'error', code: 500, message: String((e && e.message) || e) };
          err['@extra'] = extra;
          emit(err);
        }
      );
    },
    close: function () {
      if (client) client.send({ '@type': 'close' });
    }
  };
})();
