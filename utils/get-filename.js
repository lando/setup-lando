'use strict';

const {s3Releases} = require('./get-convenience-aliases');

module.exports = (version, {os, architecture, slim = false} = {}) => {
  // start by building the lando file string
  const parts = ['lando'];
  parts.push(os === 'Windows' ? 'win' : os.toLowerCase());
  parts.push(architecture.toLowerCase());

  // if version is a dev release from s3
  // @TODO: we allow s3 convenience aliases with major version stuff eg 4-dev but we dont actually
  // have those releases labeled in S3, thats fine with just Lando 3 but with Lando 4 we probably need
  // to have ALL of the below
  //
  // https://files.lando.dev/cli/lando-macos-arm64-dev
  // https://files.lando.dev/cli/lando-macos-arm64-3-dev
  // https://files.lando.dev/cli/lando-macos-arm64-4-dev
  //
  // right now we basically just strip the version
  if (s3Releases.includes(version)) {
    // add the s3 alias
    parts.push(version.split('-').length === 2 ? version.split('-')[1] : version.split('-')[0]);
  // otherwise append the version
  } else parts.push(version);

  // add slim if needed
  if (slim) parts.push('slim');

  // and add special handling for windows
  return os === 'Windows' ? `${parts.join('-')}.exe` : parts.join('-');
};
