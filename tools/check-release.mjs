import assert from 'node:assert/strict'
import { readFileSync, writeFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

import { releaseNotes } from './changelog.mjs'
export { releaseNotes } from './changelog.mjs'

export function checkRelease(root, tag = '', requireNotes = false) {
  const text = path => readFileSync(resolve(root, path), 'utf8')
  const json = path => JSON.parse(text(path))
  const version = text('version.txt').trim()
  assert(/^\d+\.\d+\.\d+$/.test(version), 'version.txt must contain a stable semantic version.')
  const manifest = text('fxmanifest.lua').match(/^version '([^']+)'/m)?.[1]
  const config = json('release-please-config.json')
  const released = json('.release-please-manifest.json')
  assert.equal(manifest, version, 'manifest version differs from version.txt.')
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
