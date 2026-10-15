// Dashboard: searches every service bundled into data.js by scripts/build-dashboard-data.ps1.
// Nothing here is specific to one service. Any dataExports/<service>/ that follows the shared format
// (index.json + <folder>/metadata.json + content.md) shows up automatically after the script is rerun.
(function () {
  "use strict";

  // Display names and badge colors for known services. Unknown services get a name from their
  // folder and a stable color from FALLBACK_COLORS, so new services need no code change.
  var SERVICES = {
    notion: { name: "Notion", color: "#37352f" },
    jira:   { name: "Jira",   color: "#0052cc" },
    github: { name: "GitHub", color: "#6639ba" },
    slack:  { name: "Slack",  color: "#611f69" },
    gdrive: { name: "Google Drive", color: "#188038" },
    gmail:  { name: "Gmail",  color: "#c5221f" }
  };
  var FALLBACK_COLORS = ["#b35900", "#00787a", "#8a3ffc", "#a2191f", "#005d5d", "#6f6f00", "#9f1853", "#1d5ab8"];

  // metadata.json fields that describe the download, not the item. Not searched or shown as metadata.
  var HIDDEN_FIELDS = ["schema_version", "service", "id", "url", "title", "icon", "content_file", "download_request",
    "supporting_requests", "downloaded_at", "created_time", "last_edited_time", "cloud_id", "comment_count"];

  var $ = function (id) { return document.getElementById(id); };
  var state = { q: "", service: "all", open: null };
  var items = [], services = [];

  // ---------- helpers ----------

  function escapeHtml(s) {
    return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }

  function serviceInfo(key) {
    if (SERVICES[key]) return SERVICES[key];
    var h = 0;
    for (var i = 0; i < key.length; i++) h = (h * 31 + key.charCodeAt(i)) >>> 0;
    var name = key.replace(/[-_]+/g, " ").replace(/\b\w/g, function (c) { return c.toUpperCase(); });
    return (SERVICES[key] = { name: name, color: FALLBACK_COLORS[h % FALLBACK_COLORS.length] });
  }

  function badge(key) {
    var s = serviceInfo(key);
    return '<span class="badge" style="--badge:' + s.color + '">' + escapeHtml(s.name) + "</span>";
  }

  function humanize(key) {
    var s = key.replace(/_/g, " ");
    return s.charAt(0).toUpperCase() + s.slice(1);
  }

  // Turn a metadata value into readable text: people -> name, parent -> "KEY — title", arrays -> list.
  function valueText(v) {
    if (v === null || v === undefined || v === "") return "";
    if (Array.isArray(v)) return v.map(valueText).filter(Boolean).join(", ");
    if (typeof v === "object") {
      var label = v.name || v.title || v.login || v.display_name || "";
      if (v.key && v.key !== label) label = label ? v.key + " — " + label : v.key;
      return String(label);
    }
    return String(v);
  }

  function metaFields(meta) {
    var out = [];
    Object.keys(meta).forEach(function (k) {
      if (HIDDEN_FIELDS.indexOf(k) !== -1 || /_precision$/.test(k)) return;
      var text = valueText(meta[k]);
      if (text) out.push({ label: humanize(k), value: text });
    });
    return out;
  }

  function parseDate(s) {
    if (!s) return null;
    if (/^\d{4}-\d{2}-\d{2}$/.test(s)) return { date: new Date(s + "T00:00:00Z"), dayOnly: true };
    var d = new Date(s);
    return isNaN(d) ? null : { date: d, dayOnly: false };
  }

  function formatDate(s, withTime) {
    var p = parseDate(s);
    if (!p) return s || "";
    var opts = { year: "numeric", month: "short", day: "numeric" };
    if (p.dayOnly) opts.timeZone = "UTC";
    else if (withTime) { opts.hour = "numeric"; opts.minute = "2-digit"; }
    return p.date.toLocaleString(undefined, opts);
  }

  // Markdown -> plain text for snippets and search.
  function plainText(md) {
    return md
      .replace(/```[\s\S]*?```/g, " ")
      .replace(/^\s*\|?\s*:?-{2,}.*$/gm, " ")
      .replace(/!?\[([^\]]*)\]\([^)]*\)/g, "$1")
      .replace(/\\([\\`*_{}\[\]()#+\-.!|~$<>])/g, "$1")
      .replace(/^\s*(#{1,6}|>|[-*+]\s+\[[ xX]\]|[-*+]|\d+[.)])\s+/gm, "")
      .replace(/[*_`|~]+/g, " ")
      .replace(/\s+/g, " ")
      .trim();
  }

  // Query -> lowercase terms. "Quoted text" is one exact phrase; other words are separate terms.
  function parseQuery(q) {
    var terms = [], re = /"([^"]+)"|(\S+)/g, m;
    while ((m = re.exec(q))) {
      var t = (m[1] || m[2]).trim().toLowerCase();
      if (t && terms.indexOf(t) === -1) terms.push(t);
    }
    return terms;
  }

  function termRegex(terms) {
    var parts = terms.slice().sort(function (a, b) { return b.length - a.length; })
      .map(function (t) { return t.replace(/[.*+?^${}()|[\]\\]/g, "\\$&").replace(/\s+/g, "\\s+"); });
    return parts.length ? new RegExp("(" + parts.join("|") + ")", "gi") : null;
  }

  function highlight(text, re) {
    if (!re) return escapeHtml(text);
    return text.split(re).map(function (part, i) {
      return i % 2 ? "<mark>" + escapeHtml(part) + "</mark>" : escapeHtml(part);
    }).join("");
  }

  function count(hay, term) {
    var n = 0, i = hay.indexOf(term);
    while (i !== -1 && n < 50) { n++; i = hay.indexOf(term, i + term.length); }
    return n;
  }

  // ---------- data ----------

  function load() {
    var data = window.DASHBOARD_DATA;
    if (!data || !data.services) return false;
    data.services.forEach(function (svc) {
      if (!svc.items || !svc.items.length) return;
      services.push(svc.service);
      svc.items.forEach(function (it) {
        var meta = it.metadata || {};
        var title = meta.title || it.folder;
        var content = it.content || "";
        // Drop the "# <title>" first line; the title is shown separately.
        var body = content.replace(/^﻿?#\s+[^\n]*\n+/, "");
        var plain = plainText(body);
        // Snippets prefer prose over tables (Jira repeats its fields in a table at the top).
        var prose = plainText(body.replace(/^\s*\|.*$/gm, ""));
        var fields = metaFields(meta);
        var metaText = fields.map(function (f) { return f.value; }).join("\n");
        items.push({
          uid: svc.service + ":" + (meta.id || it.folder),
          service: svc.service,
          folder: it.folder,
          meta: meta,
          title: title,
          body: body,
          hasContent: it.content !== null && it.content !== undefined,
          plain: plain,
          prose: prose,
          fields: fields,
          titleL: title.toLowerCase(),
          metaL: metaText.toLowerCase(),
          plainL: plain.toLowerCase(),
          date: meta.created_time || meta.last_edited_time || "",
          sortTime: (parseDate(meta.created_time || meta.last_edited_time) || { date: new Date(0) }).date.getTime()
        });
      });
    });
    return true;
  }

  // ---------- search ----------

  function search() {
    var terms = parseQuery(state.q);
    var results = [];
    items.forEach(function (it) {
      var score = 0;
      for (var i = 0; i < terms.length; i++) {
        var t = terms[i];
        var inTitle = count(it.titleL, t), inMeta = count(it.metaL, t), inBody = count(it.plainL, t);
        if (!inTitle && !inMeta && !inBody) return; // every term must match somewhere
        score += inTitle * 20 + inMeta * 5 + Math.min(inBody, 20);
      }
      if (terms.length > 1) {
        var phrase = terms.join(" ");
        if (it.titleL.indexOf(phrase) !== -1) score += 50;
        if (it.plainL.indexOf(phrase) !== -1) score += 10;
      }
      results.push({ item: it, score: score });
    });
    results.sort(function (a, b) {
      return (b.score - a.score) || (b.item.sortTime - a.item.sortTime) || (a.item.title < b.item.title ? -1 : 1);
    });
    return { terms: terms, results: results };
  }

  function firstMatch(text, terms) {
    var pos = -1;
    terms.forEach(function (t) {
      var m = new RegExp(t.replace(/[.*+?^${}()|[\]\\]/g, "\\$&").replace(/\s+/g, "\\s+"), "i").exec(text);
      if (m && (pos === -1 || m.index < pos)) pos = m.index;
    });
    return pos;
  }

  function snippet(it, terms, re) {
    var text = it.prose, pos = firstMatch(text, terms);
    if (pos === -1 && terms.length) { text = it.plain; pos = firstMatch(text, terms); }
    var html = "";
    if (pos !== -1 || !terms.length) {
      var start = Math.max(0, (pos === -1 ? 0 : pos) - 60);
      if (start > 0) { var sp = text.indexOf(" ", start); if (sp !== -1 && sp < start + 20) start = sp + 1; }
      var piece = text.slice(start, start + 240);
      html = (start > 0 ? "… " : "") + highlight(piece, re) + (start + 240 < text.length ? " …" : "");
    }
    // Show the metadata fields that matched, e.g. "Assignee: Joe Smith".
    var matched = terms.length ? it.fields.filter(function (f) {
      var v = f.value.toLowerCase();
      return terms.some(function (t) { return v.indexOf(t) !== -1; });
    }) : [];
    if (matched.length) {
      html += '<span class="meta-hits">' + matched.slice(0, 4).map(function (f) {
        return "<span>" + escapeHtml(f.label) + ": " + highlight(f.value, re) + "</span>";
      }).join("") + "</span>";
    }
    if (!html) html = highlight(text.slice(0, 240), re);
    return html;
  }

  // ---------- rendering ----------

  function renderFilters(counts) {
    var total = 0;
    services.forEach(function (s) { total += counts[s] || 0; });
    var html = '<button type="button" data-service="all" aria-pressed="' + (state.service === "all") + '">All services <span class="count">' + total + "</span></button>";
    services.forEach(function (s) {
      var info = serviceInfo(s);
      html += '<button type="button" data-service="' + escapeHtml(s) + '" aria-pressed="' + (state.service === s) +
        '" style="--badge:' + info.color + '"><span class="dot"></span>' + escapeHtml(info.name) +
        ' <span class="count">' + (counts[s] || 0) + "</span></button>";
    });
    $("filters").innerHTML = html;
  }

  function renderResults() {
    var r = search(), re = termRegex(r.terms), counts = {};
    r.results.forEach(function (x) { counts[x.item.service] = (counts[x.item.service] || 0) + 1; });
    renderFilters(counts);

    var shown = r.results.filter(function (x) { return state.service === "all" || x.item.service === state.service; });
    var where = state.service === "all" ? "all services" : serviceInfo(state.service).name;
    $("summary").textContent = r.terms.length
      ? shown.length + (shown.length === 1 ? " result" : " results") + " for “" + state.q.trim() + "” in " + where
      : shown.length + " items in " + where + " (newest first). Type to search.";

    if (!shown.length) {
      $("results").innerHTML = '<li class="empty">No matches. Try fewer words, or pick “All services”.</li>';
      return;
    }
    $("results").innerHTML = shown.map(function (x) {
      var it = x.item, m = it.meta;
      var extra = m.key ? '<span class="key">' + escapeHtml(m.key) + "</span>" : "";
      var status = m.status ? '<span class="pill">' + escapeHtml(m.status) + "</span>" : "";
      var link = m.url ? '<a class="orig" href="' + escapeHtml(m.url) + '" target="_blank" rel="noopener noreferrer">Open in ' + escapeHtml(serviceInfo(it.service).name) + " ↗</a>" : "";
      return '<li class="result' + (state.open === it.uid ? " active" : "") + '" data-uid="' + escapeHtml(it.uid) + '">' +
        '<div class="result-head">' + badge(it.service) + extra + status +
        '<time datetime="' + escapeHtml(it.date) + '">' + escapeHtml(formatDate(it.date)) + "</time></div>" +
        '<h2><button type="button" class="open" data-uid="' + escapeHtml(it.uid) + '">' + (m.icon ? escapeHtml(m.icon) + " " : "") + highlight(it.title, re) + "</button></h2>" +
        '<p class="snippet">' + snippet(it, r.terms, re) + "</p>" + link + "</li>";
    }).join("");
  }

  function highlightNodes(root, re) {
    if (!re) return;
    var walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, null), nodes = [], n;
    while ((n = walker.nextNode())) nodes.push(n);
    nodes.forEach(function (node) {
      re.lastIndex = 0;
      if (!re.test(node.nodeValue)) return;
      var span = document.createElement("span");
      span.innerHTML = highlight(node.nodeValue, re);
      node.parentNode.replaceChild(span, node);
    });
  }

  function renderDetail() {
    var it = null;
    for (var i = 0; i < items.length; i++) if (items[i].uid === state.open) it = items[i];
    document.body.classList.toggle("detail-open", !!it);
    if (!it) { $("detail").innerHTML = '<p class="placeholder">Select a result to read it here.</p>'; return; }

    var m = it.meta, info = serviceInfo(it.service);
    var rows = [];
    if (m.created_time) rows.push({ label: "Created", value: formatDate(m.created_time, true) });
    if (m.last_edited_time) rows.push({ label: "Last edited", value: formatDate(m.last_edited_time, true) });
    rows = rows.concat(it.fields);
    rows.push({ label: "Local copy", value: "dataExports/" + it.service + "/" + it.folder + "/" });

    var contentHtml;
    if (it.hasContent) contentHtml = window.renderMarkdown(it.body);
    else {
      var file = "../dataExports/" + encodeURIComponent(it.service) + "/" + encodeURIComponent(it.folder) + "/" + encodeURIComponent(m.content_file || "");
      contentHtml = '<p class="placeholder">This item’s content is not text (' + escapeHtml(m.content_file || "no content file") + ").</p>" +
        (m.content_file ? '<p><a href="' + file + '" target="_blank">Open the local file</a></p>' : "");
    }

    $("detail").innerHTML =
      '<button type="button" class="back" id="back">← Back to results</button>' +
      '<div class="detail-head">' + badge(it.service) + (m.key ? '<span class="key">' + escapeHtml(m.key) + "</span>" : "") + "</div>" +
      "<h1>" + (m.icon ? escapeHtml(m.icon) + " " : "") + escapeHtml(it.title) + "</h1>" +
      (m.url ? '<p><a class="orig big" href="' + escapeHtml(m.url) + '" target="_blank" rel="noopener noreferrer">Open original in ' + escapeHtml(info.name) + " ↗</a></p>" : "") +
      '<dl class="meta">' + rows.map(function (f) {
        return "<div><dt>" + escapeHtml(f.label) + "</dt><dd>" + escapeHtml(f.value) + "</dd></div>";
      }).join("") + "</dl>" +
      '<article class="markdown" id="content">' + contentHtml + "</article>";
    highlightNodes($("content"), termRegex(parseQuery(state.q)));
    $("detail").scrollTop = 0;
  }

  // ---------- state <-> URL (#q=...&service=...&open=...) ----------

  function readHash() {
    var p = new URLSearchParams(location.hash.slice(1));
    state.q = p.get("q") || "";
    state.service = p.get("service") || "all";
    if (state.service !== "all" && services.indexOf(state.service) === -1) state.service = "all";
    state.open = p.get("open") || null;
  }

  function writeHash() {
    var p = new URLSearchParams();
    if (state.q) p.set("q", state.q);
    if (state.service !== "all") p.set("service", state.service);
    if (state.open) p.set("open", state.open);
    var h = p.toString();
    try { history.replaceState(null, "", h ? "#" + h : location.pathname + location.search); } catch (e) { /* some file:// setups */ }
  }

  function update(changes, opts) {
    Object.keys(changes).forEach(function (k) { state[k] = changes[k]; });
    writeHash();
    renderResults();
    if (!opts || opts.detail !== false) renderDetail();
  }

  // ---------- start ----------

  function init() {
    if (!load()) {
      $("summary").innerHTML = "No data found. Run <code>scripts/build-dashboard-data.ps1</code> to create <code>webapp/data.js</code>, then reload this page. See webapp/README.md.";
      return;
    }
    if (!items.length) {
      $("summary").textContent = "No downloaded items yet. Download data into dataExports/, then rerun scripts/build-dashboard-data.ps1.";
      return;
    }
    var gen = window.DASHBOARD_DATA.generated_at;
    $("generated").textContent = items.length + " items from " + services.length + (services.length === 1 ? " service" : " services") +
      " · data bundled " + formatDate(gen, true);

    readHash();
    $("q").value = state.q;
    renderResults();
    renderDetail();

    $("q").addEventListener("input", function () { update({ q: this.value }, { detail: false }); refreshDetailHighlight(); });
    $("search-form").addEventListener("submit", function (e) { e.preventDefault(); });
    $("filters").addEventListener("click", function (e) {
      var b = e.target.closest("button[data-service]");
      if (b) update({ service: b.getAttribute("data-service") }, { detail: false });
    });
    $("results").addEventListener("click", function (e) {
      if (e.target.closest("a")) return; // let "Open in …" links work normally
      var li = e.target.closest("[data-uid]");
      if (li) update({ open: li.getAttribute("data-uid") });
    });
    $("detail").addEventListener("click", function (e) {
      if (e.target.id === "back") update({ open: null });
    });
    document.addEventListener("keydown", function (e) {
      if (e.key === "/" && document.activeElement !== $("q")) { e.preventDefault(); $("q").focus(); }
      if (e.key === "Escape" && state.open) update({ open: null });
    });
    window.addEventListener("hashchange", function () { readHash(); $("q").value = state.q; renderResults(); renderDetail(); });
  }

  var highlightTimer;
  function refreshDetailHighlight() {
    clearTimeout(highlightTimer);
    if (state.open) highlightTimer = setTimeout(renderDetail, 250);
  }

  init();
})();
