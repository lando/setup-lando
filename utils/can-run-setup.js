'use strict';

const satisfies = require('semver/functions/satisfies');

// Call this with the installed binary's version, including for dev/local downloads.
module.exports = version => satisfies(version, '>=3.21.0-0 <4.0.0-0', {includePrerelease: true, loose: true});
