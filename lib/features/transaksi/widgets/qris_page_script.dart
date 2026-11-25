/// Menyisakan logo QRIS, QR, dan NMID dari halaman DOKU Checkout, lalu
/// memperbesarnya memenuhi WebView. Melapor lewat channel `MitbizQr`:
/// `qr` bila berhasil, `full` bila QR tidak ditemukan (halaman tampil utuh).
///
/// shortcut: bergantung pada susunan halaman DOKU (gambar persegi di dekat
/// tulisan NMID). Ganti dengan QR dari DOKU SNAP bila Merchant ID sudah ada.
const qrisPageScript = r'''
(function () {
  if (window.__mitbizQr) return;
  window.__mitbizQr = true;

  var changed = [], block = null, qr = null, state = null, ticks = 0;

  function post(next) {
    if (state === next) return;
    state = next;
    MitbizQr.postMessage(next);
  }

  // Lewat CSSOM, karena <style> bisa ditolak aturan keamanan halaman.
  function style(el, props) {
    if (!changed.some(function (c) { return c.el === el; })) {
      changed.push({ el: el, css: el.style.cssText });
    }
    for (var key in props) el.style.setProperty(key, props[key], 'important');
  }

  function restore() {
    changed.forEach(function (c) { c.el.style.cssText = c.css; });
    changed = [];
    block = qr = null;
  }

  function hasNmid(el) { return /NMID/i.test(el.textContent || ''); }

  function isSquare(el) {
    var r = el.getBoundingClientRect();
    return r.width >= 80 && Math.abs(r.width - r.height) <= r.width * 0.1;
  }

  // QR = gambar persegi dengan induk terkecil yang juga memuat tulisan NMID.
  function find() {
    var best = null;
    var images = document.querySelectorAll('canvas,img,svg');
    for (var i = 0; i < images.length; i++) {
      if (!isSquare(images[i])) continue;
      var p = images[i].parentElement;
      while (p && p !== document.body && !hasNmid(p)) p = p.parentElement;
      if (!p || p === document.body) continue;
      var size = p.textContent.length;
      if (!best || size < best.size) best = { qr: images[i], block: p, size: size };
    }
    return best;
  }

  function prune(node) {
    for (var i = 0; i < node.children.length; i++) {
      var el = node.children[i];
      if (el === qr || el.contains(qr)) { prune(el); continue; }
      if (el.closest('svg') && el.tagName.toLowerCase() !== 'svg') continue;
      var isButton = el.matches('button,a,[role=button]');
      var isImage = el.matches('img,svg,canvas') || el.querySelector('img,svg,canvas');
      if (hasNmid(el)) prune(el);
      else if (isButton || !isImage) style(el, { display: 'none' });
    }
  }

  function isolate() {
    prune(block);
    for (var n = block; n && n !== document.documentElement; n = n.parentElement) {
      style(n, {
        overflow: 'visible', position: 'static', transform: 'none', filter: 'none',
        opacity: '1', background: '#fff', border: '0', 'box-shadow': 'none',
        'max-height': 'none', contain: 'none', 'clip-path': 'none'
      });
      var siblings = n.parentElement ? n.parentElement.children : [];
      for (var i = 0; i < siblings.length; i++) {
        if (siblings[i] !== n && !/^(SCRIPT|STYLE|HEAD|LINK)$/.test(siblings[i].tagName)) {
          style(siblings[i], { display: 'none' });
        }
      }
    }
    // Hanya di <html>: overflow hidden di <body> memotong QR yang diperbesar.
    style(document.documentElement, { overflow: 'hidden', background: '#fff' });
    style(qr, { 'image-rendering': 'pixelated' });
    fit();
  }

  function bounds() {
    var box = null;
    function add(r) {
      if (!r.width || !r.height) return;
      box = box || { l: r.left, t: r.top, r: r.right, b: r.bottom };
      box.l = Math.min(box.l, r.left); box.t = Math.min(box.t, r.top);
      box.r = Math.max(box.r, r.right); box.b = Math.max(box.b, r.bottom);
    }
    var images = block.querySelectorAll('canvas,img,svg');
    for (var i = 0; i < images.length; i++) add(images[i].getBoundingClientRect());
    var walker = document.createTreeWalker(block, NodeFilter.SHOW_TEXT), text;
    while ((text = walker.nextNode())) {
      if (!text.nodeValue.trim()) continue;
      var range = document.createRange();
      range.selectNodeContents(text);
      add(range.getBoundingClientRect());
    }
    return box;
  }

  function fit() {
    style(block, { transform: 'none', 'transform-origin': '0 0' });
    var box = bounds(), origin = block.getBoundingClientRect();
    if (!box) return;
    var w = box.r - box.l, h = box.b - box.t;
    var vw = window.innerWidth, vh = window.innerHeight;
    var k = Math.min((vw - 8) / w, (vh - 8) / h);
    var x = (vw - k * w) / 2 - origin.left - k * (box.l - origin.left);
    var y = (vh - k * h) / 2 - origin.top - k * (box.t - origin.top);
    style(block, { transform: 'translate(' + x + 'px,' + y + 'px) scale(' + k + ')' });
  }

  function tick() {
    if (block && !(document.contains(block) && block.contains(qr) && hasNmid(block))) restore();
    if (!block) {
      var found = find();
      if (found) { block = found.block; qr = found.qr; }
    }
    if (block) { isolate(); post('qr'); }
    else if (state === 'qr' || ++ticks > 20) post('full');
  }

  window.addEventListener('resize', function () { if (block) fit(); });
  setInterval(tick, 500);
  tick();
})();
''';
