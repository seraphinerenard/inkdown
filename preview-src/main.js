// Preview renderer — bundled by esbuild into Sources/Resources/preview/app.js.
// markdown-it + plugins + highlight.js are bundled here; KaTeX and Mermaid are
// loaded separately as window globals (see index.html) to keep their fonts /
// lazy diagram loading intact.

import MarkdownIt from 'markdown-it'
import hljs from 'highlight.js/lib/common'
import texmath from 'markdown-it-texmath'
import footnote from 'markdown-it-footnote'
import taskLists from 'markdown-it-task-lists'
import deflist from 'markdown-it-deflist'
import sub from 'markdown-it-sub'
import sup from 'markdown-it-sup'
import mark from 'markdown-it-mark'
import abbr from 'markdown-it-abbr'
import attrs from 'markdown-it-attrs'
import anchor from 'markdown-it-anchor'
import container from 'markdown-it-container'
import frontMatter from 'markdown-it-front-matter'
import { full as emoji } from 'markdown-it-emoji'
import githubAlerts from 'markdown-it-github-alerts'

const katex = window.katex
const mermaid = window.mermaid

function escapeHtml(s) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
}

const md = MarkdownIt({
  html: true,
  linkify: true,
  breaks: false,
  typographer: false,
  highlight(str, lang) {
    if (lang && lang !== 'mermaid' && hljs.getLanguage(lang)) {
      try {
        return '<pre class="hljs"><code>' +
          hljs.highlight(str, { language: lang, ignoreIllegals: true }).value +
          '</code></pre>'
      } catch (_) { /* fall through */ }
    }
    return '<pre class="hljs"><code>' + escapeHtml(str) + '</code></pre>'
  },
})

// Front matter is stripped from the rendered body (shown by the editor, not preview).
md.use(frontMatter, () => {})
md.use(footnote)
md.use(taskLists, { enabled: true, label: true, labelAfter: true })
md.use(deflist)
md.use(sub)
md.use(sup)
md.use(mark)
md.use(abbr)
md.use(attrs)
md.use(anchor, { slugify: s => s.trim().toLowerCase().replace(/[^\w]+/g, '-') })
md.use(emoji)
md.use(githubAlerts)
if (katex) md.use(texmath, { engine: katex, delimiters: 'dollars', katexOptions: { throwOnError: false } })

// Generic ::: name ... ::: admonitions (in addition to GitHub > [!NOTE] alerts).
for (const name of ['note', 'tip', 'important', 'warning', 'caution', 'info', 'success', 'danger']) {
  md.use(container, name, {
    render(tokens, idx) {
      if (tokens[idx].nesting === 1) {
        return `<div class="admonition admonition-${name}"><p class="admonition-title">${name}</p>\n`
      }
      return '</div>\n'
    },
  })
}

// Mermaid fences → <div class="mermaid"> so mermaid.run() can typeset them.
const defaultFence = md.renderer.rules.fence.bind(md.renderer.rules)
md.renderer.rules.fence = (tokens, idx, options, env, self) => {
  const token = tokens[idx]
  if (token.info.trim() === 'mermaid') {
    const line = token.map ? ` data-line="${token.map[0]}"` : ''
    return `<div class="mermaid source-line"${line}>${escapeHtml(token.content)}</div>`
  }
  return defaultFence(tokens, idx, options, env, self)
}

// VSCode-style source mapping: tag every top-level block with its source line.
md.core.ruler.push('source_line', state => {
  for (const token of state.tokens) {
    if (token.map && token.level === 0 && token.type.endsWith('_open')) {
      token.attrSet('data-line', String(token.map[0]))
      token.attrJoin('class', 'source-line')
    }
  }
})

// ---------------------------------------------------------------------------
// Scroll-sync line map
// ---------------------------------------------------------------------------
let lineMap = []          // sorted [{ line, top }]
let suppressUntil = 0     // ignore our own programmatic scrolls

function rebuildLineMap() {
  lineMap = []
  for (const el of document.querySelectorAll('[data-line]')) {
    lineMap.push({ line: parseInt(el.getAttribute('data-line'), 10), top: el.offsetTop })
  }
  lineMap.sort((a, b) => a.line - b.line)
}

function offsetForLine(line) {
  if (!lineMap.length) return 0
  if (line <= lineMap[0].line) return lineMap[0].top
  const last = lineMap[lineMap.length - 1]
  if (line >= last.line) return last.top
  for (let i = 0; i < lineMap.length - 1; i++) {
    const a = lineMap[i], b = lineMap[i + 1]
    if (line >= a.line && line <= b.line) {
      const f = (line - a.line) / Math.max(1, b.line - a.line)
      return a.top + f * (b.top - a.top)
    }
  }
  return 0
}

function lineForOffset(y) {
  if (!lineMap.length) return 0
  if (y <= lineMap[0].top) return lineMap[0].line
  const last = lineMap[lineMap.length - 1]
  if (y >= last.top) return last.line
  for (let i = 0; i < lineMap.length - 1; i++) {
    const a = lineMap[i], b = lineMap[i + 1]
    if (y >= a.top && y <= b.top) {
      const f = (y - a.top) / Math.max(1, b.top - a.top)
      return Math.round(a.line + f * (b.line - a.line))
    }
  }
  return last.line
}

function post(name, body) {
  try { window.webkit.messageHandlers[name].postMessage(body || {}) } catch (_) {}
}

window.addEventListener('scroll', () => {
  if (performance.now() < suppressUntil) return
  post('scrollSync', { line: lineForOffset(window.scrollY) })
}, { passive: true })

document.addEventListener('dblclick', e => {
  const el = e.target.closest('[data-line]')
  if (el) post('revealEditor', { line: parseInt(el.getAttribute('data-line'), 10) })
})

document.addEventListener('click', e => {
  const a = e.target.closest('a')
  if (a && a.getAttribute('href')) {
    const href = a.getAttribute('href')
    if (/^[a-z]+:\/\//i.test(href) || href.startsWith('mailto:')) {
      e.preventDefault()
      post('linkClicked', { href })
    }
  }
})

// ---------------------------------------------------------------------------
// Public API used by Swift over the bridge
// ---------------------------------------------------------------------------
if (mermaid) {
  try { mermaid.initialize({ startOnLoad: false, securityLevel: 'strict', theme: 'default' }) } catch (_) {}
}

window.MDPreview = {
  render(src) {
    const content = document.getElementById('content')
    content.innerHTML = md.render(src || '')
    if (mermaid) {
      const nodes = content.querySelectorAll('.mermaid')
      if (nodes.length) { try { mermaid.run({ nodes }) } catch (_) {} }
    }
    rebuildLineMap()
  },
  scrollToLine(line) {
    suppressUntil = performance.now() + 150
    window.scrollTo({ top: Math.max(0, offsetForLine(line)), behavior: 'auto' })
  },
  revealLine(line) {
    const target = offsetForLine(line)
    const top = window.scrollY, bottom = top + window.innerHeight
    if (target < top + 40 || target > bottom - 120) {
      suppressUntil = performance.now() + 150
      window.scrollTo({ top: Math.max(0, target - window.innerHeight / 3), behavior: 'auto' })
    }
  },
  setTheme(dark) {
    document.documentElement.classList.toggle('dark', !!dark)
    if (mermaid) {
      try { mermaid.initialize({ startOnLoad: false, securityLevel: 'strict', theme: dark ? 'dark' : 'default' }) } catch (_) {}
    }
  },
}

post('ready')
