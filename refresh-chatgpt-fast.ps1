param(
  [string]$Destination = "E:\Users\Administrator\Apps\ChatGPT-Fast",
  [string]$NodeDir = "F:\Nodejs",
  [switch]$ForceClose,
  [switch]$SkipLaunch
)

$ErrorActionPreference = "Stop"
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Info([string]$Message) { Write-Host "[info] $Message" }
function Ok([string]$Message) { Write-Host "[ok] $Message" }

function Read-Utf8File {
  param([string]$Path)
  return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Write-Utf8File {
  param([string]$Path, [string]$Text)
  [System.IO.File]::WriteAllText($Path, $Text, $script:Utf8NoBom)
}

function Backup-File {
  param([string]$Path, [string]$Stamp)
  $backup = "$Path.bak-fast-$Stamp"
  Copy-Item -LiteralPath $Path -Destination $backup
  return $backup
}

function Patch-GeneralSettings {
  param([string]$AssetsDir, [string]$Stamp)

  $target = Get-ChildItem -LiteralPath $AssetsDir -Filter "general-settings*.js" |
    Where-Object { (Read-Utf8File -Path $_.FullName).Contains("settings.agent.speed.label") } |
    Select-Object -First 1

  if (-not $target) {
    throw "general-settings chunk containing Speed was not found"
  }

  Backup-File -Path $target.FullName -Stamp $Stamp | Out-Null
  $text = Read-Utf8File -Path $target.FullName
  $pattern = 'if\(![A-Za-z_$][A-Za-z0-9_$]*\|\|[A-Za-z_$][A-Za-z0-9_$]*\.availableOptions\.length<=1\)return null;'
  $regex = [regex]::new($pattern)

  if ($regex.IsMatch($text)) {
    $text = $regex.Replace($text, 'if(!1)return null;', 1)
    Write-Utf8File -Path $target.FullName -Text $text
    Ok "patched Speed visibility: $($target.Name)"
  } elseif ($text.Contains('if(!1)return null;')) {
    Ok "Speed visibility already patched: $($target.Name)"
  } else {
    throw "Speed visibility pattern changed in $($target.Name)"
  }
}

function Patch-ServiceTierPermission {
  param([string]$AssetsDir, [string]$Stamp)

  $target = Get-ChildItem -LiteralPath $AssetsDir -Filter "use-service-tier-settings*.js" |
    Where-Object { (Read-Utf8File -Path $_.FullName).Contains("featureRequirements?.fast_mode") } |
    Select-Object -First 1

  if (-not $target) {
    throw "use-service-tier-settings chunk was not found"
  }

  Backup-File -Path $target.FullName -Stamp $Stamp | Out-Null
  $text = Read-Utf8File -Path $target.FullName
  $pattern = '(?<lhs>[A-Za-z_$][A-Za-z0-9_$]*)=(?<auth>[A-Za-z_$][A-Za-z0-9_$]*)&&!(?<loading>[A-Za-z_$][A-Za-z0-9_$]*)&&(?<data>[A-Za-z_$][A-Za-z0-9_$]*)!=null&&\k<data>\?\.requirements\?\.featureRequirements\?\.fast_mode!==!1'
  $regex = [regex]::new($pattern)

  if ($regex.IsMatch($text)) {
    $text = $regex.Replace($text, '${lhs}=!${loading}', 1)
    Write-Utf8File -Path $target.FullName -Text $text
    Ok "patched service tier permission: $($target.Name)"
  } elseif ($text -match '[A-Za-z_$][A-Za-z0-9_$]*=![A-Za-z_$][A-Za-z0-9_$]*') {
    Ok "service tier permission appears patched: $($target.Name)"
  } else {
    throw "service tier permission pattern changed in $($target.Name)"
  }
}

function Patch-RequestGate {
  param([string]$AssetsDir, [string]$Stamp)

  $target = Get-ChildItem -LiteralPath $AssetsDir -Filter "read-service-tier-for-request*.js" |
    Where-Object { (Read-Utf8File -Path $_.FullName).Contains("fast_mode") } |
    Select-Object -First 1

  if (-not $target) {
    throw "read-service-tier-for-request chunk was not found"
  }

  Backup-File -Path $target.FullName -Stamp $Stamp | Out-Null
  $text = Read-Utf8File -Path $target.FullName
  $currentPattern = 'async function (?<fn>[A-Za-z_$][A-Za-z0-9_$]*)\(e,t\)\{let n=await [A-Za-z_$][A-Za-z0-9_$]*\(e,t\);if\(n!==`chatgpt`\)return!1;let r=await [A-Za-z_$][A-Za-z0-9_$]*\(t,\{priority:`critical`\}\);return .*?fast_mode!==!1\}'
  $legacyPattern = 'async function (?<fn>[A-Za-z_$][A-Za-z0-9_$]*)\(e,t\)\{let n=await [A-Za-z_$][A-Za-z0-9_$]*\(e,t\);return n===`chatgpt`\?.*?fast_mode!==!1:!1\}'
  $currentRegex = [regex]::new($currentPattern, [Text.RegularExpressions.RegexOptions]::Singleline)
  $legacyRegex = [regex]::new($legacyPattern, [Text.RegularExpressions.RegexOptions]::Singleline)

  if ($currentRegex.IsMatch($text)) {
    $text = $currentRegex.Replace($text, 'async function ${fn}(e,t){return!0}', 1)
  } elseif ($legacyRegex.IsMatch($text)) {
    $text = $legacyRegex.Replace($text, 'async function ${fn}(e,t){return!0}', 1)
  } elseif ($text -match 'async function [A-Za-z_$][A-Za-z0-9_$]*\(e,t\)\{return!0\}') {
    Ok "request gate already patched: $($target.Name)"
    return
  } else {
    throw "request gate pattern changed in $($target.Name)"
  }

  Write-Utf8File -Path $target.FullName -Text $text
  Ok "patched request gate: $($target.Name)"
}

function Patch-FixedFastOptions {
  param([string]$AssetsDir, [string]$Stamp)

  $target = Get-ChildItem -LiteralPath $AssetsDir -Filter "*.js" |
    Where-Object {
      $text = Read-Utf8File -Path $_.FullName
      $text.Contains("serviceTier.standard.label") -and
      $text.Contains("serviceTiers??[]") -and
      $text.Contains("fastDescription")
    } |
    Select-Object -First 1

  if (-not $target) {
    Info "fixed Fast option chunk not found; model catalog will supply tiers"
    return
  }

  $text = Read-Utf8File -Path $target.FullName
  $functionPattern = 'function (?<fn>[A-Za-z_$][A-Za-z0-9_$]*)\(e\)\{return\[(?<standard>[A-Za-z_$][A-Za-z0-9_$]*),\.\.\.\(e\?\.serviceTiers\?\?\[\]\)\.map\(e=>\(\{description:[^}]+value:e\.id\}\)\)\]\}'
  $functionRegex = [regex]::new($functionPattern)
  $match = $functionRegex.Match($text)

  if (-not $match.Success) {
    Info "fixed Fast option function pattern changed; skipped"
    return
  }

  $standard = [regex]::Escape($match.Groups['standard'].Value)
  $arrayPattern = '(?<fixed>[A-Za-z_$][A-Za-z0-9_$]*)=\[' + $standard + ',\{description:[A-Za-z_$][A-Za-z0-9_$]*\.fastDescription,iconKind:`fast`,label:[A-Za-z_$][A-Za-z0-9_$]*\.fastLabel,tier:null,value:[A-Za-z_$][A-Za-z0-9_$]*\}\]'
  $arrayMatch = [regex]::Match($text, $arrayPattern)

  if (-not $arrayMatch.Success) {
    Info "built-in Standard/Fast array not found; model catalog will supply tiers"
    return
  }

  Backup-File -Path $target.FullName -Stamp $Stamp | Out-Null
  $replacement = "function $($match.Groups['fn'].Value)(e){return $($arrayMatch.Groups['fixed'].Value)}"
  $text = $functionRegex.Replace($text, $replacement, 1)
  Write-Utf8File -Path $target.FullName -Text $text
  Ok "patched fixed Standard/Fast options: $($target.Name)"
}

function Patch-CodexConfig {
  param([string]$Stamp)

  $codexHome = Join-Path $env:USERPROFILE ".codex"
  $config = Join-Path $codexHome "config.toml"
  if (-not (Test-Path -LiteralPath $config)) {
    Info "config.toml not found; skipped"
    return
  }

  Backup-File -Path $config -Stamp $Stamp | Out-Null
  $text = Read-Utf8File -Path $config
  if ($text -match '(?m)^\s*service_tier\s*=') {
    $text = [regex]::Replace($text, '(?m)^\s*service_tier\s*=.*$', 'service_tier = "fast"', 1)
  } else {
    $section = [regex]::Match($text, '(?m)^\[')
    if ($section.Success) {
      $text = $text.Insert($section.Index, "service_tier = `"fast`"`r`n`r`n")
    } else {
      $text += "`r`nservice_tier = `"fast`"`r`n"
    }
  }
  Write-Utf8File -Path $config -Text $text
  Ok "set service_tier=fast in config.toml"

  $catalogMatch = [regex]::Match($text, '(?m)^\s*model_catalog_json\s*=\s*"([^"]+)"')
  if (-not $catalogMatch.Success) {
    Info "model_catalog_json is not configured; skipped catalog patch"
    return
  }

  $catalog = $catalogMatch.Groups[1].Value
  if (-not [IO.Path]::IsPathRooted($catalog)) {
    $catalog = Join-Path $codexHome $catalog
  }
  if (-not (Test-Path -LiteralPath $catalog)) {
    Info "model catalog not found: $catalog"
    return
  }

  Backup-File -Path $catalog -Stamp $Stamp | Out-Null
  $json = Read-Utf8File -Path $catalog | ConvertFrom-Json
  $changed = 0
  foreach ($model in @($json.models)) {
    $supportsFast = @($model.additional_speed_tiers) -contains "fast"
    if (-not $supportsFast -and $model.slug -ne "gpt-5.5") {
      continue
    }

    if ($null -eq $model.PSObject.Properties['additional_speed_tiers']) {
      $model | Add-Member -NotePropertyName additional_speed_tiers -NotePropertyValue @("fast")
    } elseif (-not (@($model.additional_speed_tiers) -contains "fast")) {
      $model.additional_speed_tiers = @($model.additional_speed_tiers) + "fast"
    }

    $tiers = @($model.service_tiers)
    if (-not ($tiers | Where-Object { $_.id -eq "priority" })) {
      $fastTier = [pscustomobject]@{
        id = "priority"
        name = "Fast"
        description = "1.5x speed, increased usage"
      }
      if ($null -eq $model.PSObject.Properties['service_tiers']) {
        $model | Add-Member -NotePropertyName service_tiers -NotePropertyValue @($fastTier)
      } else {
        $model.service_tiers = $tiers + $fastTier
      }
      $changed++
    }
  }

  $jsonText = $json | ConvertTo-Json -Depth 100
  Write-Utf8File -Path $catalog -Text $jsonText
  Ok "patched model catalog Fast tiers ($changed added)"
}

$package = Get-AppxPackage OpenAI.Codex | Sort-Object Version -Descending | Select-Object -First 1
if (-not $package) {
  throw "OpenAI.Codex Microsoft Store package is not installed"
}

$source = Join-Path $package.InstallLocation "app"
$sourceExe = Join-Path $source "ChatGPT.exe"
if (-not (Test-Path -LiteralPath $sourceExe)) {
  throw "ChatGPT.exe was not found in the Store package"
}

$running = Get-CimInstance Win32_Process | Where-Object {
  $_.ExecutablePath -like "$Destination\*"
}
if ($running) {
  if (-not $ForceClose) {
    $running | Select-Object ProcessId,Name,ExecutablePath | Format-Table -AutoSize
    throw "ChatGPT Fast is running. Close it or rerun with -ForceClose."
  }
  Info "closing ChatGPT Fast processes"
  $running | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
  Start-Sleep -Seconds 2
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$parent = Split-Path -Parent $Destination
$leaf = Split-Path -Leaf $Destination
$staging = Join-Path $parent "$leaf.staging-$stamp"
New-Item -ItemType Directory -Force -Path $parent | Out-Null
New-Item -ItemType Directory -Force -Path $staging | Out-Null

Info "copying Store package $($package.Version)"
robocopy $source $staging /E /COPY:DAT /DCOPY:DAT /R:3 /W:1 /NFL /NDL /NP
$copyCode = $LASTEXITCODE
if ($copyCode -ge 8) {
  throw "robocopy failed with exit code $copyCode"
}

$env:PATH = "$NodeDir;$env:PATH"
$npx = Join-Path $NodeDir "npx.cmd"
if (-not (Test-Path -LiteralPath $npx)) {
  throw "npx was not found: $npx"
}

$resources = Join-Path $staging "resources"
$asar = Join-Path $resources "app.asar"
$unpacked = Join-Path $resources "app"
Info "extracting app.asar"
& $npx --yes "@electron/asar" extract $asar $unpacked
if (-not (Test-Path -LiteralPath (Join-Path $unpacked "package.json"))) {
  throw "ASAR extraction failed"
}

$assets = Join-Path $unpacked "webview\assets"
Patch-GeneralSettings -AssetsDir $assets -Stamp $stamp
Patch-ServiceTierPermission -AssetsDir $assets -Stamp $stamp
Patch-RequestGate -AssetsDir $assets -Stamp $stamp
Patch-FixedFastOptions -AssetsDir $assets -Stamp $stamp
Patch-CodexConfig -Stamp $stamp

$asarBackup = Join-Path $resources "app.asar.fastmode.bak"
Rename-Item -LiteralPath $asar -NewName (Split-Path -Leaf $asarBackup)
Ok "backed up original app.asar"

$unpackPattern = "{node_modules/better-sqlite3,node_modules/node-pty,node_modules/@worklouder/device-kit-oai}"
Info "repacking patched app.asar"
& $npx --yes "@electron/asar" pack $unpacked $asar --unpack-dir $unpackPattern
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $asar)) {
  throw "ASAR repack failed"
}
if ((Get-Item -LiteralPath $asar).Length -lt 1MB) {
  throw "Repacked app.asar is unexpectedly small"
}
Ok "rebuilt patched app.asar"

if (Test-Path -LiteralPath $Destination) {
  $userData = Join-Path $Destination "UserData"
  if (Test-Path -LiteralPath $userData) {
    Move-Item -LiteralPath $userData -Destination (Join-Path $staging "UserData")
    Ok "preserved UserData"
  }
  $oldName = "$leaf.backup-$stamp"
  Rename-Item -LiteralPath $Destination -NewName $oldName
  Ok "backed up previous build to $(Join-Path $parent $oldName)"
}

Rename-Item -LiteralPath $staging -NewName $leaf

$exe = Join-Path $Destination "ChatGPT.exe"
$data = Join-Path $Destination "UserData"
New-Item -ItemType Directory -Force -Path $data | Out-Null
$shortcuts = @(
  (Join-Path ([Environment]::GetFolderPath("Desktop")) "ChatGPT Fast.lnk"),
  (Join-Path (Join-Path ([Environment]::GetFolderPath("StartMenu")) "Programs") "ChatGPT Fast.lnk")
)
$shell = New-Object -ComObject WScript.Shell
foreach ($shortcutPath in $shortcuts) {
  $shortcut = $shell.CreateShortcut($shortcutPath)
  $shortcut.TargetPath = $exe
  $shortcut.Arguments = "--user-data-dir=`"$data`""
  $shortcut.WorkingDirectory = $Destination
  $shortcut.IconLocation = "$exe,0"
  $shortcut.Description = "ChatGPT Fast patched portable build"
  $shortcut.Save()
}

Ok "ChatGPT Fast refreshed from Store package $($package.Version)"
if (-not $SkipLaunch) {
  Start-Process -FilePath $exe -ArgumentList @("--user-data-dir=$data")
  Ok "launched ChatGPT Fast"
}
