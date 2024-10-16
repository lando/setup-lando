'use strict';


module.exports = (command, landoBin = 'lando') => {
  // throw if not a string
  if (typeof command !== 'string') throw new Error('Setup command must be a string!');
  // validate a few things
  if (!command.includes('lando setup')) {
    throw new Error(`Setup command must include "lando setup"! You tried to run "${command}"`);
  }

  // break command into pieces if there are multiple commands
  return command
    .split('&&')
    .map(command => command.replace(/lando /g, `"${landoBin.replace(/\\/g, '\\\\')}" `))
    .map(command => command.trim());
};
