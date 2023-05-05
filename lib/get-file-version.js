'use strict';

const core = require('@actions/core');
const fs = require('fs');
const os = require('os');
const path = require('path');

module.exports = file => {
  // if no file then return right away
  if (!file) return;

  // if file is not absolute then prepend some bases as needed
  if (!path.isAbsolute(file)) file = path.join(process.env.GITHUB_WORKSPACE || process.cwd(), file);

  // if the file does not exist then notify and return
  if (!fs.existsSync(file)) {
    core.notice(`Could not locate a version file at ${file}`);
    return;
  }

  // Otherwise try to parse it depending on what it is, we start first with a "tool-versions" file
  if (path.basename('.tool-versions')) {
    const contents = fs.readFileSync(file, 'utf8');
    const versions = Object.fromEntries(contents.trim().split(os.EOL).map(tool => tool.split(' ')));
    return versions.lando;
  }

  // If not .tool-versions then we just assume a single JSON version entry
  try {
    const version = fs.readFileSync(file, 'utf8');
    return version.trim();
  } catch {
    core.error(`Error reading version file ${file}`);
  }
};
