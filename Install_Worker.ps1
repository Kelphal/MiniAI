#requires -Version 5.1
param(
 [Parameter(Mandatory=$true)][string]$Requested,
 [Parameter(Mandatory=$true)][string]$ScriptRoot,
 [Parameter(Mandatory=$true)][string]$StateFile,
 [Parameter(Mandatory=$true)][string]$LogFile
)
$ErrorActionPreference='Stop'
try { New-Item -ItemType File -Force -Path $LogFile | Out-Null } catch { }
function Log([string]$Message){
 $line='['+(Get-Date -Format 'HH:mm:ss')+'] '+$Message
 try { Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8 } catch { }
 Write-Output $line
}
function Write-State([int]$Percent,[string]$Message,[string]$Status='RUNNING',[string]$Result=''){
 $tmp="$StateFile.tmp"; $text="$Percent`r`n$Message`r`n$Status"; if($Result){$text+="`r`n$Result"}
 Set-Content -LiteralPath $tmp -Value $text -Encoding UTF8; Remove-Item -LiteralPath $StateFile -Force -ErrorAction SilentlyContinue; Move-Item -LiteralPath $tmp -Destination $StateFile -Force
 Log "$Percent% - $Message"
}
function Download-File([string]$Url,[string]$Out,[string]$Label,[int]$Base,[int]$Span){
 Log "Connecting: $Url"
 $part="$Out.part"; Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue
 for($attempt=1;$attempt -le 10;$attempt++){
  $request=$null;$response=$null;$input=$null;$output=$null
  try{
   Log "${Label} download attempt $attempt of 10 started."
   $request=[Net.HttpWebRequest]::Create([Uri]$Url); $request.UserAgent='MiniAI-Installer/4.2'; $request.AllowAutoRedirect=$true; $request.MaximumAutomaticRedirections=10; $request.Timeout=30000; $request.ReadWriteTimeout=30000
   $response=$request.GetResponse(); $total=[int64]$response.ContentLength
   $input=$response.GetResponseStream(); $output=[IO.File]::Open($part,[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::None)
   $buffer=New-Object byte[] (65536); [int64]$received=0; $last=Get-Date
   while(($read=$input.Read($buffer,0,$buffer.Length)) -gt 0){
    $output.Write($buffer,0,$read); $received += $read
    $now=Get-Date
    if((($now-$last).TotalMilliseconds -ge 500) -or ($total -gt 0 -and $received -ge $total)){
     if($total -gt 0){$raw=[int][math]::Min(100,[math]::Floor(($received*100.0)/$total));$pct=$Base+[int][math]::Floor(($raw*$Span)/100);$msg="$Label $raw% - $([math]::Round($received/1MB,1)) MB / $([math]::Round($total/1MB,1)) MB"}else{$pct=$Base;$msg="$Label - $([math]::Round($received/1MB,1)) MB received"}
     Write-State $pct $msg; $last=$now
    }
   }
   $output.Flush();$output.Dispose();$output=$null;$input.Dispose();$input=$null;$response.Dispose();$response=$null
   $size=(Get-Item -LiteralPath $part).Length
   if($size -le 0){throw "$Label download produced a zero-byte file."}
   if($total -gt 0 -and $size -ne $total){throw "$Label download ended early: received $size bytes but server reported $total bytes."}
   Remove-Item -LiteralPath $Out -Force -ErrorAction SilentlyContinue; Move-Item -LiteralPath $part -Destination $Out -Force
   Write-State ($Base+$Span) "$Label download complete - $([math]::Round($size/1MB,2)) MB."; return
  }catch{
   try{$output.Dispose()}catch{};try{$input.Dispose()}catch{};try{$response.Dispose()}catch{}
   Log "${Label} attempt $attempt failed: $($_.Exception.Message)"
   if($attempt -ge 10){throw "${Label} download failed after 10 attempts. Last error: $($_.Exception.Message)"}
   Start-Sleep -Seconds 3; Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue
  }
 }
}
function Find-ExistingModel([string]$PreferredRoot,[string]$FileName){
 $candidates=New-Object System.Collections.Generic.List[string]
 $local=Join-Path (Join-Path $env:LOCALAPPDATA 'MiniAI\Models') $FileName
 [void]$candidates.Add($local)
 if($PreferredRoot){[void]$candidates.Add((Join-Path (Join-Path $PreferredRoot 'Models') $FileName))}
 foreach($drive in Get-PSDrive -PSProvider FileSystem){
  $r=$drive.Root
  [void]$candidates.Add((Join-Path $r ('MiniAI\Models\'+$FileName)))
  [void]$candidates.Add((Join-Path $r ('Users\'+$env:USERNAME+'\Downloads\MiniAI\Models\'+$FileName)))
  [void]$candidates.Add((Join-Path $r ('Users\'+$env:USERNAME+'\Downloads\MiniAI_v4.1_Debug_Package\Models\'+$FileName)))
 }
 foreach($p in $candidates | Select-Object -Unique){
  try{ if(Test-Path -LiteralPath $p){$i=Get-Item -LiteralPath $p; if($i.Length -ge 2GB){return $i.FullName}} }catch{}
 }
 return $null
}
try{
 Log 'MiniAI installer worker v4.11.0 started - Made by Kelphal - Gio A.'
 $Requested=[Environment]::ExpandEnvironmentVariables($Requested)
 if(-not [IO.Path]::IsPathRooted($Requested)){throw "The installation path must be a full Windows path: $Requested"}
 $driveRoot=[IO.Path]::GetPathRoot($Requested); $driveLetter=$driveRoot.Substring(0,1).ToUpperInvariant()
 $root=if($driveLetter -eq 'C'){Join-Path $env:LOCALAPPDATA 'MiniAI'}else{$Requested}
 Log "Requested path: [$Requested]"; Log "Resolved install root: [$root]"
 New-Item -ItemType Directory -Force -Path $root | Out-Null
 foreach($d in 'Models','Runtime','Runtime\Flux','Knowledge','Conversations','Training','Training\Manual Learnings','Training\Auto Learnings','Plugins','Logs','Math','Files'){New-Item -ItemType Directory -Force -Path (Join-Path $root $d)|Out-Null}
 $psDrive=Get-PSDrive -Name $driveLetter -ErrorAction Stop; if($psDrive.Free -lt 7GB){throw 'The selected drive needs at least 7 GB free for Chat AI and Image AI.'}
 foreach($f in 'MiniAI.exe','config.json','README.txt','SAFETY_CORE.md','STABILITY.md','FILE_WORKSPACE.md','Plugin_Developer_Guide.md','Runtime\Flux\flux_worker.py'){$src=Join-Path $ScriptRoot $f;if(-not(Test-Path -LiteralPath $src)){throw "Installer file is missing: $f"};Copy-Item -LiteralPath $src -Destination (Join-Path $root $f)-Force}
 Write-State 5 'Base files copied.'
 $runtimeExe=Join-Path $root 'Runtime\llama-server.exe'
 if(Test-Path -LiteralPath $runtimeExe){Log "Existing llama.cpp runtime found at [$runtimeExe]. Skipping runtime download.";Write-State 22 'Existing llama.cpp runtime found.'}
 else{
  $llamaZip=Join-Path $env:TEMP 'MiniAI-llama.zip';$llamaUrl='https://github.com/ggml-org/llama.cpp/releases/download/b11430/llama-b11430-bin-win-cpu-x64.zip';Write-State 6 'Downloading llama.cpp runtime...';Download-File $llamaUrl $llamaZip 'Runtime:' 6 16
  $tmp=Join-Path $env:TEMP 'MiniAI-llama';Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue;Expand-Archive $llamaZip $tmp -Force
  $exe=Get-ChildItem $tmp -Recurse -Filter 'llama-server.exe'|Select-Object -First 1;if(!$exe){throw 'llama-server.exe was not found in the downloaded runtime.'};$runtimeRoot=$exe.Directory.FullName
  Get-ChildItem -LiteralPath $runtimeRoot -File -Recurse | ForEach-Object {$relative=$_.FullName.Substring($runtimeRoot.Length).TrimStart('\');$dest=Join-Path (Join-Path $root 'Runtime') $relative;New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest)|Out-Null;Copy-Item -LiteralPath $_.FullName -Destination $dest -Force}
  if(-not(Test-Path -LiteralPath $runtimeExe)){throw 'Runtime installation completed but llama-server.exe is missing.'};Write-State 22 'Runtime installed.'
 }
 $fileName='Qwen3-4B-Instruct-2507-Q4_K_M.gguf';$modelUrl='https://huggingface.co/DhruvalLabs/Qwen3-4B-Instruct-2507-GGUF/resolve/main/Qwen3-4B-Instruct-2507-Q4_K_M.gguf?download=true'
 $target=Join-Path $root ('Models\'+$fileName);$existing=Find-ExistingModel $root $fileName
 if($existing){
  Log "Existing model found at [$existing]"
  $existingFull=(Resolve-Path -LiteralPath $existing).Path
  $targetFull=[IO.Path]::GetFullPath($target)
  if(-not [string]::Equals($existingFull,$targetFull,[StringComparison]::OrdinalIgnoreCase)){
    $free=(Get-PSDrive -Name $driveLetter -ErrorAction Stop).Free
    $size=(Get-Item -LiteralPath $existingFull).Length
    if($free -lt ($size + 512MB)){throw 'The selected drive does not have enough free space to place the AI model in the MiniAI installation.'}
    Write-State 78 'Placing existing Chat AI model in the selected MiniAI folder...'
    Copy-Item -LiteralPath $existingFull -Destination $target -Force
    Log "Copied existing model into installation root: [$target]"
  }
  $modelPath=$target
  Remove-Item -LiteralPath ($target+'.part') -Force -ErrorAction SilentlyContinue
  Write-State 78 'Chat AI model ready in the MiniAI installation.'
}
else{
  Write-State 30 'Downloading Chat AI model...'
  Download-File $modelUrl $target 'Chat AI model:' 30 48
  $modelPath=$target
}
# FLUX.2-dev model weights and Python dependencies remain optional and are not downloaded by the base installer.
# If a worker is present in the package, it is copied into Runtime\Flux; otherwise the UI reports it as missing.
Write-State 99 'Writing MiniAI configuration...'
$cfg=[ordered]@{
  install_dir=$root
  model_path='Models\Qwen3-4B-Instruct-2507-Q4_K_M.gguf'
  server_port=8080
  ui_port=32123
  max_tokens=384
  temperature=0.7
  context_size=2048
  flux_model_path='Models\Flux2'
  auto_learn=$true
  full_auto=$false
}
$cfg | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $root 'config.json')
$startCmdPath=Join-Path $root 'Start_MiniAI.cmd'
$exePath=Join-Path $root 'MiniAI.exe'
$startLines=@('@echo off','setlocal','cd /d "%~dp0"','if not exist "%~dp0MiniAI.exe" exit /b 1','start "MiniAI" /b "%~dp0MiniAI.exe"','exit /b 0'); Set-Content -LiteralPath $startCmdPath -Value $startLines -Encoding ASCII
# The user-facing launcher is a CMD file so Windows reputation/blocking is less likely to stop MiniAI.
# Shortcuts remain .lnk files and are configured with the Run-as-administrator shell-link flag.
# Create an ordinary .lnk with WScript.Shell, then set the Windows
# SLDF_RUNAS_USER bit directly in the Shell Link header. This avoids
# IShellLinkDataList COM interface compatibility problems on some Windows builds.
$shell=New-Object -ComObject WScript.Shell
function Set-ShortcutRunAs([string]$ShortcutPath) {
  $sc=$shell.CreateShortcut($ShortcutPath)
  $sc.TargetPath=$env:ComSpec
  $sc.Arguments='/d /c ""'+$startCmdPath+'""'
  $sc.WorkingDirectory=$root
  $sc.Description='MiniAI - Run as administrator'
  $sc.IconLocation='shell32.dll,71'
  $sc.Save()
  $bytes=[IO.File]::ReadAllBytes($ShortcutPath)
  if($bytes.Length -lt 24){throw "Shortcut was created but is too small to modify: $ShortcutPath"}
  # Shell Link Header LinkFlags are a 32-bit little-endian value at offset 0x14.
  $flags=[BitConverter]::ToUInt32($bytes,20)
  $flags = $flags -bor 0x00002000
  $fb=[BitConverter]::GetBytes([uint32]$flags)
  [Array]::Copy($fb,0,$bytes,20,4)
  [IO.File]::WriteAllBytes($ShortcutPath,$bytes)
}
$programsDir=[Environment]::GetFolderPath('Programs')
$menuDir=Join-Path $programsDir 'MiniAI'
New-Item -ItemType Directory -Path $menuDir -Force|Out-Null
$startLink=Join-Path $menuDir 'MiniAI.lnk'
Set-ShortcutRunAs $startLink
$desktop=[Environment]::GetFolderPath('Desktop')
$desktopLink=$null
if($desktop){
  $desktopLink=Join-Path $desktop 'MiniAI.lnk'
  Set-ShortcutRunAs $desktopLink
}
# Verify the shortcuts invoke cmd.exe with the MiniAI launcher as their command.
$check=$shell.CreateShortcut($startLink)
if(-not [string]::Equals([IO.Path]::GetFullPath($check.TargetPath),[IO.Path]::GetFullPath($env:ComSpec),[StringComparison]::OrdinalIgnoreCase) -or $check.Arguments -notlike ('*'+$startCmdPath+'*')){throw 'Start Menu shortcut verification failed.'}
if($desktop -and $desktopLink){$check2=$shell.CreateShortcut($desktopLink); if(-not [string]::Equals([IO.Path]::GetFullPath($check2.TargetPath),[IO.Path]::GetFullPath($env:ComSpec),[StringComparison]::OrdinalIgnoreCase) -or $check2.Arguments -notlike ('*'+$startCmdPath+'*')){throw 'Desktop shortcut verification failed.'}}
Log "Install directory saved: [$root]"
Log "Runtime path: [$(Join-Path $root 'Runtime\llama-server.exe')]"
Log "Model path: [$modelPath]"
Log "Start Menu shortcut: [$startLink]"
Log 'Shortcuts created and verified.'
Write-State 100 'Installation complete.' 'DONE' $root
}catch{$detail=$_.Exception.ToString();Log ('ERROR: '+$detail);try{Write-State 0 'Installation failed.' 'ERROR' $detail}catch{};exit 1}
