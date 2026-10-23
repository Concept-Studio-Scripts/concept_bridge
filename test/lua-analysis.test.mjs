import assert from 'node:assert/strict'
import { test } from 'node:test'
import { compareBaseline, forSide, normalize } from '../tools/check-lua.mjs'

const finding = {side: 'client', file: 'modules/example/client.lua', code: 'return-type-mismatch',
  source: 'return nil', message: 'Optional result is documented as required.', severity: 2}
const baseline = {version: 1, reasons: {annotation: 'Legacy return annotation; nil is intentional.'},
  entries: [{...finding, count: 1, reason: 'annotation'}]}

test('an empty LuaLS report is accepted while malformed reports fail', () => {
  assert.deepEqual(normalize([], 'client', '.'), [])
  assert.deepEqual(normalize({}, 'client', '.'), [])
  assert.throws(() => normalize([{}], 'client', '.'), /Invalid/)
  assert.throws(() => normalize(null, 'client', '.'), /Invalid/)
})

test('only the exact reviewed diagnostic is accepted, including multiplicity', () => {
  assert.deepEqual(compareBaseline([finding], baseline), {unexpected: [], resolved: []})
  for (const change of [{code: 'undefined-global'}, {message: 'New type mismatch'}, {source: 'return unknown()'}]) {
    assert.equal(compareBaseline([{...finding, ...change}], baseline).unexpected.length, 1)
  }
  assert.equal(compareBaseline([finding, finding], baseline).unexpected.length, 1)
  assert.equal(compareBaseline([{...finding, severity: 1}], baseline).unexpected.length, 1, 'errors are never baselined')
})

test('fixed warnings must be removed and untriaged/duplicate entries fail', () => {
  assert.equal(compareBaseline([], baseline).resolved.length, 1)
  assert.throws(() => compareBaseline([], {...baseline, reasons: {}}), /Untriaged/)
  assert.throws(() => compareBaseline([], {...baseline, entries: [...baseline.entries, ...baseline.entries]}), /Duplicate/)
})

test('client and server scopes retain shared code while separating runtime sides', () => {
  for (const file of ['init.lua', 'fxmanifest.lua', 'lib/providers/shared/resolver.lua']) {
    assert(forSide(file, 'client') && forSide(file, 'server'), file)
  }
  for (const file of ['client.lua', 'modules/framework/es_extended/client.lua', 'lib/entities/client/client_entity.lua', 'settings/clientConfig.lua']) {
    assert(forSide(file, 'client') && !forSide(file, 'server'), file)
  }
  for (const file of ['server.lua', 'modules/framework/es_extended/server.lua', 'lib/entities/server/server_entity.lua', 'settings/serverConfig.lua']) {
    assert(forSide(file, 'server') && !forSide(file, 'client'), file)
  }
})
