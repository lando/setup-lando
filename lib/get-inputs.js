'use strict';

const core = require('@actions/core');
const get = require('lodash.get');
const os = require('os');

const getArch = () => {
  if (!get(process, 'env.RUNNER_ARCH', false)) {
    process.env.RUNNER_ARCH = os.arch().toUpperCase();
  }
  return get(process, 'env.RUNNER_ARCH', 'unknown');
};

const getOS = () => {
  if (!get(process, 'env.RUNNER_OS', false)) {
    if (process.platform === 'win32') process.env.RUNNER_OS = 'Windows';
    else if (process.platform === 'darwin') process.env.RUNNER_OS = 'macOS';
    else process.env.RUNNER_OS = 'Linux';
  }
  return get(process, 'env.RUNNER_OS', 'unknown');
};

const getDepCheck = () => {
  if (!['warn', 'error'].includes(core.getInput('dependency-check'))) return false;
  else return core.getInput('dependency-check');
};

module.exports = () => ({
  // primary inputs
  landoVersion: String(core.getInput('lando-version')),
  landoVersionFile: core.getInput('lando-version-file'),
  config: core.getMultilineInput('config'),
  configFile: core.getInput('config-file'),
  token: core.getInput('token') || get(process, 'env.GITHUB_TOKEN'),

  // other inputs
  architecture: core.getInput('architecture') || getArch(),
  dependencyCheck: getDepCheck(),
  debug: process.env.GITHUB_ACTIONS ? core.getBooleanInput('debug') : true,
  os: core.getInput('os') || getOS(),
  telemetry: process.env.GITHUB_ACTIONS ? core.getBooleanInput('telemetry') : true,
});
