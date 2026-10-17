import assert from 'node:assert/strict'
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { test } from 'node:test'
import { checkRelease, releaseNotes } from '../tools/check-release.mjs'

test('manual notes select one version and preserve their wording', () => {
  assert.equal(releaseNotes('# Changelog\n\n## Unreleased\n- Pending.\n\n## [2.0.0] - 2026-10-14\n\n### Changed\n- Use ox_lib directly.\n\n## 1.0.0 - 2026-10-10\n- First release.\n', '2.0.0'), '### Changed\n- Use ox_lib directly.\n')
})

test('missing and empty manual notes cannot publish a release', () => {
  assert.throws(() => releaseNotes('## Unreleased\n- Pending.\n', '2.0.0'), /Write a CHANGELOG/)
  assert.throws(() => releaseNotes('## [2.0.0]\n\n### Fixed\n\n## [1.0.0]\n- Old.\n', '2.0.0'), /empty/)
})

test('release gates reject mismatched versions, tags and automatic changelogs', () => {
  const root = mkdtempSync(join(tmpdir(), 'concept-release-test-'))
  const json = (path, data) => writeFileSync(join(root, path), JSON.stringify(data))
  try {
    writeFileSync(join(root, 'version.txt'), '1.0.0\n')
    writeFileSync(join(root, 'fxmanifest.lua'), "version '1.0.0' -- x-release-please-version\n")
    writeFileSync(join(root, 'CHANGELOG.md'), '## [1.0.0]\n- Manual notes.\n')
    json('.release-please-manifest.json', { '.': '1.0.0' })
    json('release-please-config.json', { packages: { '.': { 'skip-changelog': true } } })
    assert.equal(checkRelease(root, 'v1.0.0').notes, '- Manual notes.\n')
    assert.throws(() => checkRelease(root, 'v2.0.0'), /tag differs/)
    json('.release-please-manifest.json', {})
    assert.throws(() => checkRelease(root), /empty release manifest requires/)
    json('release-please-config.json', { packages: { '.': { 'skip-changelog': true, 'initial-version': '1.0.0' } } })
    assert.equal(checkRelease(root, 'v1.0.0').version, '1.0.0')
    json('.release-please-manifest.json', { '.': '9.0.0' })
    assert.throws(() => checkRelease(root), /releaseManifest version differs/)
    json('.release-please-manifest.json', { '.': '1.0.0' })

    writeFileSync(join(root, 'fxmanifest.lua'), "version '9.0.0' -- x-release-please-version\n")
    assert.throws(() => checkRelease(root), /manifest version differs/)
    writeFileSync(join(root, 'fxmanifest.lua'), "version '1.0.0' -- x-release-please-version\n")
    json('release-please-config.json', { packages: { '.': { 'skip-changelog': false } } })
    assert.throws(() => checkRelease(root), /manually maintained/)
  } finally {
    rmSync(root, { recursive: true, force: true })
  }
})
