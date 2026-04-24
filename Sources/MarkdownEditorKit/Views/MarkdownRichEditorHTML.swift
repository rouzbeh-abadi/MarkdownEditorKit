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
      let md = blockMD(editor).trim();
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

    function applyBold()          { execCmd('bold'); }
    function applyItalic()        { execCmd('italic'); }
    function applyStrikethrough() { execCmd('strikeThrough'); }
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

    function applyLink() {
      const sel = window.getSelection();
      const title = (sel && !sel.isCollapsed) ? sel.toString() : 'link';
      const url = 'https://example.com';
      execCmd('createLink', url);
      // Update link text if it was empty
      const anchor = document.querySelector('a[href="' + url + '"]');
      if (anchor && anchor.textContent === '') anchor.textContent = title;
    }

    // ── DOM → Markdown ───────────────────────────────────────────────────────

    function blockMD(root) {
      const parts = [];
      for (const child of root.childNodes) {
        const md = _nodeMD(child);
        if (md !== null) parts.push(md);
      }
      return parts.join('\n');
    }

    function _nodeMD(node) {
      if (node.nodeType === Node.TEXT_NODE) return node.textContent;
      if (node.nodeType !== Node.ELEMENT_NODE) return '';

      const tag = node.tagName.toLowerCase();
      const inner = () => Array.from(node.childNodes).map(_nodeMD).join('');

      switch (tag) {
        case 'br':
          return node.parentElement === editor ? '\n' : '';
        case 'hr':   return '\n---';
        case 'b': case 'strong': return '**' + inner() + '**';
        case 'i': case 'em':    return '*' + inner() + '*';
        case 'del': case 's': case 'strike': return '~~' + inner() + '~~';
        case 'code': {
          const inPre = node.parentElement && node.parentElement.tagName.toLowerCase() === 'pre';
          return inPre ? inner() : '`' + inner() + '`';
        }
        case 'pre':  return '\n```\n' + inner().trim() + '\n```';
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
          } else if (hasCheckbox) {
            // Task list → new unchecked item
            const newLi = document.createElement('li');
            const cb = document.createElement('input');
            cb.type = 'checkbox';
            newLi.appendChild(cb);
            li.parentNode.insertBefore(newLi, li.nextSibling);
            const r = document.createRange();
            r.setStartAfter(cb); r.collapse(true);
            sel.removeAllRanges(); sel.addRange(r);
          } else {
            // Bullet / numbered → new item of the same type
            const newLi = document.createElement('li');
            newLi.innerHTML = '<br>';
            li.parentNode.insertBefore(newLi, li.nextSibling);
            const r = document.createRange();
            r.setStart(newLi, 0); r.collapse(true);
            sel.removeAllRanges(); sel.addRange(r);
          }
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

    // Checkbox taps don't fire 'input' on the contentEditable div, so report
    // the change explicitly when a task-list checkbox is toggled.
    editor.addEventListener('click', function(e) {
      if (e.target.type === 'checkbox') _reportChange();
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
