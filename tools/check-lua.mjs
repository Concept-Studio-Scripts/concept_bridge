import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, writeFileSync } from 'node:fs'
import { dirname, isAbsolute, join, relative, resolve, sep } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const readJson = file => JSON.parse(readFileSync(file, 'utf8').replace(/^\uFEFF/, ''))

export function runtimeFiles(directory, ignored) {
  const found = []
  function walk(folder) {
    for (const entry of readdirSync(folder, { withFileTypes: true })) {
      if (ignored.includes(entry.name)) continue
      const file = join(folder, entry.name)
      assert(!entry.isSymbolicLink(), 'Static analysis does not follow source symlinks.')
      if (entry.isDirectory()) walk(file)
      else if (entry.name.endsWith('.lua')) found.push(relative(directory, file).split(sep).join('/'))
    }
  }
  walk(directory)
  assert(found.length, 'No runtime Lua files found.')
  return found.sort()
}

export function forSide(file, side) {
  const other = side === 'client' ? 'server' : 'client'
  return !file.split('/').includes(other) && file.split('/').at(-1) !== other + '.lua'
    && file !== 'settings/' + other + 'Config.lua'
}

export function normalize(report, side, directory) {
  assert(report && !Array.isArray(report) && typeof report === 'object', 'Invalid LuaLS report.')
  return Object.entries(report).flatMap(([uri, diagnostics]) => {
    const file = relative(directory, fileURLToPath(uri)).split(sep).join('/')
    assert(!file.startsWith('../') && !isAbsolute(file), 'Diagnostic outside the checked workspace.')
    const lines = readFileSync(join(directory, file), 'utf8').split(/\r?\n/)
    assert(Array.isArray(diagnostics), 'Invalid diagnostic list.')
    return diagnostics.map(d => {
      const line = d.range?.start?.line
      assert(Number.isInteger(line) && line >= 0 && line < lines.length, 'Invalid diagnostic location.')
      assert(typeof d.code === 'string' && typeof d.message === 'string', 'Invalid diagnostic.')
      return { side, file, code: d.code, source: lines[line].trim(), message: d.message, line: line + 1, severity: d.severity }
    })
  })
}

export const diagnosticKey = d => JSON.stringify([d.side, d.file, d.code, d.source, d.message])

export function compareBaseline(actual, baseline) {
  assert(baseline.version === 1 && Array.isArray(baseline.entries), 'Invalid diagnostic baseline.')
  const expected = new Map()
  for (const entry of baseline.entries) {
    assert(baseline.reasons[entry.reason] && Number.isSafeInteger(entry.count) && entry.count > 0, 'Untriaged baseline entry.')
    const key = diagnosticKey(entry)
    assert(!expected.has(key), 'Duplicate diagnostic baseline entry.')
    expected.set(key, entry.count)
  }
  const unexpected = []
  for (const entry of actual) {
    const key = diagnosticKey(entry)
    const count = expected.get(key) || 0
    if (!count || entry.severity === 1) unexpected.push(entry)
    else expected.set(key, count - 1)
  }
  const resolved = baseline.entries.filter(entry => expected.get(diagnosticKey(entry)) > 0)
  return { unexpected, resolved }
}

function scan(executable, directory, settings, output, expectedVersion) {
  mkdirSync(output, { recursive: true })
  const config = join(output, 'config.json')
  const report = join(output, 'diagnostics.json')
  writeFileSync(config, JSON.stringify(settings, null, 2) + '\n')
  const result = spawnSync(executable, ['--check', directory, '--configpath', config,
    '--checklevel=Warning', '--check_format=json', '--check_out_path', report, '--logpath', output, '--quiet'],
  { encoding: 'utf8', maxBuffer: 2 * 1024 * 1024, timeout: 180000 })
  if (result.error) throw result.error
  assert(result.status === 0 || result.status === 1, result.stderr || result.stdout || 'LuaLS failed.')
  assert(existsSync(report), 'LuaLS produced no fresh report.')
  const log = readFileSync(join(output, 'service.log'), 'utf8')
  assert(log.includes('VERSION:') && new RegExp('VERSION:\\s+' + expectedVersion.replaceAll('.', '\\.') + '\\s').test(log),
    'Use the LuaLS version pinned in tools/lua-analysis-config.json.')
  return readJson(report)
}

export function run(env = process.env) {
  const config = readJson(join(root, 'tools/lua-analysis-config.json'))
  const addon = resolve(env.CFX_LUALS_ADDON || '')
  assert(env.CFX_LUALS_ADDON && existsSync(join(addon, 'plugin.lua')), 'Set CFX_LUALS_ADDON to the pinned addon checkout.')
  const revision = spawnSync('git', ['-C', addon, 'rev-parse', 'HEAD'], { encoding: 'utf8' })
  assert(revision.status === 0 && revision.stdout.trim() === config.addonRef, 'Use the pinned FiveM addon revision.')
  const addonChanges = spawnSync('git', ['-C', addon, 'status', '--porcelain', '--untracked-files=no'], { encoding: 'utf8' })
  assert(addonChanges.status === 0 && !addonChanges.stdout.trim(), 'The pinned addon must have no tracked modifications.')
  const executable = env.LUA_LS || 'lua-language-server'
  const outputRoot = join(root, 'release', 'lua-analysis')
  mkdirSync(outputRoot, { recursive: true })
  const output = mkdtempSync(join(outputRoot, 'run-'))
  const library = ['runtime', 'natives/GTAV', 'natives/CFX-NATIVE'].map(part => join(addon, 'library', part))
  const settings = { ...config.settings, 'runtime.plugin': join(addon, 'plugin.lua'), 'workspace.library': library }
  const files = runtimeFiles(root, config.settings['workspace.ignoreDir'])
  const diagnostics = []
  const coverage = {}
  for (const side of ['client', 'server']) {
    const sideSettings = { ...settings, 'workspace.ignoreDir': [...settings['workspace.ignoreDir'],
      ...files.filter(file => !forSide(file, side))] }
    const report = scan(executable, root, sideSettings, join(output, side), config.luaLS)
    const results = normalize(report, side, root)
    coverage[side] = files.filter(file => forSide(file, side))
    assert(results.every(d => coverage[side].includes(d.file)), 'Unexpected file in side-specific analysis.')
    diagnostics.push(...results)
  }
  assert(files.every(file => coverage.client.includes(file) || coverage.server.includes(file)), 'Runtime file excluded from both passes.')

  // Negative controls catch a disabled/no-op checker and unsupported CfxLua syntax.
  const probe = join(output, 'probe')
  mkdirSync(probe)
  writeFileSync(join(probe, 'names.lua'), 'local value = static_analysis_missing_symbol()\nprint(value)\n')
  writeFileSync(join(probe, 'syntax.lua'), 'local broken =\n')
  writeFileSync(join(probe, 'cfx.lua'), 'local obj = {}\nlocal value = obj?.value or 0\nvalue += 1\nlocal hash = ' + String.fromCharCode(96) + 'adder' + String.fromCharCode(96) + '\nprint(value, hash)\n')
  const probes = normalize(scan(executable, probe, settings, join(output, 'probe-log'), config.luaLS), 'client', probe)
  assert(probes.some(d => d.code === 'undefined-global') && probes.some(d => d.severity === 1), 'LuaLS failed its negative controls.')
  assert(!probes.some(d => d.file === 'cfx.lua'), 'CfxLua syntax is not configured correctly.')

  writeFileSync(join(output, 'summary.json'), JSON.stringify({ coverage, diagnostics }, null, 2) + '\n')
  const baseline = readJson(join(root, 'tools/lua-diagnostics-baseline.json'))
  const { unexpected, resolved } = compareBaseline(diagnostics, baseline)
  for (const d of unexpected) console.error(d.side + ':' + d.file + ':' + d.line + ' [' + d.code + '] ' + d.message)
  for (const d of resolved) console.error('Remove resolved baseline entry: ' + d.side + ':' + d.file + ' [' + d.code + ']')
  assert(!unexpected.length && !resolved.length, 'Static diagnostics changed. Fix new issues and explicitly review baseline changes. Report: ' + output)
  console.log('LuaLS: ' + files.length + ' runtime files, ' + coverage.client.length + ' client/shared and ' +
    coverage.server.length + ' server/shared; ' + diagnostics.length + ' explicitly triaged diagnostics, no new findings. Report: ' + output)
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) run()

