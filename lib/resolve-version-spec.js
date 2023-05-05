'use strict';

const core = require('@actions/core');
const tc = require('@actions/tool-cache');

const {s3Releases, gitHubReleases} = require('./get-convenience-aliases');

module.exports = (spec, releases = [], dmv = 3) => {
  // start by returning any special "dev" aliases
  if (s3Releases.includes(spec)) return spec;

  // then attempt to resolve special "convenience" aliases to actual versions
  if (gitHubReleases.includes(spec)) {
    const mv = spec.split('-').length === 1 ? dmv : spec.split('-')[0];
    const prerelease = spec.split('-').length === 1 ? spec.split('-')[0] === 'edge' : spec.split('-')[1] === 'edge';
    // fitler based on release type and reset spec
    releases = releases.filter(release => release.prerelease === prerelease);
    spec = `>=${mv}`;
    // debug
    core.debug(`filtered to ${releases.length} prereleases`);
    core.debug(`reset version spec ${spec}`);
  }

  // eval and return
  return tc.evaluateVersions(releases.map(release => release.tag_name), spec);
};
