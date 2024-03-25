'use strict';

const isDisabled = require('./is-disabled');

module.exports = setup => {
  // if its jsut disabled then return false
  if (isDisabled(setup)) return false;

  // if its a truthy value somehow then assume that is auto
  if (setup === true || setup === 1) setup = 'auto';

  // check to see if auto mode is on
  if (typeof setup === 'string' &&
    (setup.toUpperCase() === '1' ||
    setup.toUpperCase() === 'AUTO' ||
    setup.toUpperCase() === 'ENABLED' ||
    setup.toUpperCase() === 'ON' ||
    setup.toUpperCase() === 'RUN' ||
    setup.toUpperCase() === 'TRUE'
    )) {
    setup = 'lando setup';
  }

  // if we get here we *should* have a string command we can parse
  return setup;
};
