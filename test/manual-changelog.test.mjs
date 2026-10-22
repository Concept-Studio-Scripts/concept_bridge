import assert from 'node:assert/strict'
import { test } from 'node:test'
import { promoteUnreleased, releaseNotes } from '../tools/changelog.mjs'
import { prepareReleasePr } from '../tools/run-release-ci.mjs'

for (const newline of ['\n', '\r\n']) {
  test(`manual promotion preserves formatting and history (${JSON.stringify(newline)})`, () => {
    const body = ['', '### Fixed', '', '- First line.', '  Wrapped **text** and [link](https://example.test).', '  - Nested item.', '', '```md', '## [9.9.9]', '- This is an example, not a release.', '```', '', '| Item | Value |', '| --- | --- |', '| A | B |', '', ''].join(newline)
    const history = ['## [1.0.3] - 2026-10-20', '', '- Previous release.', '', '[1.0.3]: https://example.test/v1.0.3', ''].join(newline)
    const prefix = '# Changelog' + newline + newline + '## [Unreleased]' + newline
    const actual = promoteUnreleased(prefix + body + history, '1.0.4', '2026-10-22')
    assert.equal(actual, prefix + newline + '## [1.0.4] - 2026-10-22' + newline + body + history)
    assert.equal(promoteUnreleased(actual, '1.0.4', '2026-10-23'), actual, 'repeat runs do not change the date or duplicate notes')
    assert.equal(releaseNotes(actual, '1.0.4'), body.trim() + '\n')
  })
}

test('existing dated sections stay authoritative and empty Unreleased cannot create a release', () => {
  const manual = '## Unreleased\n- Future change.\n\n## [1.0.4] - 2026-10-21\n- Already prepared.\n'
  assert.equal(promoteUnreleased(manual, '1.0.4', '2026-10-22'), manual)
  for (const source of ['## Unreleased\n\n', '## [Unreleased]\n\n### Fixed\n\n', '# No pending notes\n']) {
    assert.equal(promoteUnreleased(source, '1.0.4', '2026-10-22'), source)
    assert.throws(() => releaseNotes(source, '1.0.4'), /CHANGELOG/)
  }
  assert.throws(() => promoteUnreleased('', '1.0.4', '2026-02-30'), /Invalid release date/)
})

function fixture({ base = '1.0.3', version = '1.0.4', source = '## Unreleased\n\n### Fixed\n- Manual note.\n', current = source, fork = false, branch = 'main', state = 'open' } = {}) {
  const repository = 'Concept-Studio-Scripts/example'
  const baseSha = 'a'.repeat(40)
  const headSha = 'b'.repeat(40)
  const writes = []
  const file = text => ({ type: 'file', encoding: 'base64', content: Buffer.from(text).toString('base64'), sha: 'c'.repeat(40) })
  const responses = {
    [`repos/${repository}/pulls/1`]: { state, base: { ref: branch, sha: baseSha, repo: { full_name: repository } }, head: { ref: 'release-please--branches--main--components--example', sha: headSha, repo: { full_name: fork ? 'someone/fork' : repository } } },
    [`repos/${repository}/contents/version.txt?ref=${headSha}`]: file(version + '\n'),
    [`repos/${repository}/contents/.release-please-manifest.json?ref=${baseSha}`]: file(JSON.stringify(base ? { '.': base } : {})),
    [`repos/${repository}/contents/release-please-config.json?ref=${baseSha}`]: file(JSON.stringify({ packages: { '.': { 'initial-version': '1.0.0' } } })),
    [`repos/${repository}/contents/CHANGELOG.md?ref=${baseSha}`]: file(source),
    [`repos/${repository}/contents/CHANGELOG.md?ref=${headSha}`]: file(current),
  }
  return { repository, writes, api(path, body) {
    if (body !== undefined) { writes.push({ path, body }); return {} }
    assert.ok(path in responses, `Unexpected API read ${path}`)
    return responses[path]
  } }
}

test('the release PR gets only the current base notes, without changing the base branch', () => {
  const prior = promoteUnreleased('## Unreleased\n- Older note.\n', '1.0.4', '2026-10-21')
  const f = fixture({ current: prior })
  const branch = prepareReleasePr(f.repository, 1, f.api, '2026-10-22')
  assert.equal(f.writes.length, 1)
  assert.equal(f.writes[0].path, `repos/${f.repository}/contents/CHANGELOG.md`)
  assert.equal(f.writes[0].body.branch, branch)
  const markdown = Buffer.from(f.writes[0].body.content, 'base64').toString('utf8')
  assert.equal(markdown, '## Unreleased\n\n## [1.0.4] - 2026-10-22\n\n### Fixed\n- Manual note.\n')
  const again = fixture({ current: markdown })
  prepareReleasePr(again.repository, 1, again.api, '2026-10-22')
  assert.equal(again.writes.length, 0, 'a prepared PR does not get another commit')
})

test('release preparation refuses duplicate versions and untrusted PR targets', () => {
  for (const options of [{ version: '1.0.3' }, { version: '1.0.2' }, { fork: true }, { branch: 'other' }, { state: 'closed' }]) {
    const f = fixture(options)
    assert.throws(() => prepareReleasePr(f.repository, 1, f.api, '2026-10-22'))
    assert.equal(f.writes.length, 0)
  }
  const initial = fixture({ base: null, version: '1.0.0' })
  prepareReleasePr(initial.repository, 1, initial.api, '2026-10-22')
  assert.equal(initial.writes.length, 1)
})
