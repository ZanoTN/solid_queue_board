// Solid Queue Board: theme, auto-refresh polling, expandable rows, confirmations.
// Plain JS, no dependencies. Polling fetches the same URL with a header and swaps the live region.
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

  function signatures() {
    var map = {};
    region.querySelectorAll("[data-sqb-sig]").forEach(function (row) {
      map[row.getAttribute("data-sqb-toggle")] = row.getAttribute("data-sqb-sig");
    });
    return map;
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
    var before = signatures();
    var headers = { "Accept": "text/html" };
    headers[root.getAttribute("data-partial-header")] = "1";
    fetch(window.location.href, { headers: headers, credentials: "same-origin", cache: "no-store", redirect: "manual" })
      .then(function (response) {
        if (!response.ok) throw new Error(response.status || "redirect");
        return response.text();
      })
      .then(function (html) {
        var scrollX = (region.querySelector(".tbl-wrap") || {}).scrollLeft || 0;
        region.innerHTML = html;
        var wrap = region.querySelector(".tbl-wrap");
        if (wrap) wrap.scrollLeft = scrollX;
        restoreRows();
        region.querySelectorAll("[data-sqb-sig]").forEach(function (row) {
          var id = row.getAttribute("data-sqb-toggle");
          if (Object.keys(before).length && before[id] !== row.getAttribute("data-sqb-sig")) row.classList.add("changed");
        });
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
