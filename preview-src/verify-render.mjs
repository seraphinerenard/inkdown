// Verifies the markdown-it rendering pipeline (the core of the preview) in Node,
// so config/plugin bugs surface without a browser. Mermaid/KaTeX layout happen
// client-side, but KaTeX markup + all markdown-it plugins are checked here.
import MarkdownIt from 'markdown-it'
import footnote from 'markdown-it-footnote'
import taskLists from 'markdown-it-task-lists'
import githubAlerts from 'markdown-it-github-alerts'
import texmath from 'markdown-it-texmath'
import katex from 'katex'
import mark from 'markdown-it-mark'
import sub from 'markdown-it-sub'
import sup from 'markdown-it-sup'
import deflist from 'markdown-it-deflist'
import { full as emoji } from 'markdown-it-emoji'
import anchor from 'markdown-it-anchor'

const md = MarkdownIt({ html: true, linkify: true })
  .use(footnote).use(taskLists, { enabled: true }).use(mark).use(sub).use(sup)
  .use(deflist).use(emoji).use(anchor).use(githubAlerts)
  .use(texmath, { engine: katex, delimiters: 'dollars', katexOptions: { throwOnError: false } })

// data-line rule (mirror of main.js)
md.core.ruler.push('source_line', state => {
  for (const t of state.tokens) {
    if (t.map && t.level === 0 && t.type.endsWith('_open')) t.attrSet('data-line', String(t.map[0]))
  }
})

const src = `# Heading One

Some **bold**, *italic*, ==highlight==, H~2~O, x^2^ and :tada:.

- [x] done
- [ ] todo

| A | B |
|---|---|
| 1 | 2 |

> [!NOTE]
> An alert.

Inline math $E = mc^2$ and display:

$$\\int_0^1 x^2\\,dx$$

A footnote.[^1]

[^1]: the note.

\`\`\`js
const x = 1
\`\`\`
`

const html = md.render(src)
const checks = {
  'heading with data-line': /<h1[^>]*data-line="0"/,
  'bold': /<strong>bold<\/strong>/,
  'highlight mark': /<mark>highlight<\/mark>/,
  'subscript': /H<sub>2<\/sub>O/,
  'superscript': /x<sup>2<\/sup>/,
  'emoji': /🎉/,
  'task checkbox': /<input[^>]*type="checkbox"/,
  'table': /<table>[\s\S]*<td>1<\/td>/,
  'github alert': /markdown-alert/,
  'katex inline': /class="katex"/,
  'footnote': /class="footnote/,
}
let fail = 0
for (const [label, re] of Object.entries(checks)) {
  const ok = re.test(html)
  console.log(`${ok ? '  ok ' : 'FAIL'}  ${label}`)
  if (!ok) fail++
}
console.log(fail === 0 ? '\nALL RENDER CHECKS PASSED' : `\n${fail} RENDER CHECK(S) FAILED`)
process.exit(fail === 0 ? 0 : 1)
