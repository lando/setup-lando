'use strict';

const satisfies = require('semver/functions/satisfies');
const {s3Releases} = require('./get-convenience-aliases');

module.exports = version => {
  // slim can be any v3 s3 alias
  if (s3Releases.includes(version)) return version.split('-')[0] === '3';
  // or anything in the range
  return satisfies(version, '>3.20 <4', {includePrerelease: true, loose: true});
};
