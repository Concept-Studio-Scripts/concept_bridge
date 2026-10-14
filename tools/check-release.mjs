import assert from 'node:assert/strict'
import { readFileSync, writeFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

export function releaseNotes(changelog, version) {
  const headings = [...changelog.matchAll(/^## (.+)$/gm)]
  const index = headings.findIndex(match => match[1].match(/^\[?(\d+\.\d+\.\d+)\]?(?:\s|$)/)?.[1] === version)
  assert(index >= 0, `Write a CHANGELOG.md section for ${version} before merging the release PR.`)
  const start = headings[index].index + headings[index][0].length
  const end = headings[index + 1]?.index ?? changelog.length
  const notes = changelog.slice(start, end).trim()
  assert(notes && notes.split('\n').some(line => line.trim() && !line.startsWith('#')), `Release notes for ${version} are empty.`)
  return notes + '\n'
}

export function checkRelease(root, tag = '', requireNotes = false) {
  const text = path => readFileSync(resolve(root, path), 'utf8')
  const json = path => JSON.parse(text(path))
  const version = text('version.txt').trim()
  assert(/^\d+\.\d+\.\d+$/.test(version), 'version.txt must contain a stable semantic version.')
  const manifest = text('fxmanifest.lua').match(/^version '([^']+)'/m)?.[1]
  const lock = json('web/package-lock.json')
  const config = json('release-please-config.json')
  const released = json('.release-please-manifest.json')
  for (const [name, value] of Object.entries({ manifest, package: json('web/package.json').version, lock: lock.version, lockRoot: lock.packages[''].version })) {
    assert.equal(value, version, `${name} version differs from version.txt.`)
  }
  if (tag) assert.equal(tag, `v${version}`, 'Release tag differs from the checked-out version.')
  if (Object.keys(released).length === 0) {
    assert.equal(config.packages['.']['initial-version'], version, 'An empty release manifest requires the configured initial version.')
  } else {
    assert.equal(released['.'], version, 'releaseManifest version differs from version.txt.')
  }
  assert.equal(config.packages['.']['skip-changelog'], true, 'The changelog must remain manually maintained.')
  if (requireNotes || tag) return { version, notes: releaseNotes(text('CHANGELOG.md'), version) }
  return { version }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const tag = process.argv[2] ?? ''
  const requireNotes = process.env.GITHUB_HEAD_REF?.startsWith('release-please--') || process.env.GITHUB_REF_NAME?.startsWith('release-please--')
  const result = checkRelease(process.cwd(), tag, requireNotes)
  if (tag) writeFileSync('release-notes.md', result.notes)
  console.log(`Release versions verified: ${result.version}${tag ? ` (${tag}); manual release notes ready` : ''}`)
}
