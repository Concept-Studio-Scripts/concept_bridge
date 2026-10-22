import assert from 'node:assert/strict'

function commentFilter() {
  let open = false
  const filter = text => {
    let visible = ''
    while (text) {
      const token = open ? null : text.match(/<!--|`+/)
      const index = open ? text.indexOf('-->') : (token?.index ?? -1)
      if (index < 0) return visible + (open ? '' : text)
      if (!open) visible += text.slice(0, index)
      if (token?.[0].startsWith('`')) {
        const ticks = token[0]
        const rest = text.slice(index + ticks.length)
        const close = new RegExp('(?<!`)' + ticks + '(?!`)').exec(rest)
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
  return filter
}

// Keep offsets into the original text so notes, indentation and line endings
// are copied verbatim. Markdown headings inside fenced examples are not sections.
function sections(markdown) {
  const result = []
  const visible = commentFilter()
  let offset = 0
  let fence
  for (const line of markdown.split(/(?<=\n)/)) {
    const raw = line.replace(/\r?\n$/, '')
    const text = fence || (!visible.isOpen() && /^ {0,3}(?:`{3,}|~{3,})/.test(raw)) ? raw : visible(raw)
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

function hasNotes(body) {
  const visible = commentFilter()
  let fence
  for (const raw of body.split(/\r?\n/)) {
    const text = fence || (!visible.isOpen() && /^ {0,3}(?:`{3,}|~{3,})/.test(raw)) ? raw : visible(raw)
    const marker = text.match(/^ {0,3}(`{3,}|~{3,})(.*)$/)
    if (fence) {
      if (marker && marker[1][0] === fence[0] && marker[1].length >= fence.length && !marker[2].trim()) fence = undefined
      else if (text.trim()) return true
    } else if (marker) {
      fence = marker[1]
    } else if (text.trim() && !/^ {0,3}#{1,6}(?:[\t ]|$)/.test(text) && !/^ {0,3}\[[^\]]+\]:[\t ]*\S/.test(text)) return true
  }
  return false
}

export function releaseNotes(markdown, version) {
  const headings = sections(markdown)
  const index = headings.findIndex(heading => versionOf(heading.title) === version)
  assert(index >= 0, `Write a CHANGELOG.md section for ${version}, or add notes under Unreleased for automatic preparation, before merging the release PR.`)
  const body = markdown.slice(headings[index].start, headings[index + 1]?.index ?? markdown.length).trim()
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
