'use strict';

module.exports = (command, landoBin = 'lando') => {
  // throw if not a string
  if (typeof command !== 'string') throw new Error('Setup command must be a string!');
  // validate a few things
  if (!command.includes('lando setup')) {
    throw new Error(`Setup command must include "lando setup"! You tried to run "${command}"`);
  }

  // return command but with lando invocations replaced with absolute paths to the landoBin
  return command.replace(/lando /g, `${landoBin} `);
};
