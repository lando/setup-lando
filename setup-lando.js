'use strict';

const core = require('@actions/core');
const exec = require('@actions/exec');
const fs = require('fs');
const get = require('lodash.get');
const io = require('@actions/io');
const os = require('os');
const path = require('path');
const set = require('lodash.set');
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
const resolveVersionSpec = require('./lib/resolve-version-spec');

const main = async () => {
  // start by getting the inputs
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
    // @TODO: what about installing from source?
    let version = resolveVersionSpec(spec, releases);
    // throw error if we cannot resolve a version
    if (!version) throw new Error(`Could not resolve "${spec}" into an installable version of Lando`);

    // determine url of lando version to install
    const downloadUrl = getDownloadUrl(version, inputs);
    core.debug(`going to download version ${version} from ${downloadUrl}`);
    core.startGroup('Download information');
    core.info(`spec: ${spec}`);
    core.info(`version: ${version}`);
    core.info(`url: ${downloadUrl}`);
    core.endGroup();

    // ensure needed RUNNER_ vars are set
    // @NOTE: this is just to ensure we can run this locally
    if (!get(process, 'env.RUNNER_TEMP', false)) process.env.RUNNER_TEMP = os.tmpdir();
    if (!get(process, 'env.RUNNER_TOOL_CACHE', false)) process.env.RUNNER_TOOL_CACHE = os.tmpdir();

    // download lando
    // @NOTE: separate try catch here because we dont get a great error message from download tool
    let landoPath;
    try {
      landoPath = await tc.downloadTool(downloadUrl);
    } catch (error) {
      throw new Error(`Unable to download Lando ${version} from ${downloadUrl}. ${error.message}`);
    }

    // if on windows we need to move and rename so it ends in exe
    if (inputs.os === 'Windows') {
      await io.cp(landoPath, `${landoPath}.exe`, {force: true});
      landoPath = `${landoPath}.exe`;
    }

    // make executable
    fs.chmodSync(landoPath, '755');

    // reset version information, we do this to get the source of truth on what we've downloaded
    const output = execSync(`${landoPath} version`, {maxBuffer: 1024 * 1024 * 10, encoding: 'utf-8'});
    version = output.split(' ').length === 2 ? output.split(' ')[1] : output.split(' ')[0];
    core.debug(`downloaded lando is version ${version}`);

    // move into the tool cache and compute path
    const targetFile = inputs.os === 'Windows' ? 'lando.exe' : 'lando';
    const toolDir = await tc.cacheFile(landoPath, targetFile, 'lando', version);
    landoPath = path.join(toolDir, targetFile);
    core.debug(`lando installed at ${landoPath}`);

    // set the path and outputs
    core.addPath(toolDir);
    core.setOutput('lando-path', landoPath);

    // start with either the config file or an empty object
    const config = getConfigFile(inputs.configFile) || {};
    // if we have config then loop through that and set
    if (inputs.config) {
      inputs.config.forEach(line => {
        const key = line.split('=')[0];
        const value = line.split('=')[1];
        set(config, key, value);
      });
    }

    // set config info
    core.startGroup('Configuration information');
    getObjectKeys(config).forEach(key => core.info(`${key}: ${get(config, key)}`));
    core.endGroup();

    // write the config file to disk
    const gcf = getGCFPath();
    await io.mkdirP(path.dirname(gcf));
    fs.writeFileSync(gcf, yaml.dump(config));

    // get version
    await exec.exec('lando', ['version']);
    // get config
    await exec.exec('cat', [gcf]);
    // print full config?
    core.startGroup('Lando information');
    await exec.exec('lando', ['config']);
    core.endGroup();

  // catch unexpected
  } catch (error) {
    core.setFailed(error.message);
  }
};

// main logix
main();
