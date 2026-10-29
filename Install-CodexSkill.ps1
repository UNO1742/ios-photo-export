#requires -Version 5.1
[CmdletBinding()]
param([string]$SkillsDirectory)
$ErrorActionPreference='Stop'
if(!$SkillsDirectory){
    $root=if($env:CODEX_HOME){$env:CODEX_HOME}else{Join-Path $env:USERPROFILE '.codex'}
    $SkillsDirectory=Join-Path $root 'skills'
}
$target=Join-Path $SkillsDirectory 'ios-photo-export'
if(Test-Path -LiteralPath $target){throw ('Skill already exists; update it explicitly: '+$target)}
New-Item -ItemType Directory -Path $SkillsDirectory -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'skill\ios-photo-export') -Destination $target -Recurse
Join-Path $PSScriptRoot 'Export-iPhone.ps1' | Set-Content -LiteralPath (Join-Path $target 'program-path.txt') -Encoding UTF8
Write-Host ('Installed skill: '+$target)
