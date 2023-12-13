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

const getDebug = () => {
  // GITHUB ACTIONS logix
  if (process.env.GITHUB_ACTIONS) return core.getBooleanInput('debug') || process.env['RUNNER_DEBUG'] === '1' || false;
  // otherwise we assume this is running locally eg for dev/test so just set to true as that is a sensible thing
  return true;
};

const getOS = () => {
  if (!get(process, 'env.RUNNER_OS', false)) {
    if (process.platform === 'win32') process.env.RUNNER_OS = 'Windows';
    else if (process.platform === 'darwin') process.env.RUNNER_OS = 'macOS';
    else process.env.RUNNER_OS = 'Linux';
  }
  return get(process, 'env.RUNNER_OS', 'unknown');
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
  autoSetup: core.getInput('auto-setup'),
  debug: getDebug(),
  os: core.getInput('os') || getOS(),
  telemetry: process.env.GITHUB_ACTIONS ? core.getBooleanInput('telemetry') : true,
  setup: core.getInput('setup'),
});
