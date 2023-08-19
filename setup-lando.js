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

const getConfigFile = require('./lib/get-config-file');
const getDownloadUrl = require('./lib/get-download-url');
const getGCFPath = require('./lib/get-gcf-path');
const getInputs = require('./lib/get-inputs');
const getFileVersion = require('./lib/get-file-version');
const getObjectKeys = require('./lib/get-object-keys');
const mergeConfig = require('./lib/merge-config');
const resolveVersionSpec = require('./lib/resolve-version-spec');

const main = async () => {
  // ensure needed RUNNER_ vars are set
  // @NOTE: this is just to ensure we can run this locally
  if (!get(process, 'env.RUNNER_DEBUG', false)) process.env.RUNNER_DEBUG = core.isDebug();
  if (!get(process, 'env.RUNNER_TEMP', false)) process.env.RUNNER_TEMP = os.tmpdir();
  if (!get(process, 'env.RUNNER_TOOL_CACHE', false)) process.env.RUNNER_TOOL_CACHE = os.tmpdir();

  // start by getting the inputs and stuff
  const inputs = getInputs();

  // show a warning if both version inputs are set
  if (inputs.landoVersion && inputs.landoVersionFile) {
    core.warning('Both lando-version and lando-version-file inputs are specified, only lando-version will be used');
  }

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

    // start by assuming that version is just the path to some locally installed version of lando
    let landoPath = version;

    // if that assumption is wrong then we need to attempt a download
    if (!fs.existsSync(landoPath)) {
      // determine url of lando version to install
      const downloadUrl = getDownloadUrl(version, inputs);
      core.debug(`going to download version ${version} from ${downloadUrl}`);
      core.startGroup('Download information');
      core.info(`spec: ${spec}`);
      core.info(`version: ${version}`);
      core.info(`url: ${downloadUrl}`);
      core.endGroup();

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

    // reset version information, we do this to get the source of truth on what we've downloaded
    fs.chmodSync(landoPath, '755');
    const output = execSync(`${landoPath} version`, {maxBuffer: 1024 * 1024 * 10, encoding: 'utf-8'});
    version = output.split(' ').length === 2 ? output.split(' ')[1] : output.split(' ')[0];
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

    // if debug i son then lets set that in the config file unless its already been set
    //  if (core.isDebug() || inputs.debug) {
    //   // only set DEBUG="lando*" if DEBUG hasnt already been set
    //   // @TODO: ideally we can get rid of this in favor of better/more unified debug activitation
    //   if (!get(process, 'env.DEBUG', false)) core.exportVariable('envVar', 'Val');
    //   process.env.DEBUG='lando*';
    // @NOTE: we use proces.env.DEBUG instead of core.exportVariable because we dont want to pollute downstream steps?

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

    // if we have telemetry off on v3 we need to turn report errors off
    if (!inputs.telemetry && lmv === 'v3') {
      const reportFile = path.join(path.dirname(gcf), 'cache', 'report_errors');
      await io.mkdirP(path.dirname(reportFile));
      fs.writeFileSync(reportFile, 'false');
      await exec.exec('cat', [reportFile]);
    }

    // do v3 dependency checks if warn or error
    if (lmv === 'v3' && ['warn', 'error'].includes(inputs.dependencyCheck)) {
      const docker = await exec.exec('docker', ['info'], {ignoreReturnCode: true});
      const dockerCompose = await exec.exec('docker-compose', ['--version'], {ignoreReturnCode: true});
      const func = inputs.dependencyCheck === 'warn' ? core.warning : core.setFailed;
      const suffix = 'See: https://docs.lando.dev/getting-started/installation.html';
      if (docker !== 0 ) {
        func(`Something is wrong with Docker! Make sure Docker is installed correctly and running. ${suffix}`);
      }
      if (dockerCompose !== 0 ) {
        func(`Something is wrong with Docker Compose! Make sure Docker Compose 1.x is installed correctly. ${suffix}`);
      }
    }

    // @TODO: v4 dep checking?

    // if debug then print the entire lando config
    if (core.isDebug() || inputs.debug) await exec.exec('lando', ['config']);

  // catch unexpected
  } catch (error) {
    core.setFailed(error.message);
  }
};

// main logix
main();
