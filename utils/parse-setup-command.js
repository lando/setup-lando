'use strict';

module.exports = (command, landoBin = 'lando') => {
  // throw if not a string
  if (typeof command !== 'string') throw new Error('Setup command must be a string!');
  // validate a few things
  if (!command.includes('lando setup')) {
    throw new Error(`Setup command must include "lando setup"! You tried to run "${command}"`);
  }

  // return command with absolute paths so the landoPath
  return command.replace(/lando/g, landoBin);
};
