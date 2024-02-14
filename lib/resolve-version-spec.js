'use strict';

const core = require('@actions/core');
const fs = require('fs');
const path = require('path');
const semver = require('semver');
const tc = require('@actions/tool-cache');

const isValidUrl = require('./is-valid-url');
const {s3Releases, gitHubReleases} = require('./get-convenience-aliases');

module.exports = (spec, releases = [], dmv = 3) => {
  // if spec is a file that exists relative to GITHUB_WORKSPACE then set spec to absolute path based on that
  if (!path.isAbsolute(spec) && fs.existsSync(path.join(process.env['GITHUB_WORKSPACE'], spec))) {
    spec = path.join(process.env['GITHUB_WORKSPACE'], spec);
  // or ditto if its relative to cwd
  } else if (!path.isAbsolute(spec) && fs.existsSync(path.join(process.cwd(), spec))) {
    spec = path.join(process.cwd(), spec);
  }

  // if we have a file that exists on the filesystem then return that
  if (fs.existsSync(spec)) return spec;
  // also return any spec that include "preview"
  if (spec.includes('preview')) return spec;
  // also return any url specs
  if (isValidUrl(spec)) return spec;

  // at this point it should be safe to remove -slim
  if (spec.endsWith('-slim')) spec = spec.replace(/(-slim)(?!.*\1)/, '');

  // resolve and normalize s3 aliases
  if (s3Releases.includes(spec)) {
    // add the dmv if needed
    if (spec.split('-')[0] !== '3' && spec.split('-')[0] !== '4') spec = `${dmv}-${spec}`;
    // return
    return spec;
  }

  // then attempt to resolve special "convenience" aliases to actual versions
  if (gitHubReleases.includes(spec)) {
    const mv = spec.split('-').length === 1 ? dmv : spec.split('-')[0];
    const prerelease = spec.split('-').length === 1 ? spec.split('-')[0] === 'edge' : spec.split('-')[1] === 'edge';

    // filter based on release type and major version and validity etc
    releases = releases
      .filter(release => release.prerelease === prerelease)
      .filter(release => semver.valid(semver.clean(release.tag_name)) !== null)
      .filter(release => semver.satisfies(release.tag_name, `>=${mv} <${mv + 1}`,
        {loose: true, includePrerelease: true}));

    // theoretically our spec should be at the top so reset to that
    spec = releases[0].tag_name;

    // debug
    core.debug(`filtered to ${releases.length} releases`);
    core.debug(`reset version spec ${spec}`);
  }

  // eval and return
  return tc.evaluateVersions(releases.map(release => release.tag_name), spec);
};
