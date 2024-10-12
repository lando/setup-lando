'use strict';

const isValidUrl = require('./is-valid-url');
const {s3Releases} = require('./get-convenience-aliases');

module.exports = (version, {os, architecture, slim = false} = {}) => {
  // if version is actually a downlaod url then just return that right away
  if (isValidUrl(version)) return version;

  // otherwise start by building the lando file string
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
  const filename = os === 'Windows' ? `${parts.join('-')}.exe` : parts.join('-');

  // if an s3 release alias
  if (s3Releases.includes(version) || version.includes('preview')) {
    if (version.includes('4')) return `https://files.lando.dev/core-next/${filename}`;
    else return `https://files.lando.dev/core/${filename}`;
  }

  // otherwise github?
  if (version.startsWith('v4')) return `https://github.com/lando/core-next/releases/download/${filename}`;
  else return `https://github.com/lando/core/releases/download/${filename}`;
};
