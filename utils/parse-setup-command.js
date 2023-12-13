'use strict';

const {parseArgsStringToArgv} = require('string-argv');

module.exports = command => {
  // throw if not a string
  if (typeof command !== 'string') throw new Error('Setup command must be a string!');
  // parse string
  command = parseArgsStringToArgv(command);
  // validate a few things
  if (command[0] !== 'lando' || command[1] !== 'setup') {
    throw new Error(`Setup command must begin with "lando setup"! You tried to run "${command.join(' ')}"`);
  }
  // remove first lando because we only care about the args
  command.shift();
  return command;
};
