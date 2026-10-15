// Small, dependency-free Markdown renderer for the exported content.md files (works offline).
// Supports: headings, paragraphs (single newlines become line breaks, as in Notion), bold, italic,
// strikethrough, inline code, fenced code blocks, links, bulleted / numbered / nested lists,
// to-dos (- [ ] / - [x]), tables, blockquotes, horizontal rules and backslash escapes.
// All text is HTML-escaped first, so tags inside the content are shown as text, never run.
(function () {
  "use strict";

  function escapeHtml(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }

  function safeUrl(url) {
    var u = url.trim();
    if (/^(https?:|mailto:)/i.test(u) || /^[./#]/.test(u) || !/^[a-z][a-z0-9+.-]*:/i.test(u)) return u;
    return null; // javascript:, data:, etc.
  }

  function inline(text) {
    var slots = [];
    function keep(html) { slots.push(html); return "\u0000" + (slots.length - 1) + "\u0000"; }

    // Code spans and backslash escapes first, so nothing inside them is treated as formatting.
    var s = text.replace(/(`+)([\s\S]*?[^`])\1(?!`)/g, function (_, __, code) {
      return keep("<code>" + escapeHtml(code.trim()) + "</code>");
    });
    s = s.replace(/\\([\\`*_{}\[\]()#+\-.!|~$<>"'])/g, function (_, ch) { return keep(escapeHtml(ch)); });
    s = escapeHtml(s);

    // Links [text](url)
    s = s.replace(/\[([^\]]+)\]\(([^)\s]+)(?:\s+&quot;[^&]*&quot;)?\)/g, function (m, label, url) {
      var href = safeUrl(url.replace(/&amp;/g, "&"));
      if (!href) return label;
      return keep('<a href="' + escapeHtml(href) + '" target="_blank" rel="noopener noreferrer">') + label + keep("</a>");
    });
    // Bare URLs
    s = s.replace(/(^|[\s(])(https?:\/\/[^\s<)]+[^\s<).,;:!?])/g, function (_, pre, url) {
      return pre + keep('<a href="' + url + '" target="_blank" rel="noopener noreferrer">' + url + "</a>");
    });
    s = s.replace(/(\*\*|__)(?=\S)([\s\S]*?\S)\1/g, "<strong>$2</strong>");
    s = s.replace(/(^|[^*\w])\*(?=\S)([^*]*?\S)\*(?!\*)/g, "$1<em>$2</em>");
    s = s.replace(/(^|[^_\w])_(?=\S)([^_]*?\S)_(?![_\w])/g, "$1<em>$2</em>");
    s = s.replace(/~~(?=\S)([\s\S]*?\S)~~/g, "<del>$1</del>");

    return s.replace(/\u0000(\d+)\u0000/g, function (_, i) { return slots[+i]; });
  }

  var LIST_RE = /^(\s*)([-*+]|\d+[.)])\s+(.*)$/;

  function splitRow(line) {
    var row = line.trim().replace(/^\|/, "").replace(/\|$/, "");
    var cells = [], cur = "";
    for (var i = 0; i < row.length; i++) {
      if (row[i] === "\\" && row[i + 1] === "|") { cur += "\\|"; i++; }
      else if (row[i] === "|") { cells.push(cur.trim()); cur = ""; }
      else cur += row[i];
    }
    cells.push(cur.trim());
    return cells;
  }

  function renderList(lines) {
    // Build nested lists from indentation.
    var html = "", stack = []; // {indent, tag}
    lines.forEach(function (item) {
      while (stack.length && item.indent < stack[stack.length - 1].indent) {
        html += "</li></" + stack.pop().tag + ">";
      }
      var top = stack[stack.length - 1];
      if (!top || item.indent > top.indent) {
        stack.push({ indent: item.indent, tag: item.tag });
        html += "<" + item.tag + (item.task ? ' class="tasks"' : "") + ">";
      } else if (top.tag !== item.tag) {
        html += "</li></" + stack.pop().tag + "><" + item.tag + ">";
        stack.push({ indent: item.indent, tag: item.tag });
      } else {
        html += "</li>";
      }
      var body = item.text, task = /^\[([ xX])\]\s+([\s\S]*)$/.exec(body);
      if (task) {
        html += '<li class="task"><input type="checkbox" disabled' + (task[1] !== " " ? " checked" : "") + "> " + inline(task[2]);
      } else {
        html += "<li>" + inline(body);
      }
    });
    while (stack.length) html += "</li></" + stack.pop().tag + ">";
    return html;
  }

  function render(md) {
    var lines = md.replace(/\r\n?/g, "\n").split("\n");
    var out = [], i = 0;

    while (i < lines.length) {
      var line = lines[i];

      if (!line.trim()) { i++; continue; }

      var fence = /^\s*(```|~~~)\s*([\w+-]*)/.exec(line);
      if (fence) {
        var code = [];
        i++;
        while (i < lines.length && lines[i].trim().indexOf(fence[1]) !== 0) code.push(lines[i++]);
        i++;
        out.push("<pre><code>" + escapeHtml(code.join("\n")) + "</code></pre>");
        continue;
      }

      var h = /^(#{1,6})\s+(.*?)\s*#*\s*$/.exec(line);
      if (h) { out.push("<h" + h[1].length + ">" + inline(h[2]) + "</h" + h[1].length + ">"); i++; continue; }

      if (/^\s*([-*_])(\s*\1){2,}\s*$/.test(line)) { out.push("<hr>"); i++; continue; }

      if (/^\s*\|/.test(line) && i + 1 < lines.length && /^\s*\|?\s*:?-{2,}/.test(lines[i + 1])) {
        var head = splitRow(line), rows = [];
        i += 2;
        while (i < lines.length && /^\s*\|/.test(lines[i])) rows.push(splitRow(lines[i++]));
        out.push("<div class=\"table-wrap\"><table><thead><tr>" + head.map(function (c) { return "<th>" + inline(c) + "</th>"; }).join("") +
          "</tr></thead><tbody>" + rows.map(function (r) {
            return "<tr>" + r.map(function (c) { return "<td>" + inline(c) + "</td>"; }).join("") + "</tr>";
          }).join("") + "</tbody></table></div>");
        continue;
      }

      if (/^\s*>/.test(line)) {
        var quote = [];
        while (i < lines.length && /^\s*>/.test(lines[i])) quote.push(lines[i++].replace(/^\s*>\s?/, ""));
        out.push("<blockquote>" + render(quote.join("\n")) + "</blockquote>");
        continue;
      }

      if (LIST_RE.test(line)) {
        var items = [];
        while (i < lines.length) {
          var m = LIST_RE.exec(lines[i]);
          if (m) {
            items.push({ indent: m[1].replace(/\t/g, "    ").length, tag: /\d/.test(m[2]) ? "ol" : "ul", text: m[3], task: /^\[[ xX]\]\s/.test(m[3]) });
            i++;
          } else if (lines[i].trim() && /^\s+/.test(lines[i]) && items.length) {
            items[items.length - 1].text += " " + lines[i].trim(); // continuation line
            i++;
          } else if (!lines[i].trim() && i + 1 < lines.length && LIST_RE.test(lines[i + 1])) {
            i++; // blank line between items of the same list
          } else break;
        }
        out.push(renderList(items));
        continue;
      }

      var para = [];
      while (i < lines.length && lines[i].trim() && !/^(#{1,6}\s|\s*(```|~~~)|\s*>|\s*\|)/.test(lines[i]) && !LIST_RE.test(lines[i])) {
        para.push(lines[i++].trim());
      }
      if (!para.length) para.push(lines[i++].trim()); // safety: always advance
      out.push("<p>" + para.map(inline).join("<br>") + "</p>");
    }
    return out.join("\n");
  }

  window.renderMarkdown = render;
})();
