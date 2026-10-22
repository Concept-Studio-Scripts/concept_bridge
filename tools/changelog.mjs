import assert from 'node:assert/strict'

// Keep offsets into the original text so notes, indentation and line endings
// are copied verbatim. Markdown headings inside fenced examples are not sections.
function sections(markdown) {
  const result = []
  let offset = 0
  let fence
  for (const line of markdown.split(/(?<=\n)/)) {
    const text = line.replace(/\r?\n$/, '')
    const marker = text.match(/^ {0,3}(`{3,}|~{3,})(.*)$/)
    if (fence) {
      if (marker && marker[1][0] === fence[0] && marker[1].length >= fence.length && !marker[2].trim()) fence = undefined
    } else if (marker) {
      fence = marker[1]
    } else {
      const heading = text.match(/^##[\t ]+(.+?)[\t ]*$/)
      if (heading) result.push({ title: heading[1], index: offset, start: offset + line.length })
    }
    offset += line.length
  }
  return result
}

function versionOf(title) {
  return title.match(/^\[?(\d+\.\d+\.\d+)\]?(?:\s|$)/)?.[1]
}

function hasNotes(body) {
  return body.trim().split(/\r?\n/).some(line => line.trim() && !line.startsWith('#'))
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
