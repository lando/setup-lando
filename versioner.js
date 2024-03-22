'use strict';

const fs = require('fs');
const path = require('path');

// if script version is not set then do nothing
if (!process.env.SCRIPT_VERSION) {
  console.log('SCRIPT_VERSION not set, doing nothing');
  process.exit(0);
}

// version
const DIST = path.resolve(__dirname, 'dist');
const VERSION = process.env.SCRIPT_VERSION;

// GHA SCRIPT
const GHA_REPLACER = `const SCRIPT_VERSION = '${VERSION}';`;
const ghaScriptPath = path.join(DIST, 'index.js');
const oghaScript = fs.readFileSync(ghaScriptPath, {encoding: 'utf8'});
const vghaScript = oghaScript.replace('let SCRIPT_VERSION;', GHA_REPLACER);
fs.writeFileSync(ghaScriptPath, vghaScript, {encoding: 'utf8'});

// GHA VALIDATE
const ughaScript = fs.readFileSync(ghaScriptPath, {encoding: 'utf8'});
if (!ughaScript.includes(GHA_REPLACER)) {
  throw Error(`${ghaScriptPath} does not seem to have the correct SCRIPT_VERSION=${VERSION}`);
} else {
  console.log(`updated ${ghaScriptPath} to SCRIPT_VERSION=${VERSION}`);
}

// POSIX SCRIPT
const POSIX_PREPENDER = `SCRIPT_VERSION="${VERSION}"`;
const psxScriptPath = path.join(DIST, 'setup-lando.sh');
const opsxScript = fs.readFileSync(psxScriptPath, {encoding: 'utf8'});
const vpsxScript = `${POSIX_PREPENDER}\n${opsxScript}`;
fs.writeFileSync(psxScriptPath, vpsxScript, {encoding: 'utf8'});

// POSIX VALIDATE
const upsxScript = fs.readFileSync(psxScriptPath, {encoding: 'utf8'});
if (!upsxScript.includes(POSIX_PREPENDER)) {
  throw Error(`${psxScriptPath} does not seem to have the correct SCRIPT_VERSION=${VERSION}`);
} else {
  console.log(`updated ${psxScriptPath} to SCRIPT_VERSION=${VERSION}`);
}

// @TODO: windows scripts
