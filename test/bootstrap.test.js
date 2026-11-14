'use strict';

const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {test} = require('node:test');

const root = path.resolve(__dirname, '..');
const hasPowerShell = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-Command', 'exit 0']).status === 0;

// Run the unmodified entrypoint in a separate process. Stop at its first version diagnostic,
// before release lookup/installation; forbid network, writes and all non-Git child commands.
const preload = `
const deny = () => { throw new Error('forbidden bootstrap side effect'); };
for (const name of ['http', 'https']) {
  const module = require(name);
  module.request = module.get = deny;
}
require('net').connect = require('net').createConnection = require('tls').connect = deny;
global.fetch = deny;
const fs = require('fs');
for (const name of ['writeFileSync', 'appendFileSync', 'mkdirSync', 'chmodSync', 'renameSync', 'unlinkSync']) {
  fs[name] = deny;
}
const cp = require('child_process');
const execSync = cp.execSync;
cp.execSync = (command, options) => {
  if (!command.startsWith('git describe ')) return deny();
  return execSync(command, options);
};
for (const name of ['exec', 'execFile', 'execFileSync', 'spawn', 'spawnSync', 'fork']) cp[name] = deny;
const write = process.stdout.write.bind(process.stdout);
process.stdout.write = (chunk, ...args) => {
  const match = String(chunk).match(/running setup-lando.js script version: ([^\\r\\n]+)/);
  if (match) {
    write('BOOTSTRAP_VERSION=' + match[1] + '\\n');
    process.exit(0);
  }
  return write(chunk, ...args);
};
`;

const fixture = t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'setup-bootstrap-'));
  t.after(() => fs.rmSync(dir, {recursive: true, force: true}));
  fs.mkdirSync(path.join(dir, 'empty'));
  fs.writeFileSync(path.join(dir, 'guard.cjs'), preload);
  return dir;
};

const actionBootstrap = (dir, file, noGit = false) => spawnSync(process.execPath,
  ['--require', path.join(dir, 'guard.cjs'), file], {
    cwd: path.join(dir, 'empty'), encoding: 'utf8',
    env: {...process.env, ...(noGit ? {PATH: ''} : {}), GITHUB_ACTIONS: '',
      GITHUB_WORKSPACE: path.join(dir, 'empty'), GIT_CEILING_DIRECTORIES: path.dirname(dir)},
  });

const assertBootstrap = (result, expected) => {
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.match(result.stdout, expected);
  assert.doesNotMatch(result.stderr, /not a git repository|Command failed|not recognized|not found/);
};

test('exact Action bundle boots from an empty consumer cwd using its own repository', t => {
  const dir = fixture(t);
  const expected = spawnSync('git', ['describe', '--tags', '--always', '--abbrev=1'],
    {cwd: root, encoding: 'utf8'});
  assert.equal(expected.status, 0, expected.stderr);
  const result = actionBootstrap(dir, path.join(root, 'dist/index.js'));
  assertBootstrap(result, /BOOTSTRAP_VERSION=/);
  assert.equal(result.stdout.trim(), `BOOTSTRAP_VERSION=${expected.stdout.trim()}`);
  t.diagnostic(result.stdout.trim());
});

for (const noGit of [false, true]) {
  test(`standalone exact Action bundle boots without a repository (Git absent: ${noGit})`, t => {
    const dir = fixture(t);
    const bundle = path.join(dir, 'index.js');
    for (const file of ['index.js', 'index.js.map', 'sourcemap-register.js']) {
      fs.copyFileSync(path.join(root, 'dist', file), path.join(dir, file));
    }
    const result = actionBootstrap(dir, bundle, noGit);
    assertBootstrap(result, /BOOTSTRAP_VERSION=development/);
    t.diagnostic(result.stdout.trim());
  });
}

const windowsBootstrap = (dir, file, gitMode = 'missing') => spawnSync('pwsh',
  ['-NoProfile', '-NonInteractive', '-Command', `
$ErrorActionPreference = 'Stop'
$env:PATH = ''
if (Get-Command git -ErrorAction SilentlyContinue) { throw 'Git must be absent' }
function Deny-Effect { throw 'forbidden installer side effect' }
foreach ($name in @('Invoke-WebRequest', 'Invoke-RestMethod', 'Start-Process', 'Set-ItemProperty',
  'New-Item', 'Set-Content', 'Add-Content', 'Move-Item', 'Copy-Item', 'Remove-Item')) {
  Set-Item -Path "function:$name" -Value \${function:Deny-Effect}
}
if ($env:TEST_GIT_MODE -ne 'missing') {
  function git {
    if ($args[0] -ne '-C' -or $args[1] -ne (Split-Path $env:TEST_INSTALLER)) {
      throw 'Git must be source-relative'
    }
    if ($env:TEST_GIT_MODE -eq 'failed') { $global:LASTEXITCODE = 128; return 'not-a-version' }
    $global:LASTEXITCODE = 0
    return 'source-description'
  }
}
$null = . $env:TEST_INSTALLER -Help
Write-Output "BOOTSTRAP_VERSION=$SCRIPT_VERSION"
`], {cwd: path.join(dir, 'empty'), encoding: 'utf8', env: {...process.env,
    TEST_INSTALLER: file, TEST_GIT_MODE: gitMode, PROCESSOR_ARCHITECTURE: 'AMD64'}});

for (const file of ['setup-lando.ps1', 'dist/setup-lando.ps1']) {
  for (const mode of ['missing', 'failed', 'success']) {
    test(`${file}: full Windows help bootstrap with Git ${mode}`,
      {skip: !hasPowerShell && 'PowerShell unavailable'}, t => {
        const dir = fixture(t);
        const expected = mode === 'success' ? /BOOTSTRAP_VERSION=source-description/ : /BOOTSTRAP_VERSION=development/;
        assertBootstrap(windowsBootstrap(dir, path.join(root, file), mode), expected);
      });
  }
}

test('release versioner still overrides both development bootstrap paths',
  {skip: !hasPowerShell && 'PowerShell unavailable'}, t => {
    const dir = fixture(t);
    const dist = path.join(dir, 'dist');
    fs.mkdirSync(dist);
    for (const file of ['index.js', 'index.js.map', 'sourcemap-register.js', 'setup-lando.ps1', 'setup-lando.sh']) {
      fs.copyFileSync(path.join(root, 'dist', file), path.join(dist, file));
    }
    fs.copyFileSync(path.join(root, 'versioner.js'), path.join(dir, 'versioner.js'));
    // A test-only sentinel, never used to generate committed artifacts or asserted to be a release.
    const result = spawnSync(process.execPath, [path.join(dir, 'versioner.js')],
      {encoding: 'utf8', env: {...process.env, SCRIPT_VERSION: 'test-stamp'}});
    assert.equal(result.status, 0, result.stderr);
    assertBootstrap(actionBootstrap(dir, path.join(dist, 'index.js'), true), /BOOTSTRAP_VERSION=test-stamp/);
    assertBootstrap(windowsBootstrap(dir, path.join(dist, 'setup-lando.ps1')), /BOOTSTRAP_VERSION=test-stamp/);
    assert.ok(fs.readFileSync(path.join(dist, 'setup-lando.sh'), 'utf8').startsWith('SCRIPT_VERSION="test-stamp"\n'));
  });
