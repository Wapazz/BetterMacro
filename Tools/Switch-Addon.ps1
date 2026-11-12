<#
.SYNOPSIS
    Bascule l'addon BetterMacro du jeu entre la version prod (installée) et la version dev (ce dépôt).

.DESCRIPTION
    - dev    : met de côté le dossier prod installé, puis crée une jonction AddOns\BetterMacro -> dépôt.
    - prod   : supprime la jonction (le dépôt n'est pas touché) et remet le dossier prod en place.
    - toggle : passe à l'autre mode (par défaut).
    - status : affiche le mode actuel sans rien changer.

    La version prod est rangée dans Interface\AddOns.prod-backup\BetterMacro, hors du dossier
    AddOns, pour que le jeu ne la charge pas en double.

.EXAMPLE
    .\Tools\Switch-Addon.ps1          # bascule
    .\Tools\Switch-Addon.ps1 dev
    .\Tools\Switch-Addon.ps1 prod
    .\Tools\Switch-Addon.ps1 status
#>
param(
    [ValidateSet('toggle', 'dev', 'prod', 'status')]
    [string]$Mode = 'toggle',

    [string]$AddOnsPath = 'D:\World of Warcraft\_forever_\Interface\AddOns'
)

$ErrorActionPreference = 'Stop'

$AddonName = 'BetterMacro'
$DevPath   = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$LivePath  = Join-Path $AddOnsPath $AddonName
$StashPath = Join-Path (Join-Path (Split-Path $AddOnsPath -Parent) 'AddOns.prod-backup') $AddonName

function Get-State {
    if (-not (Test-Path -LiteralPath $LivePath)) { return 'absent' }
    $item = Get-Item -LiteralPath $LivePath -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { return 'dev' }
    return 'prod'
}

function Get-TocVersion([string]$dir) {
    $toc = Join-Path $dir "$AddonName.toc"
    if (-not (Test-Path -LiteralPath $toc)) { return '?' }
    $line = Get-Content -LiteralPath $toc | Where-Object { $_ -match '^##\s*Version:' } | Select-Object -First 1
    if ($line) { return ($line -replace '^##\s*Version:\s*', '').Trim() }
    return '?'
}

function Show-Status {
    $state = Get-State
    switch ($state) {
        'dev'    { Write-Host "Mode actuel : DEV  -> $((Get-Item -LiteralPath $LivePath -Force).Target)" -ForegroundColor Cyan }
        'prod'   { Write-Host "Mode actuel : PROD (version $(Get-TocVersion $LivePath))" -ForegroundColor Green }
        'absent' { Write-Host "Mode actuel : aucun BetterMacro dans $AddOnsPath" -ForegroundColor Yellow }
    }
    if (Test-Path -LiteralPath $StashPath) {
        Write-Host "Prod sauvegardée : $StashPath (version $(Get-TocVersion $StashPath))"
    }
}

function Switch-ToDev {
    $state = Get-State
    if ($state -eq 'dev') { Write-Host 'Déjà en mode DEV.'; return }

    if ($state -eq 'prod') {
        if (Test-Path -LiteralPath $StashPath) {
            throw "Une sauvegarde prod existe déjà ($StashPath). Supprime-la ou renomme-la avant de continuer, pour ne pas l'écraser."
        }
        New-Item -ItemType Directory -Force -Path (Split-Path $StashPath -Parent) | Out-Null
        Move-Item -LiteralPath $LivePath -Destination $StashPath
        Write-Host "Prod mise de côté -> $StashPath"
    }

    New-Item -ItemType Junction -Path $LivePath -Target $DevPath | Out-Null
    Write-Host "Mode DEV activé : $LivePath -> $DevPath" -ForegroundColor Cyan
}

function Switch-ToProd {
    $state = Get-State
    if ($state -eq 'prod') { Write-Host 'Déjà en mode PROD.'; return }

    if ($state -eq 'dev') {
        # Suppression non récursive : n'enlève que la jonction, jamais les fichiers du dépôt.
        [IO.Directory]::Delete($LivePath, $false)
        Write-Host 'Jonction DEV supprimée.'
    }

    if (Test-Path -LiteralPath $StashPath) {
        Move-Item -LiteralPath $StashPath -Destination $LivePath
        Write-Host "Mode PROD activé (version $(Get-TocVersion $LivePath))." -ForegroundColor Green
    } else {
        Write-Warning "Aucune sauvegarde prod trouvée dans $StashPath. Réinstalle BetterMacro (CurseForge, etc.) pour avoir la version prod."
    }
}

switch ($Mode) {
    'status' { Show-Status; return }
    'dev'    { Switch-ToDev }
    'prod'   { Switch-ToProd }
    'toggle' { if ((Get-State) -eq 'dev') { Switch-ToProd } else { Switch-ToDev } }
}

if (Get-Process -Name 'Wow*' -ErrorAction SilentlyContinue) {
    Write-Host 'Le jeu est lancé : fais /reload pour charger la nouvelle version.' -ForegroundColor Yellow
}
