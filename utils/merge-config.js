'use strict';

const set = require('lodash.set');

module.exports = (config = {}, pairs = []) => {
  // go through pairs and set into config
  pairs.forEach(line => {
    if (Array.isArray(line)) set(config, line[0], line[1]);
    else if (typeof line === 'string') {
      const key = line.split('=')[0];
      const value = line.split('=')[1];
      set(config, key, value);
    }
  });

  return config;
};
