'use strict';

const isValidUrl = require('./is-valid-url');
const getFilename = require('./get-filename');

const {s3Releases} = require('./get-convenience-aliases');

module.exports = (version, {os, architecture, slim = false} = {}) => {
  // if version is actually a downlaod url then just return that right away
  if (isValidUrl(version)) return version;

  // otherwise construct the filename
  const filename = getFilename(version, {os, architecture, slim});

  // if an s3 release alias
  if (s3Releases.includes(version) || version.includes('preview')) {
    if (version.includes('4')) return `https://files.lando.dev/core-next/${filename}`;
    else return `https://files.lando.dev/core/${filename}`;
  }

  // otherwise github?
  if (version.startsWith('v4')) return `https://github.com/lando/core-next/releases/download/${version}/${filename}`;
  else return `https://github.com/lando/core/releases/download/${version}/${filename}`;
};
