import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import { resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { compareVersions, promoteUnreleased } from './changelog.mjs'

export function githubApi(path, body) {
  const args = ['api', path]
  if (body !== undefined) args.push('--method', 'PUT', '--input', '-')
  return JSON.parse(execFileSync('gh', args, {
    encoding: 'utf8',
    ...(body !== undefined ? { input: JSON.stringify(body) } : {}),
  }))
}

function decode(file) {
  assert(file.type === 'file' && file.encoding === 'base64', 'Expected a repository text file.')
  return Buffer.from(file.content, 'base64').toString('utf8')
}

export function prepareReleasePr(repository, number, api = githubApi, date = new Date().toISOString().slice(0, 10)) {
  assert(/^[\w.-]+\/[\w.-]+$/.test(repository ?? ''), 'Invalid repository.')
  assert(Number.isSafeInteger(number) && number > 0, 'Invalid release PR number.')
  const pr = api(`repos/${repository}/pulls/${number}`)
  assert(pr.state === 'open' && pr.base.ref === 'main' && pr.base.repo.full_name === repository, 'Unexpected release PR target.')
  assert(pr.head.repo?.full_name === repository && pr.head.ref.startsWith('release-please--'), 'Unexpected release PR source.')
  assert(/^[a-f0-9]{40}$/.test(pr.base.sha) && /^[a-f0-9]{40}$/.test(pr.head.sha), 'Invalid release PR revisions.')
  const contents = (path, sha) => api(`repos/${repository}/contents/${path}?ref=${sha}`)
  const version = decode(contents('version.txt', pr.head.sha)).trim()
  const released = JSON.parse(decode(contents('.release-please-manifest.json', pr.base.sha)))['.']
  if (released !== undefined) {
    assert(compareVersions(version, released) > 0, `Release PR version ${version} must be newer than the recorded release ${released}. Repair the release baseline before merging.`)
  } else {
    const config = JSON.parse(decode(contents('release-please-config.json', pr.base.sha)))
    assert(version === config.packages['.']['initial-version'], 'Unexpected initial release version.')
  }
  // Always start from the base revision's manual notes. A bot refresh must
  // include newly added notes without duplicating an earlier promotion.
  const source = decode(contents('CHANGELOG.md', pr.base.sha))
  const current = contents('CHANGELOG.md', pr.head.sha)
  const promoted = promoteUnreleased(source, version, date)
  if (promoted !== decode(current)) {
    api(`repos/${repository}/contents/CHANGELOG.md`, {
      branch: pr.head.ref,
      sha: current.sha,
      message: `chore(release): prepare ${version} manual notes`,
      content: Buffer.from(promoted, 'utf8').toString('base64'),
    })
  }
  return pr.head.ref
}

export function runReleaseCi(env = process.env) {
  const requests = JSON.parse(env.RELEASE_PRS || '[]')
  assert(Array.isArray(requests), 'Invalid release PR list.')
  assert(/^[\w.-]+\.ya?ml$/.test(env.CI_WORKFLOW ?? ''), 'Invalid CI workflow.')
  for (const request of requests) {
    const branch = prepareReleasePr(env.GITHUB_REPOSITORY, request.number)
    execFileSync('gh', ['workflow', 'run', env.CI_WORKFLOW, '--repo', env.GITHUB_REPOSITORY, '--ref', branch], { stdio: 'inherit' })
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) runReleaseCi()
