'use strict';

const core = require('@actions/core');
const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');

module.exports = file => {
  // if no file then return empty config
  if (!file) return;

  // if file is not absolute then prepend some bases as needed
  if (!path.isAbsolute(file)) file = path.join(process.env.GITHUB_WORKSPACE || process.cwd(), file);

  // if the file does not exist then notify and return
  if (!fs.existsSync(file)) {
    core.notice(`Could not locate a config file at ${file}`);
    return;
  }

  // otherwise return the config values
  try {
    return yaml.load(fs.readFileSync(file));
  } catch {
    core.error(`Error reading config file ${file}`);
  }
};
