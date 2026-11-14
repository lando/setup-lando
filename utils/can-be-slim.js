'use strict';

const satisfies = require('semver/functions/satisfies');

// Only legacy Lando 3 releases published separate slim assets.
module.exports = version => satisfies(version, '>=3.21.0-0 <3.24.0-0', {includePrerelease: true, loose: true});
