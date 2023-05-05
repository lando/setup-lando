'use strict';

const {s3Releases} = require('./get-convenience-aliases');

const s3Base = 'https://files.lando.dev/cli';
const gitHubBase = 'https://github.com/lando/cli/releases/download';

module.exports = (version, {os, architecture} = {}) => {
  // start by building the lando file string
  const parts = ['lando'];
  parts.push(os === 'Windows' ? 'win' : os.toLowerCase());
  parts.push(architecture.toLowerCase());

  // if version is a dev release from s3
  if (s3Releases.includes(version)) parts.push(version.split('-').length === 2 ? version.split('-')[1] : version.split('-')[0]);
  // otherwise append the version and url from github
  else parts.push(version);
  // and add special handling for windows
  const filename = os === 'Windows' ? `${parts.join('-')}.exe` : parts.join('-');

  // return the correct filename
  return s3Releases.includes(version) ? `${s3Base}/${filename}` : `${gitHubBase}/${version}/${filename}`;
};
