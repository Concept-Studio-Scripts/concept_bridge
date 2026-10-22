import assert from 'node:assert/strict'

function commentFilter() {
  let open = false
  let codeTicks
  const filter = (text, following = '') => {
    let visible = ''
    while (text) {
      if (codeTicks) {
        const close = new RegExp('(?<!`)' + codeTicks + '(?!`)').exec(text)
        if (!close) return visible + text
        const end = close.index + codeTicks.length
        visible += text.slice(0, end)
        text = text.slice(end)
        codeTicks = undefined
        continue
      }
      const token = open ? null : text.match(/<!--|`+/)
      const index = open ? text.indexOf('-->') : (token?.index ?? -1)
      if (index < 0) return visible + (open ? '' : text)
      if (!open) visible += text.slice(0, index)
      if (token?.[0].startsWith('`')) {
        const ticks = token[0]
        const rest = text.slice(index + ticks.length)
        const close = new RegExp('(?<!`)' + ticks + '(?!`)').exec(rest)
        // Inline code can continue onto the next line, but cannot cross a
        // paragraph boundary or a new heading/list/fenced block.
        if (!close) {
          const paragraph = (rest + following).split(/\r?\n(?:[\t ]*\r?\n| {0,3}#{1,6}(?:[\t ]|$)| {0,3}(?:`{3,}|~{3,})| {0,3}(?:[-+*]|\d{1,9}[.)])[\t ])/)[0]
          if (new RegExp('(?<!`)' + ticks + '(?!`)').test(paragraph)) {
            codeTicks = ticks
            return visible + text.slice(index)
          }
        }
        const length = close ? ticks.length + close.index + ticks.length : ticks.length
        visible += text.slice(index, index + length)
        text = text.slice(index + length)
        continue
      }
      text = text.slice(index + (open ? 3 : 4))
      open = !open
    }
    return visible
  }
  filter.isOpen = () => open
  filter.isCode = () => Boolean(codeTicks)
  return filter
}

// Keep offsets into the original text so notes, indentation and line endings
// are copied verbatim. Markdown headings inside fenced examples are not sections.
function sections(markdown) {
  const result = []
  const visible = commentFilter()
  let offset = 0
  let fence
  let referenceRemaining = 0
  for (const line of markdown.split(/(?<=\n)/)) {
    const raw = line.replace(/\r?\n$/, '')
    if (!referenceRemaining && !fence && !visible.isOpen() && !visible.isCode()) {
      referenceRemaining = referenceLines(markdown.slice(offset).replace(/\r\n/g, '\n'))
    }
    if (referenceRemaining) {
      referenceRemaining--
      offset += line.length
      continue
    }
    const text = fence || (!visible.isOpen() && /^ {0,3}(?:`{3,}|~{3,})/.test(raw)) ? raw : visible(raw, markdown.slice(offset + raw.length))
    const marker = text.match(/^ {0,3}(`{3,}|~{3,})(.*)$/)
    if (fence) {
      if (marker && marker[1][0] === fence[0] && marker[1].length >= fence.length && !marker[2].trim()) fence = undefined
    } else if (marker) {
      fence = marker[1]
    } else {
      const heading = text.match(/^ {0,3}##[\t ]+(.+?)[\t ]*$/)
      if (heading) {
        let start = offset + line.length
        // A comment starting on the heading belongs to that heading. Keep it
        // intact before inserting a release heading or exporting visible notes.
        if (visible.isOpen()) {
          const end = markdown.indexOf('-->', start)
          start = end < 0 ? markdown.length : end + 3
          start += markdown.slice(start).match(/^[\t ]*\r?\n/)?.[0].length ?? 0
        }
        result.push({ title: heading[1].replace(/[\t ]+#+$/, '').replace(/\\([\[\]])/g, '$1'), index: offset, start })
      }
    }
    offset += line.length
  }
  return result
}

function versionOf(title) {
  return title.match(/^\[?(\d+\.\d+\.\d+)\]?(?:\s|$)/)?.[1]
}

// Only a complete definition is invisible. Text such as
// "[Windows]: Fixed the launcher" is an ordinary paragraph.
const REFERENCE = /^ {0,3}\[((?:\\.|[^\[\]\\\r]){1,999})\]:[\t ]*(?:\n[\t ]*)?(<(?:(?:\\.)|[^<>\\\r\n])*>|(?:\\.|[^\x00-\x20<>\\])+)(?:(?:[\t ]+(?:\n[\t ]*)?|\n[\t ]*)(?:"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|\((?:\\.|[^()\\])*\)))?[\t ]*(?:\n|$)/

function referenceLines(text) {
  const match = REFERENCE.exec(text)
  if (!match || !match[1].trim() || /\n[\t ]*\n/.test(match[0])) return 0
  if (!match[2].startsWith('<')) {
    let depth = 0
    for (let i = 0; i < match[2].length; i++) {
      const char = match[2][i]
      if (char === '\\' && /[()\\]/.test(match[2][i + 1] ?? '')) i++
      else if (char === '(') depth++
      else if (char === ')' && --depth < 0) return 0
    }
    if (depth !== 0) return 0
  }
  return match[0].split('\n').length - (match[0].endsWith('\n') ? 1 : 0)
}

function hasNotes(body) {
  const visible = commentFilter()
  const lines = body.split(/\r?\n/)
  let fence
  for (let i = 0; i < lines.length; i++) {
    const raw = lines[i]
    const following = '\n' + lines.slice(i + 1).join('\n')
    // Link labels, destinations and titles are metadata, not inline Markdown.
    // Consume them before they can change HTML-comment or code-span state.
    if (!fence && !visible.isOpen() && !visible.isCode()) {
      const count = referenceLines(raw + following)
      if (count) {
        i += count - 1
        continue
      }
    }
    const text = fence || (!visible.isOpen() && /^ {0,3}(?:`{3,}|~{3,})/.test(raw)) ? raw : visible(raw, following)
    const marker = text.match(/^ {0,3}(`{3,}|~{3,})(.*)$/)
    if (fence) {
      if (marker && marker[1][0] === fence[0] && marker[1].length >= fence.length && !marker[2].trim()) fence = undefined
      else if (text.trim()) return true
    } else if (marker) {
      fence = marker[1]
    } else {
      const heading = setextLines([text, ...lines.slice(i + 1)])
      if (heading) { i += heading - 1; continue }
      if (text.trim()
      && !/^ {0,3}#{1,6}(?:[\t ]|$)/.test(text)
      && !/^ {0,3}(?:(?:\*[\t ]*){3,}|(?:-[\t ]*){3,}|(?:_[\t ]*){3,})$/.test(text)
      && !/^[\t ]*(?:[-+*]|\d{1,9}[.)])(?:[\t ]+\[[ xX]\])?[\t ]*$/.test(text)) return true
    }
  }
  return false
}

function setextLines(lines) {
  const block = /^(?: {4}|\t)|^ {0,3}(?:#{1,6}(?:[\t ]|$)|>|[-+*](?:[\t ]|$)|\d{1,9}[.)][\t ]|`{3,}|~{3,}|<)/
  if (!lines[0]?.trim() || block.test(lines[0])) return 0
  for (let i = 1; i < lines.length; i++) {
    if (/^ {0,3}(?:=+|-+)[\t ]*$/.test(lines[i])) return i + 1
    if (!lines[i].trim() || block.test(lines[i])) return 0
  }
  return 0
}

export function releaseNotes(markdown, version) {
  const headings = sections(markdown)
  const index = headings.findIndex(heading => versionOf(heading.title) === version)
  assert(index >= 0, `Write a CHANGELOG.md section for ${version}, or add notes under Unreleased for automatic preparation, before merging the release PR.`)
  const body = markdown.slice(headings[index].start, headings[index + 1]?.index ?? markdown.length)
    .replace(/^(?:[\t ]*\r?\n)+/, '').replace(/(?:\r?\n[\t ]*)+$/, '')
  assert(hasNotes(body), `Release notes for ${version} are empty.`)
  return body + '\n'
}

export function promoteUnreleased(markdown, version, date) {
  assert(/^\d+\.\d+\.\d+$/.test(version), 'Invalid release version.')
  assert(/^\d{4}-\d{2}-\d{2}$/.test(date) && new Date(`${date}T00:00:00Z`).toISOString().slice(0, 10) === date, 'Invalid release date.')
  const headings = sections(markdown)
  // An explicitly written release section is authoritative; do not merge
  // future Unreleased notes into it or rewrite its date/formatting.
  if (headings.some(heading => versionOf(heading.title) === version)) return markdown
  const index = headings.findIndex(heading => /^\[?Unreleased\]?$/i.test(heading.title))
  if (index < 0) return markdown
  const start = headings[index].start
  const end = headings[index + 1]?.index ?? markdown.length
  const body = markdown.slice(start, end)
  if (!hasNotes(body)) return markdown // CI still blocks a release without notes.
  const newline = markdown.match(/\r?\n/)?.[0] ?? '\n'
  const prefix = markdown.slice(0, start)
  const separator = prefix.endsWith('\n') ? '' : newline
  return prefix + separator + newline + `## [${version}] - ${date}` + newline + body + markdown.slice(end)
}

export function compareVersions(left, right) {
  assert(/^\d+\.\d+\.\d+$/.test(left) && /^\d+\.\d+\.\d+$/.test(right), 'Invalid release version.')
  const a = left.split('.').map(BigInt)
  const b = right.split('.').map(BigInt)
  for (let i = 0; i < 3; i++) if (a[i] !== b[i]) return a[i] > b[i] ? 1 : -1
  return 0
}
