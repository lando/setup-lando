'use strict';

const path = require('path');

const getOClifBase = () => {
  const base = process.env['XDG_CACHE_HOME'] ||
    (process.platform === 'win32' && process.env.LOCALAPPDATA) ||
    path.join(getOClifHome(), '.config');
  return path.join(base, 'lando');
};

const getOClifHome = () => {
  switch (process.platform) {
    case 'darwin':
    case 'linux':
      return process.env.HOME || os.homedir() || os.tmpdir();
    case 'win32':
      return process.env.HOME ||
      (process.env.HOMEDRIVE && process.env.HOMEPATH && path.join(process.env.HOMEDRIVE, process.env.HOMEPATH)) ||
      process.env.USERPROFILE ||
      os.homedir() ||
      os.tmpdir();
  }
};

module.exports = (lmv = 3) => {
  // if this is lando 3 then
  if (lmv === 3) return path.join(getOClifHome(), '.lando', 'config.yml');
  // otherwise we assume lando 4
  return path.join(getOClifBase(), 'config.yaml');
};
