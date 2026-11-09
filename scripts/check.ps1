# Confere o código: formatação (StyLua), boas práticas (Selene) e tipos --!strict (luau-lsp).
# Uso: powershell -ExecutionPolicy Bypass -File scripts/check.ps1
#      powershell -ExecutionPolicy Bypass -File scripts/check.ps1 -Fix   (corrige a formatação)

param([switch]$Fix)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)
$failed = $false

# Arquivo de tipos do Roblox para o luau-lsp (baixado uma vez)
$defs = "tools/globalTypes.d.luau"
if (-not (Test-Path $defs)) {
	New-Item -ItemType Directory -Force tools | Out-Null
	Write-Host "Baixando tipos do Roblox para o luau-lsp..."
	Invoke-WebRequest -UseBasicParsing -OutFile $defs "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau"
}

Write-Host "`n== StyLua (formatação) =="
if ($Fix) { stylua src } else { stylua --check src }
if ($LASTEXITCODE -ne 0) { $failed = $true }

Write-Host "`n== Selene (boas práticas) =="
selene src
if ($LASTEXITCODE -ne 0) { $failed = $true }

Write-Host "`n== luau-lsp (tipos --!strict), um place por vez =="
foreach ($place in @("lobby", "tutorial", "match")) {
	Write-Host "-- $place"
	rojo sourcemap "$place.project.json" --output sourcemap.json
	luau-lsp analyze --sourcemap=sourcemap.json --definitions=$defs --base-luaurc=.luaurc `
		src/shared src/common "src/$place"
	if ($LASTEXITCODE -ne 0) { $failed = $true }
}

if ($failed) {
	Write-Host "`nHá problemas acima." -ForegroundColor Yellow
	exit 1
}
Write-Host "`nTudo certo." -ForegroundColor Green
