// Solid Queue Board: theme, auto-refresh polling, expandable rows, confirmations.
// Plain JS, no dependencies. Polling fetches the same URL with a header and morphs the live region in place
// (only new, changed and removed nodes are touched).
(function () {
  "use strict";

  var root = document.getElementById("sqb");
  if (!root) return;

  var region = document.getElementById("sqb-region");
  var pollSelect = document.getElementById("sqb-poll");
  var themeSelect = document.getElementById("sqb-theme");
  var refreshBtn = document.getElementById("sqb-refresh");
  var live = document.getElementById("sqb-live-status");
  var liveText = live.querySelector("span");

  var store = {
    get: function (key, fallback) { try { var v = localStorage.getItem(key); return v === null ? fallback : v; } catch (e) { return fallback; } },
    set: function (key, value) { try { localStorage.setItem(key, value); } catch (e) {} }
  };
  function t(name, vars) {
    var text = root.getAttribute("data-t-" + name) || "";
    Object.keys(vars || {}).forEach(function (k) { text = text.replace("%{" + k + "}", vars[k]); });
    return text;
  }
  function clock(d) {
    function p(n) { return (n < 10 ? "0" : "") + n; }
    return p(d.getHours()) + ":" + p(d.getMinutes()) + ":" + p(d.getSeconds());
  }

  /* ---------- theme ---------- */
  function applyTheme(value) {
    if (value === "light" || value === "dark") document.documentElement.setAttribute("data-theme", value);
    else document.documentElement.removeAttribute("data-theme");
  }
  var theme = store.get("sqb-theme", "system");
  themeSelect.value = theme;
  applyTheme(theme);
  themeSelect.addEventListener("change", function () {
    store.set("sqb-theme", themeSelect.value);
    applyTheme(themeSelect.value);
  });

  /* ---------- expandable rows (state survives refreshes) ---------- */
  var openRows = new Set();
  function setRow(row, open) {
    var id = row.getAttribute("data-sqb-toggle");
    var detail = document.getElementById("sqb-detail-" + id);
    if (!detail) return;
    detail.hidden = !open;
    row.setAttribute("aria-expanded", open ? "true" : "false");
    if (open) openRows.add(id); else openRows.delete(id);
  }
  function restoreRows() {
    openRows.forEach(function (id) {
      var row = region.querySelector('[data-sqb-toggle="' + id + '"]');
      if (row) setRow(row, true); else openRows.delete(id);
    });
  }
  region.addEventListener("click", function (event) {
    if (event.target.closest("a, button, form, pre, input")) return;
    var row = event.target.closest("[data-sqb-toggle]");
    if (row) setRow(row, row.getAttribute("aria-expanded") !== "true");
  });
  region.addEventListener("keydown", function (event) {
    var row = event.target.closest("[data-sqb-toggle]");
    if (row && (event.key === "Enter" || event.key === " ")) {
      event.preventDefault();
      setRow(row, row.getAttribute("aria-expanded") !== "true");
    }
  });

  /* ---------- confirmations on destructive forms ---------- */
  document.addEventListener("submit", function (event) {
    var message = event.target.getAttribute("data-sqb-confirm");
    if (message && !window.confirm(message)) event.preventDefault();
  });

  /* ---------- polling ---------- */
  var interval = parseInt(store.get("sqb-poll", root.getAttribute("data-poll-default")), 10) || 0;
  if (!Array.prototype.some.call(pollSelect.options, function (o) { return parseInt(o.value, 10) === interval; })) {
    interval = parseInt(root.getAttribute("data-poll-default"), 10) || 0;
  }
  pollSelect.value = String(interval);
  var countdown = interval;
  var lastUpdate = new Date();
  var busy = false;
  var failed = false;

  function render() {
    live.classList.toggle("off", interval === 0);
    live.classList.toggle("busy", busy);
    live.classList.toggle("error", failed);
    if (busy) liveText.textContent = t("loading");
    else if (failed) return;
    else if (interval === 0) liveText.textContent = t("off") + " · " + t("updated", { time: clock(lastUpdate) });
    else liveText.textContent = t("updated", { time: clock(lastUpdate) }) + " · " + t("next", { seconds: countdown });
  }

  /* ---------- in-place update of the live region ---------- */
  // Client-owned state: never overwritten by the server HTML.
  var CLIENT_ATTRS = { "hidden": 1, "aria-expanded": 1 };
  var FLASH = ["added", "changed"];
  var slice = Array.prototype.slice;

  function keyOf(node) {
    if (node.nodeType !== 1) return null;
    var toggle = node.getAttribute("data-sqb-toggle");
    if (toggle !== null) return "t:" + toggle;
    return node.id ? "i:" + node.id : null;
  }
  function typeOf(node) { return node.nodeType + ":" + node.nodeName; }

  // (Re)start the row flash: remove, force a reflow, add.
  function flash(row, name) {
    FLASH.forEach(function (c) { row.classList.remove(c); });
    void row.offsetWidth;
    row.classList.add(name);
  }

  function syncAttributes(from, to) {
    slice.call(to.attributes).forEach(function (attr) {
      if (CLIENT_ATTRS[attr.name]) return;
      var value = attr.value;
      if (attr.name === "class") {
        // keep a running flash class that the server does not know about
        FLASH.forEach(function (c) { if (from.classList.contains(c)) value += " " + c; });
      }
      if (from.getAttribute(attr.name) !== value) from.setAttribute(attr.name, value);
    });
    slice.call(from.attributes).forEach(function (attr) {
      if (!CLIENT_ATTRS[attr.name] && !to.hasAttribute(attr.name)) from.removeAttribute(attr.name);
    });
  }

  function syncNode(from, to, ctx) {
    if (from.nodeType !== 1) {
      if (from.nodeValue !== to.nodeValue) from.nodeValue = to.nodeValue;
      return;
    }
    if (from.nodeName !== to.nodeName) {
      from.parentNode.replaceChild(document.importNode(to, true), from);
      return;
    }
    var sig = to.getAttribute("data-sqb-sig");
    if (ctx.animate && sig !== null && from.getAttribute("data-sqb-sig") !== sig) flash(from, "changed");
    syncAttributes(from, to);
    syncChildren(from, to, ctx);
  }

  // Match children by key (job id, element id) or, without a key, by position and type.
  function syncChildren(parent, source, ctx) {
    var olds = slice.call(parent.childNodes), news = slice.call(source.childNodes);
    var keyed = {}, queues = {};
    olds.forEach(function (node) {
      var key = keyOf(node);
      if (key) keyed[key] = node;
      else (queues[typeOf(node)] = queues[typeOf(node)] || []).push(node);
    });
    var matches = news.map(function (node) {
      var key = keyOf(node), found = null;
      if (key) { found = keyed[key] || null; delete keyed[key]; }
      else if (queues[typeOf(node)] && queues[typeOf(node)].length) found = queues[typeOf(node)].shift();
      return found;
    });
    var used = new Set(matches.filter(Boolean));
    olds.forEach(function (node) { if (!used.has(node)) parent.removeChild(node); });

    var ref = parent.firstChild;
    news.forEach(function (node, i) {
      var match = matches[i];
      if (match) {
        if (match === ref) ref = ref.nextSibling; else parent.insertBefore(match, ref);
        syncNode(match, node, ctx);
      } else {
        var created = document.importNode(node, true);
        parent.insertBefore(created, ref);
        if (ctx.animate && created.nodeType === 1 && created.hasAttribute("data-sqb-sig")) flash(created, "added");
      }
    });
  }

  // Drop the flash classes once the animation ends, so the next one restarts cleanly.
  region.addEventListener("animationend", function (event) {
    var row = event.target.closest && event.target.closest("tr");
    if (row && /^sqb-(added|flash)/.test(event.animationName)) FLASH.forEach(function (c) { row.classList.remove(c); });
  });

  function update(html) {
    var animate = !!region.querySelector("[data-sqb-sig]");
    var template = document.createElement("template");
    template.innerHTML = html;
    try {
      syncChildren(region, template.content, { animate: animate });
    } catch (error) {
      region.innerHTML = html;
    }
    restoreRows();
  }

  function userIsBusy() {
    var active = document.activeElement;
    if (active && region.contains(active) && (active.tagName === "INPUT" || active.tagName === "SELECT")) return true;
    var selection = window.getSelection && window.getSelection();
    return !!(selection && !selection.isCollapsed && region.contains(selection.anchorNode));
  }

  function refresh(force) {
    if (busy || (!force && (document.hidden || userIsBusy()))) return;
    busy = true;
    render();
    var headers = { "Accept": "text/html" };
    headers[root.getAttribute("data-partial-header")] = "1";
    fetch(window.location.href, { headers: headers, credentials: "same-origin", cache: "no-store", redirect: "manual" })
      .then(function (response) {
        if (!response.ok) throw new Error(response.status || "redirect");
        return response.text();
      })
      .then(function (html) {
        update(html);
        failed = false;
        lastUpdate = new Date();
      })
      .catch(function (error) {
        failed = true;
        liveText.textContent = t("error", { status: error.message });
      })
      .then(function () {
        busy = false;
        countdown = interval;
        render();
      });
  }

  pollSelect.addEventListener("change", function () {
    interval = parseInt(pollSelect.value, 10) || 0;
    store.set("sqb-poll", String(interval));
    countdown = interval;
    render();
  });
  refreshBtn.addEventListener("click", function () { refresh(true); });
  document.addEventListener("visibilitychange", function () {
    if (!document.hidden && interval > 0 && (new Date() - lastUpdate) / 1000 >= interval) refresh(false);
  });

  setInterval(function () {
    if (interval === 0 || busy || document.hidden) return;
    countdown -= 1;
    if (countdown <= 0) refresh(false); else render();
  }, 1000);

  render();
})();
