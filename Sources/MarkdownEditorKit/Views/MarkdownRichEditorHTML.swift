//
//  MarkdownRichEditorHTML.swift
//  MarkdownEditorKit
//
//  Created by Rouzbeh Abadi on 2026-04-25.
//

enum MarkdownRichEditorHTML {

    // The full HTML page loaded into the WKWebView-based rich editor.
    // JavaScript communicates back to Swift via three message handlers:
    //   • contentChanged  – posts the current Markdown string on every edit
    //   • selectionChanged – posts a {bold,italic,…} dictionary on cursor move
    //   • focusChanged    – posts a Bool (true = focused) on focus / blur
    static let template: String = #"""
    <!DOCTYPE html>
    <html>
    <head>
    <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
    <style>
    :root {
      --body-size: 16px;
      --text-color: #000000;
      --secondary-color: #888888;
    }
    * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
    html, body { margin: 0; padding: 0; background: transparent; }
    body {
      font-family: -apple-system, sans-serif;
      font-size: var(--body-size);
      color: var(--text-color);
      padding: 12px 16px 80px;
    }
    #editor { outline: none; min-height: 200px; word-wrap: break-word; -webkit-user-select: text; }
    h1 { font-size: 1.6em; margin: 0.4em 0 0.2em; }
    h2 { font-size: 1.4em; margin: 0.4em 0 0.2em; }
    h3 { font-size: 1.25em; margin: 0.4em 0 0.2em; }
    h4 { font-size: 1.15em; margin: 0.3em 0 0.15em; }
    h5 { font-size: 1.08em; margin: 0.3em 0 0.15em; }
    h6 { font-size: 1.0em;  margin: 0.3em 0 0.15em; }
    p  { margin: 0; min-height: 1.4em; }
    code {
      font-family: ui-monospace, monospace;
      background: rgba(0,0,0,0.07);
      border-radius: 3px;
      padding: 0.1em 0.3em;
      font-size: 0.9em;
    }
    pre {
      background: rgba(0,0,0,0.07);
      border-radius: 6px;
      padding: 10px 14px;
      overflow-x: auto;
      margin: 0.4em 0;
    }
    pre code { background: none; padding: 0; border-radius: 0; }
    blockquote {
      border-left: 3px solid var(--secondary-color);
      margin: 0.4em 0;
      padding: 0.2em 0 0.2em 1em;
      color: var(--secondary-color);
    }
    ul, ol { padding-left: 1.5em; margin: 0.2em 0; }
    li { margin: 0.1em 0; }
    li:has(> input[type=checkbox]) { list-style: none; }
    li input[type=checkbox] {
      width: 20px; height: 20px;
      margin-right: 0.5em;
      vertical-align: middle;
      cursor: pointer;
    }
    hr { border: none; border-top: 1px solid var(--secondary-color); margin: 0.8em 0; }
    a  { color: #007AFF; text-decoration: underline; }
    </style>
    </head>
    <body>
    <div id="editor" contenteditable="true" spellcheck="true"></div>
    <script>
    'use strict';

    const editor = document.getElementById('editor');
    let _lastMD = '';
    let _suppressing = false;
    // Selection captured when the host opens the link sheet, restored when the
    // host calls applyLink / removeLink. The sheet steals focus from the
    // WebView, which collapses the selection — so we save it ourselves.
    let _savedLinkRange = null;

    document.execCommand('defaultParagraphSeparator', false, 'p');

    // ── Swift ↔ JS bridge ────────────────────────────────────────────────────

    function post(name, body) {
      if (window.webkit && window.webkit.messageHandlers[name]) {
        window.webkit.messageHandlers[name].postMessage(body);
      }
    }

    // ── Exposed to Swift ─────────────────────────────────────────────────────

    function setContent(html) {
      _suppressing = true;
      editor.innerHTML = html || '<p><br></p>';
      _suppressing = false;
      _lastMD = getMarkdown();
    }

    function getMarkdown() {
      let md = blockMD(editor).replace(/\u200B/g, '').trim();
      return md.replace(/\n{3,}/g, '\n\n');
    }

    function setStyle(fontSize, textColor, secondaryColor) {
      document.documentElement.style.setProperty('--body-size', fontSize + 'px');
      document.documentElement.style.setProperty('--text-color', textColor);
      document.documentElement.style.setProperty('--secondary-color', secondaryColor);
    }

    // ── Formatting actions ───────────────────────────────────────────────────

    function execCmd(cmd, val) {
      editor.focus();
      document.execCommand(cmd, false, val !== undefined ? val : null);
    }

    // For collapsed selections inside an inline format element, "exit" the
    // element by inserting a zero-width-space text node *outside* it and
    // placing the cursor inside that node. WebKit boundary rules then make
    // the next typed character unformatted, queryCommandState flips to false
    // (so the toolbar deselects), and the marker is stripped from the
    // exported Markdown by getMarkdown().
    function _exitInlineFormat(tagNames) {
      const sel = window.getSelection();
      if (!sel || !sel.rangeCount || !sel.isCollapsed) return false;
      let node = sel.getRangeAt(0).startContainer;
      let inline = null;
      while (node && node !== editor) {
        if (node.nodeType === Node.ELEMENT_NODE && tagNames.includes(node.tagName.toLowerCase())) {
          inline = node; break;
        }
        node = node.parentNode;
      }
      if (!inline) return false;
      const zw = document.createTextNode('\u200B');
      inline.parentNode.insertBefore(zw, inline.nextSibling);
      const r = document.createRange();
      r.setStart(zw, 1);
      r.collapse(true);
      sel.removeAllRanges();
      sel.addRange(r);
      return true;
    }

    // For collapsed selections that aren't already inside the format, insert
    // an empty <tag> at the cursor with a zero-width space inside it and park
    // the cursor in that zw node. The next typed character is appended into
    // the inline element, so it picks up the format — even after the toolbar
    // tap caused the WebView to briefly lose focus (which kills WebKit's
    // built-in typing style).
    function _enterInlineFormat(tagName) {
      const sel = window.getSelection();
      if (!sel || !sel.rangeCount || !sel.isCollapsed) return false;
      const el = document.createElement(tagName);
      const zw = document.createTextNode('\u200B');
      el.appendChild(zw);
      sel.getRangeAt(0).insertNode(el);
      const r = document.createRange();
      r.setStart(zw, 1);
      r.collapse(true);
      sel.removeAllRanges();
      sel.addRange(r);
      return true;
    }

    function applyBold() {
      editor.focus();
      const sel = window.getSelection();
      if (sel && sel.rangeCount && !sel.isCollapsed) {
        document.execCommand('bold', false, null);
        return;
      }
      if (_exitInlineFormat(['b', 'strong'])) { _reportSelection(); return; }
      _enterInlineFormat('b');
      _reportSelection();
    }
    function applyItalic() {
      editor.focus();
      const sel = window.getSelection();
      if (sel && sel.rangeCount && !sel.isCollapsed) {
        document.execCommand('italic', false, null);
        return;
      }
      if (_exitInlineFormat(['i', 'em'])) { _reportSelection(); return; }
      _enterInlineFormat('i');
      _reportSelection();
    }
    function applyStrikethrough() {
      editor.focus();
      const sel = window.getSelection();
      if (sel && sel.rangeCount && !sel.isCollapsed) {
        document.execCommand('strikeThrough', false, null);
        return;
      }
      if (_exitInlineFormat(['s', 'strike', 'del'])) { _reportSelection(); return; }
      _enterInlineFormat('s');
      _reportSelection();
    }
    function applyHeading(n) {
      const cur = document.queryCommandValue('formatBlock').toLowerCase();
      execCmd('formatBlock', cur === 'h' + n ? 'p' : 'h' + n);
    }
    function applyParagraph()    { execCmd('formatBlock', 'p'); }
    function applyBulletList()   { execCmd('insertUnorderedList'); }
    function applyNumberedList() { execCmd('insertOrderedList'); }
    function applyQuote() {
      const cur = document.queryCommandValue('formatBlock').toLowerCase();
      execCmd('formatBlock', cur === 'blockquote' ? 'p' : 'blockquote');
    }
    function insertHR() {
      execCmd('insertHorizontalRule');
      // WebKit leaves the cursor trapped inside the <hr>. Find the last
      // inserted HR, ensure a paragraph follows it, then move the cursor there.
      const hrs = editor.querySelectorAll('hr');
      if (!hrs.length) { _reportChange(); return; }
      const hr = hrs[hrs.length - 1];
      let after = hr.nextSibling;
      if (!after || (after.nodeType === Node.ELEMENT_NODE && after.tagName.toLowerCase() === 'hr')) {
        const p = document.createElement('p');
        p.innerHTML = '<br>';
        hr.parentNode.insertBefore(p, hr.nextSibling);
        after = p;
      }
      const r = document.createRange();
      r.setStart(after, 0);
      r.collapse(true);
      const s = window.getSelection();
      s.removeAllRanges();
      s.addRange(r);
      _reportChange();
    }

    function applyInlineCode() {
      const sel = window.getSelection();
      if (!sel || !sel.rangeCount || sel.isCollapsed) return;
      const range = sel.getRangeAt(0);
      const code = document.createElement('code');
      try { range.surroundContents(code); _reportChange(); } catch(_) {}
    }

    function applyCodeBlock() {
      const sel = window.getSelection();
      if (!sel || !sel.rangeCount) return;
      const text = sel.toString();
      const pre = document.createElement('pre');
      const code = document.createElement('code');
      code.textContent = text || 'code';
      pre.appendChild(code);
      const range = sel.getRangeAt(0);
      range.deleteContents();
      range.insertNode(pre);
      _reportChange();
    }

    function applyTaskList() {
      execCmd('insertUnorderedList');
      const sel = window.getSelection();
      if (!sel || !sel.rangeCount) return;
      const li = _findParent(sel.getRangeAt(0).startContainer, 'li');
      if (li && !li.querySelector('input[type=checkbox]')) {
        const cb = document.createElement('input');
        cb.type = 'checkbox';
        li.insertBefore(cb, li.firstChild);
      }
      _reportChange();
    }

    /// Walks ancestors of the selection's start and end containers looking
    /// for an `<a>` element. Returns the link if either endpoint is inside
    /// (or is) one — used to highlight the toolbar Link button when the
    /// user's cursor or selection is on a link.
    function _selectionLink() {
      const sel = window.getSelection();
      if (!sel || !sel.rangeCount) return null;
      const range = sel.getRangeAt(0);
      const candidates = [range.startContainer, range.endContainer];
      for (const start of candidates) {
        let n = start;
        while (n && n !== editor) {
          if (n.nodeType === Node.ELEMENT_NODE && n.tagName.toLowerCase() === 'a') return n;
          n = n.parentNode;
        }
      }
      return null;
    }

    /// Returns the currently selected text. Pure helper, no side effects.
    function getSelectionText() {
      const sel = window.getSelection();
      if (!sel) return '';
      return sel.toString().replace(/​/g, '');
    }

    /// Snapshot of the current selection state for the host to drive the
    /// link sheet. Saves the live range to `_savedLinkRange` so a subsequent
    /// applyLink/removeLink call can restore it after the sheet dismissed.
    ///
    /// Returns:
    ///   { text: <string>, url: <string> }
    /// If the cursor or selection is inside an existing `<a>`, the saved
    /// range is expanded to cover the whole link and the returned `url`
    /// holds the link's href — so the sheet opens in edit mode.
    function prepareLinkSheet() {
      const sel = window.getSelection();
      if (!sel || !sel.rangeCount) {
        _savedLinkRange = null;
        return { text: '', url: '' };
      }
      const link = _selectionLink();
      if (link) {
        const r = document.createRange();
        r.selectNode(link);
        _savedLinkRange = r;
        return {
          text: (link.textContent || '').replace(/​/g, ''),
          url:  link.getAttribute('href') || ''
        };
      }
      _savedLinkRange = sel.getRangeAt(0).cloneRange();
      return {
        text: _savedLinkRange.toString().replace(/​/g, ''),
        url:  ''
      };
    }

    function _restoreSavedLinkRange() {
      if (!_savedLinkRange) return false;
      try {
        const sel = window.getSelection();
        sel.removeAllRanges();
        sel.addRange(_savedLinkRange);
      } catch (_) {}
      _savedLinkRange = null;
      return true;
    }

    /// Inserts (or replaces) `<a href="url">text</a>` at the selection
    /// captured by the most recent prepareLinkSheet call. If no range was
    /// saved (e.g. applyLink was called directly without going through the
    /// sheet flow), falls back to the live selection.
    function applyLink(url, text) {
      if (!url) return;
      editor.focus();
      _restoreSavedLinkRange();
      const sel = window.getSelection();
      const display = (text && text.length > 0) ? text : url;
      const a = document.createElement('a');
      a.href = url;
      a.textContent = display;
      if (sel && sel.rangeCount && !sel.isCollapsed) {
        const range = sel.getRangeAt(0);
        range.deleteContents();
        range.insertNode(a);
      } else if (sel && sel.rangeCount) {
        sel.getRangeAt(0).insertNode(a);
      } else {
        editor.appendChild(a);
      }
      const r = document.createRange();
      r.setStartAfter(a);
      r.collapse(true);
      const s = window.getSelection();
      s.removeAllRanges();
      s.addRange(r);
      _reportChange();
    }

    /// Unwraps the link saved by prepareLinkSheet, leaving its text behind.
    function removeLink() {
      editor.focus();
      if (!_restoreSavedLinkRange()) return;
      document.execCommand('unlink', false, null);
      _reportChange();
      _reportSelection();
    }

    // ── DOM → Markdown ───────────────────────────────────────────────────────

    function blockMD(root) {
      const parts = [];
      for (const child of root.childNodes) {
        const md = _nodeMD(child);
        if (md != null) parts.push(md);
      }
      // Single \n between top-level blocks so consecutive paragraphs don't
      // gain a phantom blank line in the source/preview after round-trip.
      // An intentional empty paragraph contributes its own '' part, which
      // becomes a blank line in the joined result.
      return parts.join('\n');
    }

    function _nodeMD(node) {
      if (node.nodeType === Node.TEXT_NODE) return node.textContent;
      if (node.nodeType !== Node.ELEMENT_NODE) return '';

      const tag = node.tagName.toLowerCase();
      const inner = () => Array.from(node.childNodes).map(_nodeMD).join('');

      switch (tag) {
        case 'br':   return '\n';
        case 'hr':   return '---';
        case 'b': case 'strong': {
          const c = inner().replace(/\u200B/g, '');
          return c === '' ? '' : '**' + c + '**';
        }
        case 'i': case 'em': {
          const c = inner().replace(/\u200B/g, '');
          return c === '' ? '' : '*' + c + '*';
        }
        case 'del': case 's': case 'strike': {
          const c = inner().replace(/\u200B/g, '');
          return c === '' ? '' : '~~' + c + '~~';
        }
        case 'code': {
          const inPre = node.parentElement && node.parentElement.tagName.toLowerCase() === 'pre';
          return inPre ? inner() : '`' + inner() + '`';
        }
        case 'pre':  return '```\n' + inner().trim() + '\n```';
        case 'a': {
          const href = node.getAttribute('href') || '';
          return '[' + inner() + '](' + href + ')';
        }
        case 'h1': return '# '  + inner().trim();
        case 'h2': return '## ' + inner().trim();
        case 'h3': return '### '+ inner().trim();
        case 'h4': return '#### '  + inner().trim();
        case 'h5': return '##### ' + inner().trim();
        case 'h6': return '###### '+ inner().trim();
        case 'blockquote': {
          const text = inner().trim();
          return text.split('\n').map(l => '> ' + l).join('\n');
        }
        case 'ul': {
          const items = Array.from(node.children).map(li => {
            const cb = li.querySelector('input[type=checkbox]');
            if (cb) {
              const text = _liText(li).trim();
              return (cb.checked ? '- [x] ' : '- [ ] ') + text;
            }
            return '- ' + _liText(li).trim();
          });
          return items.join('\n');
        }
        case 'ol': {
          const items = Array.from(node.children).map((li, i) =>
            (i + 1) + '. ' + _liText(li).trim()
          );
          return items.join('\n');
        }
        case 'li':   return inner();
        case 'input': return '';  // skip checkbox inputs
        case 'p': {
          const c = inner();
          if (c === '' || node.innerHTML === '<br>') return '';
          return c.trim();
        }
        case 'div': {
          const c = inner();
          if (c === '' || node.innerHTML === '<br>') return '';
          return c.trim();
        }
        default: return inner();
      }
    }

    function _liText(li) {
      return Array.from(li.childNodes)
        .filter(n => !(n.nodeType === Node.ELEMENT_NODE && n.tagName.toLowerCase() === 'input'))
        .map(_nodeMD).join('');
    }

    function _findParent(node, tagName) {
      while (node && node !== editor) {
        if (node.nodeType === Node.ELEMENT_NODE && node.tagName.toLowerCase() === tagName) return node;
        node = node.parentNode;
      }
      return null;
    }

    // ── Selection state ──────────────────────────────────────────────────────

    function _reportSelection() {
      const block = document.queryCommandValue('formatBlock').toLowerCase();
      post('selectionChanged', {
        bold:          document.queryCommandState('bold'),
        italic:        document.queryCommandState('italic'),
        strikethrough: document.queryCommandState('strikeThrough'),
        quote:  block === 'blockquote',
        h1:     block === 'h1',
        h2:     block === 'h2',
        h3:     block === 'h3',
        link:   _selectionLink() !== null,
      });
    }

    // ── Content change ───────────────────────────────────────────────────────

    function _reportChange() {
      if (_suppressing) return;
      const md = getMarkdown();
      if (md !== _lastMD) { _lastMD = md; post('contentChanged', md); }
    }

    // ── Keyboard handling ─────────────────────────────────────────────────────

    function _exitList(li, sel) {
      const list = li.parentNode;
      const listParent = list.parentNode;
      const listNextSibling = list.nextSibling;
      list.removeChild(li);
      const p = document.createElement('p');
      p.innerHTML = '<br>';
      listParent.insertBefore(p, listNextSibling);
      if (list.children.length === 0) listParent.removeChild(list);
      const r = document.createRange();
      r.setStart(p, 0); r.collapse(true);
      sel.removeAllRanges(); sel.addRange(r);
    }

    editor.addEventListener('keydown', function(e) {
      if (e.key !== 'Enter' && e.key !== 'Backspace') return;
      const sel = window.getSelection();
      if (!sel || !sel.rangeCount || !sel.isCollapsed) return;
      const range = sel.getRangeAt(0);

      // ── All list items (bullet, numbered, task) ─────────────────────────────
      const li = _findParent(range.startContainer, 'li');
      if (li) {
        const hasCheckbox = !!li.querySelector('input[type=checkbox]');
        const text = _liText(li).trim();

        if (e.key === 'Enter') {
          e.preventDefault();
          if (text === '') {
            // Empty item → exit the list entirely
            _exitList(li, sel);
            _reportChange();
            return;
          }
          // Manually append a new sibling <li> of the same kind. iOS WebKit's
          // native Enter handling here is unreliable (drops the checkbox on
          // task lists), so we always do it ourselves.
          const newLi = document.createElement('li');
          if (hasCheckbox) {
            const cb = document.createElement('input');
            cb.type = 'checkbox';
            newLi.appendChild(cb);
          } else {
            newLi.appendChild(document.createElement('br'));
          }
          li.parentNode.insertBefore(newLi, li.nextSibling);
          const nr = document.createRange();
          if (hasCheckbox) {
            nr.setStartAfter(newLi.firstChild);
          } else {
            nr.setStart(newLi, 0);
          }
          nr.collapse(true);
          sel.removeAllRanges();
          sel.addRange(nr);
          _reportChange();
          return;
        }

        if (e.key === 'Backspace' && text === '') {
          // Empty item → remove it and exit to a plain paragraph
          e.preventDefault();
          _exitList(li, sel);
          _reportChange();
          return;
        }
      }

      // ── End-of-line Enter in <p>/<h*>: always start a plain paragraph ──────
      // WebKit's default Enter inherits inline formatting (bold/italic/strike)
      // into the new line. We override this for end-of-block Enter so the next
      // line resets to plain text. Mid-line Enter still falls through to the
      // browser so the line splits naturally.
      if (e.key === 'Enter') {
        let block = range.startContainer;
        while (block && block.parentNode && block.parentNode !== editor) block = block.parentNode;
        if (block && block.nodeType === Node.ELEMENT_NODE) {
          const tag = block.tagName.toLowerCase();
          if (tag === 'p' || /^h[1-6]$/.test(tag)) {
            const tail = document.createRange();
            tail.selectNodeContents(block);
            tail.setStart(range.endContainer, range.endOffset);
            const trailing = tail.toString().replace(/\u200B/g, '').trim();
            if (trailing === '') {
              e.preventDefault();
              const newP = document.createElement('p');
              newP.innerHTML = '<br>';
              block.parentNode.insertBefore(newP, block.nextSibling);
              const nr = document.createRange();
              nr.setStart(newP, 0); nr.collapse(true);
              sel.removeAllRanges(); sel.addRange(nr);
              _reportChange();
              _reportSelection();
              return;
            }
          }
        }
      }

      // ── Blockquote ──────────────────────────────────────────────────────────
      const bq = _findParent(range.startContainer, 'blockquote');
      if (!bq) return;
      let line = _findParent(range.startContainer, 'p');
      if (!line) {
        const n = range.startContainer;
        line = n.nodeType === Node.ELEMENT_NODE ? n : n.parentElement;
      }
      const empty = !line || line.textContent.trim() === '' || line.innerHTML === '<br>';
      if (!empty) return;
      e.preventDefault();
      if (line && line.parentNode === bq) bq.removeChild(line);
      const newP = document.createElement('p');
      newP.innerHTML = '<br>';
      bq.parentNode.insertBefore(newP, bq.nextSibling);
      const r = document.createRange();
      r.setStart(newP, 0); r.collapse(true);
      sel.removeAllRanges(); sel.addRange(r);
      _reportChange();
    });

    // ── Event wiring ─────────────────────────────────────────────────────────

    // Click handling:
    //   • Checkbox taps don't fire 'input' on the contentEditable div, so we
    //     report the change explicitly when a task-list checkbox is toggled.
    //   • Anchor taps post a `linkTapped` message to Swift so the host can
    //     open the URL externally — the editor itself stays in editing mode.
    function _findAnchor(node) {
      while (node && node !== editor) {
        if (node.nodeType === Node.ELEMENT_NODE && node.tagName.toLowerCase() === 'a') return node;
        node = node.parentNode;
      }
      return null;
    }

    function _openAnchor(a, e) {
      const href = a && a.getAttribute('href');
      if (!href) return;
      if (e) { e.preventDefault(); e.stopPropagation(); }
      post('linkTapped', href);
    }

    editor.addEventListener('click', function(e) {
      if (e.target.type === 'checkbox') { _reportChange(); return; }
      const a = _findAnchor(e.target);
      if (a) _openAnchor(a, e);
    });

    // iOS WKWebView contentEditable can swallow the synthetic click on
    // links — touchend fires reliably, so use it as a fallback. We track a
    // small movement threshold so drag gestures (e.g. text selection
    // starting on a link) still work normally.
    let _linkTouch = null;
    editor.addEventListener('touchstart', function(e) {
      const a = _findAnchor(e.target);
      if (!a) { _linkTouch = null; return; }
      const t = e.touches[0];
      _linkTouch = { a: a, x: t.clientX, y: t.clientY, t: Date.now() };
    }, { passive: true });
    editor.addEventListener('touchmove', function(e) {
      if (!_linkTouch) return;
      const t = e.touches[0];
      if (Math.abs(t.clientX - _linkTouch.x) > 6 || Math.abs(t.clientY - _linkTouch.y) > 6) {
        _linkTouch = null;
      }
    }, { passive: true });
    editor.addEventListener('touchend', function(e) {
      if (!_linkTouch) return;
      const elapsed = Date.now() - _linkTouch.t;
      const a = _linkTouch.a;
      _linkTouch = null;
      if (elapsed < 500) _openAnchor(a, e);
    });

    editor.addEventListener('input', _reportChange);
    document.addEventListener('selectionchange', _reportSelection);
    editor.addEventListener('focus', () => post('focusChanged', true));
    editor.addEventListener('blur',  () => post('focusChanged', false));
    </script>
    </body>
    </html>
    """#
}
