'use strict';

const core = require('@actions/core');
const exec = require('@actions/exec');
const fs = require('fs');
const get = require('lodash.get');
const io = require('@actions/io');
const os = require('os');
const path = require('path');
const tc = require('@actions/tool-cache');
const yaml = require('js-yaml');

const {execSync} = require('child_process');
const {GitHub, getOctokitOptions} = require('@actions/github/lib/utils');
const {paginateRest} = require('@octokit/plugin-paginate-rest');

const getConfigFile = require('./utils/get-config-file');
const getDownloadUrl = require('./utils/get-download-url');
const getGCFPath = require('./utils/get-gcf-path');
const getInputs = require('./utils/get-inputs');
const getFileVersion = require('./utils/get-file-version');
const getObjectKeys = require('./utils/get-object-keys');
const getSetupCommand = require('./utils/get-setup-command');
const mergeConfig = require('./utils/merge-config');
const parseSetupCommand = require('./utils/parse-setup-command');
const resolveVersionSpec = require('./utils/resolve-version-spec');

const main = async () => {
  // ensure needed RUNNER_ vars are set
  // @NOTE: this is just to ensure we can run this locally
  if (!get(process, 'env.GITHUB_WORKSPACE', false)) process.env.GITHUB_WORKSPACE = process.cwd();
  if (!get(process, 'env.RUNNER_DEBUG', false)) process.env.RUNNER_DEBUG = core.isDebug();
  if (!get(process, 'env.RUNNER_TEMP', false)) process.env.RUNNER_TEMP = os.tmpdir();
  if (!get(process, 'env.RUNNER_TOOL_CACHE', false)) process.env.RUNNER_TOOL_CACHE = os.tmpdir();

  // start by getting the inputs and stuff
  const inputs = getInputs();

  // show a warning if both version inputs are set
  if (inputs.landoVersion && inputs.landoVersionFile) {
    core.warning('Both lando-version and lando-version-file inputs are specified, only lando-version will be used');
  }

  // prefer autoSetup to setup because setup is DEPRECATED
  inputs.setup = inputs.autoSetup ?? inputs.setup;

  // determine lando version spec to install
  const spec = inputs.landoVersion || getFileVersion(inputs.landoVersionFile) || 'stable';
  core.debug(`rolling with "${spec}" as version spec`);

  // get a pagination vibed octokit so we can get ALL release data
  const Octokit = GitHub.plugin(paginateRest);
  const octokit = new Octokit(getOctokitOptions(inputs.token));

  // try/catch
  try {
    const releases = await octokit.paginate('GET /repos/{owner}/{repo}/releases', {owner: 'lando', repo: 'cli', per_page: 100});
    core.debug(`found ${releases.length} valid releases`);

    // attempt to resolve the spec
    let version = resolveVersionSpec(spec, releases);
    // throw error if we cannot resolve a version
    if (!version) throw new Error(`Could not resolve "${spec}" into an installable version of Lando`);
    core.debug(`found ${releases.length} valid releases`);

    // start by assuming that version is just the path to some locally installed version of lando
    let landoPath = version;
    core.startGroup('Version information');
    core.info(`spec: ${spec}`);
    core.info(`version: ${version}`);

    // if that assumption is wrong then we need to attempt a download
    if (!fs.existsSync(landoPath)) {
      // determine url of lando version to install
      const downloadUrl = getDownloadUrl(version, inputs);
      core.debug(`going to download version ${version} from ${downloadUrl}`);
      core.info(`url: ${downloadUrl}`);

      // download lando
      try {
        landoPath = await tc.downloadTool(downloadUrl);
      } catch (error) {
        throw new Error(`Unable to download Lando ${version} from ${downloadUrl}. ${error.message}`);
      }
    }

    // if on windows we need to move and rename so it ends in exe if it doesnt already
    if (inputs.os === 'Windows' && path.extname(landoPath) === '') {
      await io.cp(landoPath, `${landoPath}.exe`, {force: true});
      landoPath = `${landoPath}.exe`;
    }

    core.info(`path: ${landoPath}`);
    core.endGroup();

    // reset version information, we do this to get the source of truth on what we've downloaded
    fs.chmodSync(landoPath, '755');
    const output = execSync(`${landoPath} version`, {
      maxBuffer: 1024 * 1024 * 10,
      encoding: 'utf-8',
      env: {...process.env, LANDO_DEBUG: 0},
    });

    // parse output into version
    version = output.split(' ').length === 2 ? output.split(' ')[1].trim() : output.split(' ')[0].trim();
    const lmv = version.split('.')[0];
    core.debug(`using lando version ${version}, major version ${lmv}`);

    // move into the tool cache and compute path
    const targetFile = inputs.os === 'Windows' ? 'lando.exe' : 'lando';
    const toolDir = await tc.cacheFile(landoPath, targetFile, 'lando', version);
    landoPath = path.join(toolDir, targetFile);

    // set the path and outputs
    core.addPath(toolDir);
    core.setOutput('lando-path', landoPath);
    core.debug(`lando installed at ${landoPath}`);

    // start with either the config file or an empty object
    let config = getConfigFile(inputs.configFile) || {};
    // if we have config then loop through that and set
    if (inputs.config) config = mergeConfig(config, inputs.config);

    // if telemetry is off on v3 then add in more config
    if (!inputs.telemetry && lmv === 'v3') config = mergeConfig(config, [['stats[0].report', false], 'stats[0].url=https://metrics.lando.dev']);
    // or if telemetry is off on v4 then add in more config
    else if (!inputs.telemetry && lmv === 'v4') config = mergeConfig(config, [['core.telemetry', false]]);

    // set config info
    core.startGroup('Configuration information');
    getObjectKeys(config).forEach(key => core.info(`${key}: ${get(config, key)}`));
    core.endGroup();

    // write the config file to disk
    const gcf = getGCFPath(lmv);
    await io.mkdirP(path.dirname(gcf));
    fs.writeFileSync(gcf, yaml.dump(config));

    // get version
    await exec.exec('lando', ['version']);
    // cat config
    await exec.exec('cat', [gcf]);

    // v3 needs a special thing for reporting error value comes from telemetry
    if (lmv === 'v3') {
      const reportFile = path.join(path.dirname(gcf), 'cache', 'report_errors');
      await io.mkdirP(path.dirname(reportFile));
      fs.writeFileSync(reportFile, inputs.telemetry ? 'true' : 'false');
      await exec.exec('cat', [reportFile]);
    }

    // if setup is non-false then we want to try to run it if we can
    if (lmv === 'v3' && getSetupCommand(inputs.setup) !== false) {
      // print warning if setup command does not exist and leave
      if (await exec.exec(landoPath, ['setup', '--help'], {ignoreReturnCode: true}) !== 0) {
        core.warning('lando setup is only available in lando >= 3.21! Skipping!');

      // if we get here then we should be G2G
      } else {
        const args = parseSetupCommand(getSetupCommand(inputs.setup));
        const opts = {env: {...process.env, LANDO_DEBUG: core.isDebug() || inputs.debug}};
        await exec.exec(landoPath, args, opts);
      }
    }

    // if debug then print the entire lando config
    if (core.isDebug() || inputs.debug) await exec.exec(landoPath, ['config']);

    // if core debugging or user debug is on then lets set "LANDO_DEBUG=1"
    // @NOTE: we use core.exportVariable because we want any GHA workflow that uses @lando/setup-lando to not need
    // to handle their own downstream lando debugging. Of course they can if they want since they migth want something
    // more targeted or wide than LANDO_DEBUG=1 eg LANDO_DEBUG="*" or LANDO_DEBUG="lando/core*"
    // we set this at the end so we can more selectively control the debug output above
    if (core.isDebug() || inputs.debug) core.exportVariable('LANDO_DEBUG', 1);

  // catch unexpected
  } catch (error) {
    core.setFailed(error.message);
  }
};

// main logix
main();
