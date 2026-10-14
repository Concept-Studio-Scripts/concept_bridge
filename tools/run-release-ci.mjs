import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'

const repository = process.env.GITHUB_REPOSITORY
assert(repository?.match(/^[\w.-]+\/[\w.-]+$/), 'Invalid repository.')
const requests = JSON.parse(process.env.RELEASE_PRS || '[]')
for (const request of requests) {
  assert(Number.isSafeInteger(request.number) && request.number > 0, 'Invalid release PR number.')
  const pr = JSON.parse(execFileSync('gh', ['api', `repos/${repository}/pulls/${request.number}`], { encoding: 'utf8' }))
  assert(pr.state === 'open' && pr.base.ref === 'main', 'Unexpected release PR target.')
  assert(pr.head.repo.full_name === repository && pr.head.ref.startsWith('release-please--'), 'Unexpected release PR source.')
  execFileSync('gh', ['workflow', 'run', process.env.CI_WORKFLOW, '--repo', repository, '--ref', pr.head.ref], { stdio: 'inherit' })
}
