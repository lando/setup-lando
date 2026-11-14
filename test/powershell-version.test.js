'use strict';

const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const path = require('node:path');
const {test} = require('node:test');

const hasPowerShell = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-Command', 'exit 0']).status === 0;
for (const script of ['setup-lando.ps1', 'dist/setup-lando.ps1']) {
  test(`${script}: parse and exercise Windows version decisions without installer side effects`,
    {skip: !hasPowerShell && 'PowerShell unavailable'}, () => {
      // Only load selected function AST nodes. Never dot-source the installer itself.
      const result = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-Command', `
$ErrorActionPreference = 'Stop'
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($env:TEST_INSTALLER, [ref]$tokens, [ref]$errors)
if ($errors.Count -gt 0) { throw ($errors | Out-String) }
$names = @(
  'Confirm-CanBeSlim', 'Confirm-CanRunSetup', 'Get-SemanticVersionInfo', 'Resolve-VersionUrl', 'Resolve-VersionPath'
)
$ast.FindAll({ param($node)
  $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -in $names
}, $true) | ForEach-Object { Invoke-Expression $_.Extent.Text }
function Resolve-VersionAlias { param($Version) return $Version }
foreach ($version in @('v3.21.0-beta.10', 'v3.23.11', 'v3.24.0-beta.1', 'v3.24.0', 'v3.26.9', 'v4.0.0-alpha.1')) {
  $expectedSetup = $version.StartsWith('v3.')
  $expectedSlim = $version.StartsWith('v3.21.') -or $version.StartsWith('v3.23.')
  if ((Confirm-CanRunSetup -Version $version) -ne $expectedSetup) { throw "setup: $version" }
  if ((Confirm-CanBeSlim -Version $version) -ne $expectedSlim) { throw "slim: $version" }
  $url = Resolve-VersionUrl -Version $version -Arch x64
  if ($url.EndsWith('-slim.exe') -ne $expectedSlim) { throw "URL: $url" }
  $url = Resolve-VersionUrl -Version $version -Arch x64 -Fat
  if ($url.EndsWith('-slim.exe')) { throw "fat URL: $url" }
}
if (-not (Confirm-CanRunSetup -Version '3-dev')) { throw '3-dev setup' }
if (Confirm-CanRunSetup -Version '4-dev') { throw '4-dev setup' }
$setup = $ast.EndBlock.Statements | Where-Object {
  $_.Extent.Text.StartsWith('if ((Confirm-CanRunSetup') -and $_.Extent.Text.Contains('Invoke-LandoSetup')
}
if (@($setup).Count -ne 1) { throw 'expected one final setup invocation' }
function Invoke-LandoSetup {
  param([Parameter(Mandatory)][string]$LandoBin)
  $script:called = $LandoBin
}
$SYMLINKER = '/task/mocked-lando'
foreach ($Version in @('v3.23.11', 'v3.26.9', 'v4.0.0-alpha.1')) {
  foreach ($NoSetup in @($true, $false)) {
    $script:called = $null
    Invoke-Expression $setup.Extent.Text
    $expected = $Version.StartsWith('v3.') -and -not $NoSetup
    if (($null -ne $script:called) -ne $expected) { throw "setup invocation: $Version / $NoSetup" }
    if ($expected -and $script:called -ne $SYMLINKER) { throw 'wrong Lando binary' }
  }
}
Write-Output 'all Windows version decisions passed' 
`], {encoding: 'utf8', env: {...process.env, TEST_INSTALLER: path.resolve(__dirname, '..', script)}});
      assert.equal(result.status, 0, result.stderr || result.stdout);
      assert.match(result.stdout, /all Windows version decisions passed/);
    });
}
