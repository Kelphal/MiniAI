param([Parameter(Mandatory=$true)][ValidateSet("Enable","Restore")][string]$Action,[Parameter(Mandatory=$true)][string]$StateFile)
$ErrorActionPreference = "Stop"
$protected = @("System","Idle","csrss","wininit","winlogon","services","lsass","svchost","dwm","explorer","audiodg","spoolsv","MsMpEng","SecurityHealthService","MiniAI","llama-server","python")
$eligible = @("OneDrive","SearchIndexer","Widgets","PhoneExperienceHost","YourPhone","Teams","Discord","Spotify","EpicGamesLauncher","AdobeCollabSync","GoogleDriveFS","Dropbox","Steam","Battle.net","EADesktop")
function Get-StartTicks($p) { try { return $p.StartTime.ToUniversalTime().Ticks } catch { return 0 } }
if ($Action -eq "Enable") {
  $snapshot = @()
  foreach ($p in Get-Process -ErrorAction SilentlyContinue) {
    if ($protected -contains $p.ProcessName -or $eligible -notcontains $p.ProcessName) { continue }
    try {
      $old = $p.PriorityClass.ToString()
      if ($old -notin @("Normal","AboveNormal")) { continue }
      $snapshot += [pscustomobject]@{ Id=$p.Id; Name=$p.ProcessName; StartTicks=(Get-StartTicks $p); Priority=$old }
      $p.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::BelowNormal
    } catch { }
  }
  $dir = Split-Path -Parent $StateFile
  if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $snapshot | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $StateFile -Encoding UTF8
  Write-Output ("Temporary safe optimization applied to {0} eligible background process(es)." -f $snapshot.Count)
} else {
  if (-not (Test-Path -LiteralPath $StateFile)) { Write-Output "No optimizer snapshot exists; nothing to restore."; exit 0 }
  $snapshot = Get-Content -LiteralPath $StateFile -Raw | ConvertFrom-Json
  foreach ($item in @($snapshot)) {
    try {
      $p = Get-Process -Id ([int]$item.Id) -ErrorAction Stop
      if ($p.ProcessName -ne [string]$item.Name) { continue }
      $ticks = Get-StartTicks $p
      if ($item.StartTicks -and $ticks -and $ticks -ne [int64]$item.StartTicks) { continue }
      $p.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::$($item.Priority)
    } catch { }
  }
  Remove-Item -LiteralPath $StateFile -Force -ErrorAction SilentlyContinue
  Write-Output "Original process priorities restored where the same processes were still running."
}
