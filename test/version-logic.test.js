'use strict';

const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const {test} = require('node:test');
const vm = require('node:vm');
const canBeSlim = require('../utils/can-be-slim');
const canRunSetup = require('../utils/can-run-setup');
const getDownloadUrl = require('../utils/get-download-url');
const resolveVersionSpec = require('../utils/resolve-version-spec');

const root = path.resolve(__dirname, '..');
process.env.GITHUB_WORKSPACE = root;
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const options = {os: 'Linux', architecture: 'X64', slim: true};
const release = (version, prerelease = false) => ({
  tag_name: version, prerelease,
  assets: [{name: `lando-linux-x64-${version}${canBeSlim(version) ? '-slim' : ''}`}],
});
const versions = ['v3.21.0-beta.10', 'v3.23.11', 'v3.24.0-beta.1', 'v3.24.0', 'v3.26.9', 'v4.0.0-alpha.1'];

for (const version of versions) {
  test(`separate slim and setup capabilities for ${version}`, () => {
    assert.equal(canBeSlim(version), version.startsWith('v3.21') || version.startsWith('v3.23'));
    assert.equal(canRunSetup(version), version.startsWith('v3.'));
  });
}

for (const spec of ['3', 'stable', '3-stable', '3-stable-slim', 'edge', '3-edge-slim']) {
  test(`Action alias ${spec} resolves the modern unified binary`, () => {
    const releases = [release('v4.0.0-alpha.1', true), release('v3.27.0-beta.1', true), release('v3.26.9'),
      release('v3.23.11')];
    const expected = spec.includes('edge') ? 'v3.27.0-beta.1' : 'v3.26.9';
    const version = resolveVersionSpec(spec, releases, 3, options);
    assert.equal(version, expected);
    assert.equal(getDownloadUrl(version, {...options, slim: canBeSlim(version)}),
      `https://github.com/lando/core/releases/download/${version}/lando-linux-x64-${version}`);
  });
}

test('aliases reject missing platform assets without throwing', () => {
  assert.equal(resolveVersionSpec('3-stable-slim', [release('v3.26.9')], 3,
    {...options, architecture: 'arm64'}), null);
});

test('legacy aliases still select slim assets and major 4 aliases stay on major 4', () => {
  assert.equal(resolveVersionSpec('3-stable-slim', [release('v3.23.11')], 3, options), 'v3.23.11');
  assert.equal(resolveVersionSpec('4', [release('v4.0.0')], 3, options), 'v4.0.0');
});

// Run only the actual resolution/decision section, stopping before installer side effects.
// cURL aliases are mocked; no downloads, local installation, Lando, Docker or networks are touched.
const posixDecision = (file, version, {fat = '0', setup = '1', local = false} = {}) => {
  const source = read(file);
  const compare = source.slice(source.indexOf('version_compare() ('), source.indexOf('# abort if we dont have curl'));
  const decision = source.slice(source.indexOf('ORIGINAL_VERSION="$VERSION"'),
    source.indexOf('# determine existing dir'));
  const script = `set -eu\n${compare}\nmajor() { printf '%s' "\${1%%.*}"; }
CURL=mock_curl
mock_curl() { printf '%s' "$TEST_ALIAS"; }
debug() { :; }
abort() { exit 91; }
VERSION="$TEST_VERSION"
LANDO_DEFAULT_MV=3
OS=linux
ARCH=x64
FAT="$TEST_FAT"
SETUP="$TEST_SETUP"
${local ? 'URL=file:///task/lando' : ''}
${decision}
printf '%s|%s|%s' "$URL" "$SETUP" "$LMV"`;
  const result = spawnSync('bash', ['-c', script], {encoding: 'utf8', env: {...process.env,
    TEST_VERSION: version, TEST_ALIAS: 'v3.26.9', TEST_FAT: fat, TEST_SETUP: setup}});
  assert.equal(result.status, 0, result.stderr);
  return result.stdout.split('|');
};

for (const file of ['setup-lando.sh', 'dist/setup-lando.sh']) {
  for (const version of [...versions, '3-stable', '3-edge', '3-dev', '4-dev']) {
    test(`${file}: correct URL and autosetup for ${version}`, () => {
      const [url, setup, major] = posixDecision(file, version);
      assert.equal(setup, major === '3' ? '1' : '0');
      assert.equal(url.endsWith('-slim'), version.startsWith('v3.21') || version.startsWith('v3.23'));
    });
  }
  test(`${file}: fat and no-setup opt-outs are independent; local URLs are untouched`, () => {
    assert.equal(posixDecision(file, 'v3.23.11', {fat: '1'})[0].endsWith('-slim'), false);
    assert.equal(posixDecision(file, 'v3.26.9', {setup: '0'})[1], '0');
    assert.equal(posixDecision(file, 'v3.23.11', {local: true})[0], 'file:///task/lando');
  });
  test(`${file}: successful interactive confirmation keeps a successful exit status`, () => {
    const source = read(file);
    const wait = source.slice(source.indexOf('wait_for_user() {'), source.indexOf('# helpers for more itemized'));
    const result = spawnSync('bash', ['-c', `set -eu
stty() { :; }
tput() { :; }
getc() { printf -v "$1" '\\n'; }
tty_bold=''
tty_reset=''
${wait}
wait_for_user >/dev/null
printf success
exit 0`], {encoding: 'utf8'});
    assert.equal(result.status, 0, result.stderr);
    assert.equal(result.stdout, 'success');
  });
}

// Exercise the Action entry point with all external effects mocked, including filesystem writes.
for (const file of ['setup-lando.js', 'dist/setup-lando.js']) {
  for (const [version, setup, expected] of [['v3.23.11', 'auto', true], ['v3.26.9', 'auto', true],
    ['v3.26.9', 'off', false], ['v3.26.9', 'lando setup --skip-networking', true],
    ['v4.0.0-alpha.1', 'auto', false]]) {
    test(`${file}: Action autosetup ${version} / ${setup}`, async () => {
      const commands = [];
      const inputs = {landoVersion: version, setup, autoSetup: setup, ...options};
      const mocks = {
        '@actions/core': new Proxy({}, {get: (_, name) => name === 'setFailed' ? message => {
          throw new Error(message);
        } : () => {}}),
        '@actions/exec': {exec: async (command, args) => {
          commands.push([command, args]);
          return 0;
        }},
        '@actions/io': {mkdirP: async () => {}},
        '@actions/tool-cache': {downloadTool: async () => '/task/download', cacheFile: async () => '/task/cache'},
        '@actions/github/lib/utils': {GitHub: {plugin: () => class {
          async paginate() {
            return [];
          }
        }}, getOctokitOptions: () => ({})},
        '@octokit/plugin-paginate-rest': {paginateRest: {}},
        'fs': {existsSync: () => false, chmodSync: () => {}, writeFileSync: () => {}},
        'child_process': {execSync: command => command.startsWith('git ') ? 'test-script' : version},
        './utils/get-inputs': () => inputs,
        './utils/get-config-file': () => ({}),
        './utils/resolve-version-spec': () => version,
      };
      const context = {process: {env: {...process.env}, cwd: () => root}, require: name => {
        if (Object.hasOwn(mocks, name)) return mocks[name];
        return name.startsWith('.') ? require(path.resolve(root, name)) : require(name);
      }};
      await vm.runInNewContext(read(file), context);
      const actual = commands.some(([command]) => command.includes('"/task/cache/lando" setup'));
      assert.equal(actual, expected, JSON.stringify(commands));
    });
  }
}

test('copied Action script matches source', () => assert.equal(read('dist/setup-lando.js'), read('setup-lando.js')));
