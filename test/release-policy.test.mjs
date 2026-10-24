import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { test } from 'node:test'

test('automatic releases stay patch-only and publish manually written notes', () => {
  const config = JSON.parse(readFileSync(new URL('../release-please-config.json', import.meta.url), 'utf8')).packages['.']
  assert.equal(config.versioning, 'always-bump-patch', 'Features and breaking commits must not trigger a major/minor release.')
  assert.equal(config['skip-changelog'], true, 'Release notes must remain manually written.')
  assert.equal(config.draft, true, 'Publishing must wait for verification and packaging.')
  assert.equal(config['force-tag-creation'], true, 'The verified release must be tied to its source tag.')
})
