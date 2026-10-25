import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { test } from 'node:test'

test('automatic releases stay patch-only and publish manually written notes', () => {
  const packageConfig = JSON.parse(readFileSync(new URL('../release-please-config.json', import.meta.url), 'utf8')).packages['.']
  assert.equal(packageConfig.versioning, 'always-bump-patch', 'Features and breaking commits must not trigger a major/minor release.')
  assert.equal(packageConfig['skip-changelog'], true, 'Release notes must remain manually written.')
  assert.equal(packageConfig.draft, true, 'Publishing must wait for verification and packaging.')
  assert.equal(packageConfig['force-tag-creation'], true, 'The verified release must be tied to its source tag.')
})

test('tagged publication does not depend on Actions artifact storage', () => {
  const workflow = readFileSync(new URL('../.github/workflows/release.yml', import.meta.url), 'utf8')
  const lines = workflow.split(/\r?\n/)
  const step = name => {
    const start = lines.findIndex(line => line === `      - name: ${name}`)
    assert.notEqual(start, -1, `${name} step is missing`)
    let end = start + 1
    while (end < lines.length && !/^      - /.test(lines[end])) end++
    return lines.slice(start, end).join('\n')
  }
  const artifactStep = step('Save verified ZIP')
  const publishStep = step('Attach ZIP and publish manual release notes')
  assert.match(artifactStep, /^ {8}if: inputs\.tag == ''$/m)
  assert.match(artifactStep, /^ {10}retention-days: 1$/m)
  assert.match(artifactStep, /^ {10}compression-level: 0$/m)
  assert.match(publishStep, /^ {8}if: inputs\.tag != ''$/m)
  assert.match(publishStep, /gh release upload/)
})
