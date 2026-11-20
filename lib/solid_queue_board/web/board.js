// Solid Queue Board: theme, auto-refresh polling, expandable rows, confirmations.
// Plain JS, no dependencies. Polling fetches the same URL with a header: the jobs page gets JSON with one
// HTML fragment per row (rows are inserted, updated and removed one by one); other pages get HTML that is
// morphed in place (only new, changed and removed nodes are touched).
(function () {
  "use strict";

  var root = document.getElementById("sqb");
  if (!root) return;

  var region = document.getElementById("sqb-region");
  var themeBtn = document.getElementById("sqb-theme");
  var live = document.getElementById("sqb-live");
  var liveLabel = document.getElementById("sqb-live-label");
  var liveStatus = document.getElementById("sqb-live-status");

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

  /* ---------- theme: one button cycles system, light, dark ---------- */
  var THEMES = ["system", "light", "dark"];
  var THEME_ICONS = { system: "\u25D0", light: "\u2600", dark: "\u263E" };
  function applyTheme(value) {
    if (value === "light" || value === "dark") document.documentElement.setAttribute("data-theme", value);
    else document.documentElement.removeAttribute("data-theme");
    var label = t("theme") + ": " + t("theme-" + value);
    themeBtn.textContent = THEME_ICONS[value];
    themeBtn.title = label;
    themeBtn.setAttribute("aria-label", label);
  }
  var theme = store.get("sqb-theme", "system");
  if (THEMES.indexOf(theme) < 0) theme = "system";
  applyTheme(theme);
  themeBtn.addEventListener("click", function () {
    theme = THEMES[(THEMES.indexOf(theme) + 1) % THEMES.length];
    store.set("sqb-theme", theme);
    applyTheme(theme);
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
  var intervals = (root.getAttribute("data-poll-intervals") || "0").split(",").map(function (v) { return parseInt(v, 10) || 0; });
  var interval = parseInt(store.get("sqb-poll", root.getAttribute("data-poll-default")), 10) || 0;
  if (intervals.indexOf(interval) < 0) interval = parseInt(root.getAttribute("data-poll-default"), 10) || 0;
  var countdown = interval;
  var lastUpdate = new Date();
  var busy = false;
  var failed = false;

  // The live button shows the interval; the full status goes to its title and to a screen reader region.
  function render() {
    live.classList.toggle("off", interval === 0);
    live.classList.toggle("busy", busy);
    live.classList.toggle("error", !!failed);
    liveLabel.textContent = interval === 0 ? t("off") : interval + " s";
    if (busy) return;
    var status;
    if (failed) status = failed;
    else if (interval === 0) status = t("off") + " \u00B7 " + t("updated", { time: clock(lastUpdate) });
    else status = t("updated", { time: clock(lastUpdate) }) + " \u00B7 " + t("next", { seconds: countdown });
    live.title = status + "\n" + t("change");
    if (liveStatus.textContent !== status && (failed || countdown === interval)) liveStatus.textContent = status;
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
        if (ctx.animate && created.nodeType === 1 && created.hasAttribute("data-sqb-sig")) {
          flash(created, "added");
        }
      }
    });
  }

  // Drop the flash classes once the animation ends, so the next one restarts cleanly.
  region.addEventListener("animationend", function (event) {
    var row = event.target.closest && event.target.closest("tr");
    if (!row) return;
    if (/^sqb-(added|flash)/.test(event.animationName)) FLASH.forEach(function (c) { row.classList.remove(c); });
  });

  // New rows grow from zero height: each cell's content goes into a temporary wrapper whose height
  // is animated, so the rows below move down with it. Layout animation: works on tables everywhere.
  var reduceMotion = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)");
  var GROW_MS = 450;
  function growRow(row) {
    if (!row.animate || (reduceMotion && reduceMotion.matches)) return;
    var cells = slice.call(row.cells);
    var wraps = cells.map(function (cell) {
      var wrap = document.createElement("div");
      wrap.className = "sqb-grow";
      while (cell.firstChild) wrap.appendChild(cell.firstChild);
      cell.appendChild(wrap);
      return wrap;
    });
    var heights = wraps.map(function (wrap) { return wrap.offsetHeight; });
    var easing = "cubic-bezier(.2, .7, .2, 1)";
    var pending = cells.length;
    cells.forEach(function (cell, i) {
      var style = getComputedStyle(cell);
      cell.animate([{ paddingTop: "0px", paddingBottom: "0px" }, { paddingTop: style.paddingTop, paddingBottom: style.paddingBottom }],
                   { duration: GROW_MS, easing: easing });
      wraps[i].animate([{ height: "0px", opacity: 0 }, { height: heights[i] + "px", opacity: 1 }], { duration: GROW_MS, easing: easing })
        .onfinish = function () {
          // put the content back as the server sent it
          var wrap = wraps[i];
          if (--pending === 0) row.classList.remove("entering");
          if (wrap.parentNode !== cell) return; // a refresh already replaced this cell
          while (wrap.firstChild) cell.insertBefore(wrap.firstChild, wrap);
          wrap.remove();
        };
    });
  }

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

  /* ---------- jobs page: JSON with one HTML fragment per row ---------- */
  function fragment(html) {
    var template = document.createElement("template");
    template.innerHTML = html || "";
    return template.content;
  }
  function elements(content) { return slice.call(content.childNodes).filter(function (n) { return n.nodeType === 1; }); }

  function applyJobs(data) {
    var tbody = document.getElementById("sqb-rows");
    var animate = !!tbody.querySelector("[data-sqb-sig]");
    var ctx = { animate: animate };

    var nav = region.querySelector("nav.tabs"), newNav = elements(fragment(data.nav))[0];
    if (nav && newNav) syncNode(nav, newNav, ctx);
    syncChildren(document.getElementById("sqb-toolbar"), fragment(data.toolbar), ctx);
    syncChildren(document.getElementById("sqb-pager"), fragment(data.pager), ctx);

    var keep = new Set(), ref = tbody.firstChild, grown = [];
    function place(node) {
      if (node === ref) ref = ref.nextSibling; else tbody.insertBefore(node, ref);
      keep.add(node);
    }
    data.rows.forEach(function (item) {
      var row = tbody.querySelector('tr[data-sqb-toggle="' + item.id + '"]');
      var detail = document.getElementById("sqb-detail-" + item.id);
      if (row && detail) {
        if (row.sqbHtml !== item.html) {
          var fresh = elements(fragment(item.html));
          syncNode(row, fresh[0], ctx);
          if (fresh[1]) syncNode(detail, fresh[1], ctx);
          row.sqbHtml = item.html;
        }
        place(row);
        place(detail);
      } else {
        var created = elements(fragment(item.html));
        created.forEach(place);
        created[0].sqbHtml = item.html;
        if (animate) {
          flash(created[0], "added");
          created[0].classList.add("entering");
          grown.push(created[0]);
        }
      }
    });
    if (data.empty) {
      var empty = tbody.querySelector("tr.empty-row") || elements(fragment(data.empty))[0];
      place(empty);
    }
    slice.call(tbody.childNodes).forEach(function (node) { if (!keep.has(node)) tbody.removeChild(node); });

    restoreRows();
    grown.forEach(growRow);
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
    var json = !!document.getElementById("sqb-rows");
    var headers = { "Accept": json ? "application/json" : "text/html" };
    headers[root.getAttribute("data-partial-header")] = "1";
    fetch(window.location.href, { headers: headers, credentials: "same-origin", cache: "no-store", redirect: "manual" })
      .then(function (response) {
        if (!response.ok) throw new Error(response.status || "redirect");
        return json ? response.json() : response.text();
      })
      .then(function (body) {
        if (json) applyJobs(body); else update(body);
        failed = false;
        lastUpdate = new Date();
      })
      .catch(function (error) {
        failed = t("error", { status: error.message });
      })
      .then(function () {
        busy = false;
        countdown = interval;
        render();
      });
  }

  // Each click moves to the next interval and refreshes right away.
  live.addEventListener("click", function () {
    interval = intervals[(intervals.indexOf(interval) + 1) % intervals.length];
    store.set("sqb-poll", String(interval));
    refresh(true);
  });
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
