#requires -Version 5.1
# MiniAI installer UI. Worker runs as a separate PowerShell process.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$ScriptRoot = $PSScriptRoot

$form = New-Object Windows.Forms.Form
$form.Text = 'MiniAI - Install - Kelphal - Gio A.'
$form.Size = New-Object Drawing.Size(720,455)
$form.StartPosition = 'CenterScreen'
$form.BackColor = [Drawing.Color]::FromArgb(14,17,21)
$form.ForeColor = [Drawing.Color]::White
$form.Font = New-Object Drawing.Font('Segoe UI',10)
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false

$title = New-Object Windows.Forms.Label
$title.Text = 'MiniAI'
$title.Font = New-Object Drawing.Font('Segoe UI',24,[Drawing.FontStyle]::Bold)
$title.Location = '34,28'; $title.AutoSize = $true; $form.Controls.Add($title)
$sub = New-Object Windows.Forms.Label
$sub.Text = 'Local 4B AI - Made by Kelphal - Gio A.'
$sub.ForeColor = [Drawing.Color]::LightGray
$sub.Location = '38,75'; $sub.AutoSize = $true; $form.Controls.Add($sub)
$lab = New-Object Windows.Forms.Label
$lab.Text = 'Installation folder'
$lab.Location = '38,125'; $lab.AutoSize = $true; $form.Controls.Add($lab)
$box = New-Object Windows.Forms.TextBox
$box.Text = 'D:\MiniAI'; $box.Location = '38,153'; $box.Size = '500,30'
$box.BackColor = [Drawing.Color]::FromArgb(27,31,37); $box.ForeColor = [Drawing.Color]::White
$form.Controls.Add($box)
$browse = New-Object Windows.Forms.Button
$browse.Text = 'Browse...'; $browse.Location = '548,152'; $browse.Size = '105,31'; $form.Controls.Add($browse)
$info = New-Object Windows.Forms.Label
$info.Text = 'C: installs to LocalAppData\MiniAI. Another drive keeps MiniAI data on that selected drive.'
$info.Location = '38,205'; $info.Size = '610,55'; $info.ForeColor = [Drawing.Color]::Gainsboro
$form.Controls.Add($info)
$progress = New-Object Windows.Forms.ProgressBar
$progress.Location = '38,290'; $progress.Size = '615,20'; $progress.Style = 'Continuous'; $form.Controls.Add($progress)
$status = New-Object Windows.Forms.Label
$status.Text = 'Ready'; $status.Location = '38,320'; $status.Size = '615,24'; $status.ForeColor = [Drawing.Color]::Silver
$form.Controls.Add($status)
$details = New-Object Windows.Forms.Button
$details.Text = 'More Details'; $details.Location = '38,365'; $details.Size = '115,35'; $form.Controls.Add($details)
$install = New-Object Windows.Forms.Button
$install.Text = 'Install MiniAI'; $install.Location = '535,365'; $install.Size = '118,35'; $form.Controls.Add($install)

$session = [guid]::NewGuid().ToString('N')
$stateFile = Join-Path $env:TEMP ('MiniAIInstaller_' + $session + '.state')
$logFile = Join-Path $env:TEMP ('MiniAIInstaller_' + $session + '.log')
$stdoutFile = Join-Path $env:TEMP ('MiniAIInstaller_' + $session + '.stdout')
$stderrFile = Join-Path $env:TEMP ('MiniAIInstaller_' + $session + '.stderr')
$workerCmd = Join-Path $env:TEMP ('MiniAIInstaller_' + $session + '.cmd')
$workerProcess = $null
$timer = New-Object Windows.Forms.Timer
$timer.Interval = 250
$detailForm = $null
$detailBox = $null

function Update-Details {
    if(-not $detailBox -or $detailBox.IsDisposed){ return }
    try {
        $parts = New-Object System.Collections.Generic.List[string]
        if(Test-Path -LiteralPath $logFile){ [void]$parts.Add((Get-Content -LiteralPath $logFile -Raw -ErrorAction Stop)) }
        elseif(Test-Path -LiteralPath $stdoutFile){ [void]$parts.Add("[STDOUT]`r`n" + (Get-Content -LiteralPath $stdoutFile -Raw -ErrorAction SilentlyContinue)) }
        else { [void]$parts.Add('[DEBUG] Worker log has not been created yet.') }
        if(Test-Path -LiteralPath $stderrFile){ [void]$parts.Add("`r`n[STDERR]`r`n" + (Get-Content -LiteralPath $stderrFile -Raw -ErrorAction SilentlyContinue)) }
        [void]$parts.Add("`r`n[DEBUG] State: $stateFile")
        [void]$parts.Add("[DEBUG] Log: $logFile")
        [void]$parts.Add("[DEBUG] Worker stdout: $stdoutFile")
        [void]$parts.Add("[DEBUG] Worker stderr: $stderrFile")
        if($workerProcess){
            try { [void]$parts.Add("[DEBUG] Worker PID: $($workerProcess.Id)  Exited: $($workerProcess.HasExited)") } catch { }
        }
        $detailBox.Text = ($parts -join "`r`n")
        $detailBox.SelectionStart = $detailBox.TextLength
        $detailBox.ScrollToCaret()
    } catch {
        try { $detailBox.Text = "[DEBUG] Error reading installer diagnostics:`r`n$($_.Exception.ToString())" } catch { }
    }
}

function Show-Details {
    if($detailForm -and -not $detailForm.IsDisposed){ $detailForm.Activate(); Update-Details; return }
    $detailForm = New-Object Windows.Forms.Form
    $detailForm.Text = 'MiniAI Installer - More Details'
    $detailForm.Size = New-Object Drawing.Size(820,520)
    $detailForm.StartPosition = 'CenterParent'
    $detailForm.BackColor = [Drawing.Color]::FromArgb(10,12,15)
    $detailForm.ForeColor = [Drawing.Color]::White
    $detailForm.Font = New-Object Drawing.Font('Consolas',9)
    $detailBox = New-Object Windows.Forms.TextBox
    $detailBox.Multiline = $true; $detailBox.ReadOnly = $true; $detailBox.ScrollBars = 'Both'; $detailBox.WordWrap = $false
    $detailBox.Dock = 'Fill'; $detailBox.BackColor = [Drawing.Color]::FromArgb(8,10,12); $detailBox.ForeColor = [Drawing.Color]::Gainsboro
    $detailForm.Controls.Add($detailBox)
    $detailForm.Show($form)
    Update-Details
}
$details.Add_Click({ Show-Details })

function Read-State {
    if(-not (Test-Path -LiteralPath $stateFile)){ Update-Details; return }
    try {
        $lines = Get-Content -LiteralPath $stateFile -ErrorAction Stop
        if($lines.Count -ge 2){
            $pct=0; [int]::TryParse($lines[0],[ref]$pct) | Out-Null
            $progress.Value = [math]::Max(0,[math]::Min(100,$pct))
            $status.Text = [string]$lines[1]
        }
        Update-Details
        if($lines.Count -ge 3 -and $lines[2] -eq 'DONE') {
            $timer.Stop(); $install.Enabled=$false; $browse.Enabled=$false
            $root = if($lines.Count -ge 4){$lines[3]}else{''}
            [Windows.Forms.MessageBox]::Show("MiniAI is installed at:`r`n$root`r`n`r`nUse Start_MiniAI.cmd or the Start Menu shortcut.",'MiniAI',0,64) | Out-Null
        } elseif($lines.Count -ge 3 -and $lines[2] -eq 'ERROR') {
            $timer.Stop(); $install.Enabled=$true; $browse.Enabled=$true
            $msg = if($lines.Count -ge 4){$lines[3]}else{'Unknown installer error.'}
            [Windows.Forms.MessageBox]::Show($msg,'MiniAI installation failed',0,16) | Out-Null
        }
    } catch { Update-Details }
}
$timer.Add_Tick({ Read-State })

$browse.Add_Click({
    if(-not $install.Enabled){return}
    $d=New-Object Windows.Forms.FolderBrowserDialog; $d.Description='Choose the parent folder for MiniAI'
    if($d.ShowDialog() -eq 'OK'){$box.Text=Join-Path $d.SelectedPath 'MiniAI'}
})

$install.Add_Click({
    if(-not $install.Enabled){return}
    try {
        $requested=$box.Text.Trim()
        if([string]::IsNullOrWhiteSpace($requested)){throw 'Choose an installation folder.'}
        $requested=[Environment]::ExpandEnvironmentVariables($requested)
        if(-not [IO.Path]::IsPathRooted($requested)){throw 'The installation path must be a full Windows path, such as D:\MiniAI.'}
        $driveRoot=[IO.Path]::GetPathRoot($requested)
        if([string]::IsNullOrWhiteSpace($driveRoot)){throw 'The installation path must include a drive, such as D:\MiniAI.'}
        $driveLetter=$driveRoot.Substring(0,1).ToUpperInvariant()
        $psDrive=Get-PSDrive -Name $driveLetter -ErrorAction Stop
        if($psDrive.Free -lt 6GB){throw 'The selected drive needs at least 6 GB free for the base install, temporary download files, and model.'}
        Remove-Item -LiteralPath $stateFile,$logFile,$stdoutFile,$stderrFile,$workerCmd -Force -ErrorAction SilentlyContinue
        $install.Enabled=$false; $browse.Enabled=$false; $progress.Value=0; $status.Text='Starting installer worker...'
        $worker=Join-Path $ScriptRoot 'Install_Worker.ps1'
        if(-not(Test-Path -LiteralPath $worker)){throw "Installer worker is missing: $worker"}
        # Use a CMD wrapper only for stdout/stderr redirection. Paths are quoted normally; no PowerShell backtick escaping is used.
        $dq=[char]34
        $workerCmdText='@echo off`r`n' + 'echo MiniAI worker wrapper started.' + "`r`n" + 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File ' + $dq + $worker + $dq + ' -Requested ' + $dq + $requested + $dq + ' -ScriptRoot ' + $dq + $ScriptRoot + $dq + ' -StateFile ' + $dq + $stateFile + $dq + ' -LogFile ' + $dq + $logFile + $dq + ' 1>' + $dq + $stdoutFile + $dq + ' 2>' + $dq + $stderrFile + $dq + "`r`nexit /b %errorlevel%`r`n"
        # Convert the literal backslash-r/backslash-n markers above to actual CRLF only for the wrapper line.
        $workerCmdText=$workerCmdText.Replace('`r`n',"`r`n")
        Set-Content -LiteralPath $workerCmd -Value $workerCmdText -Encoding ASCII
        $psi=New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName=$env:ComSpec
        $psi.Arguments='/d /c ' + $dq + $workerCmd + $dq
        $psi.WorkingDirectory=$ScriptRoot
        $psi.UseShellExecute=$false; $psi.CreateNoWindow=$true
        $workerProcess=[Diagnostics.Process]::Start($psi)
        $timer.Start(); Update-Details
    } catch {
        $install.Enabled=$true; $browse.Enabled=$true
        [Windows.Forms.MessageBox]::Show($_.Exception.ToString(),'MiniAI installation failed',0,16) | Out-Null
    }
})

$form.Add_FormClosed({
    $timer.Stop()
    if($workerProcess -and -not $workerProcess.HasExited){try{$workerProcess.Kill()}catch{}}
    # Keep diagnostics instead of deleting them, so a failed install can be investigated after the window closes.
    if(Test-Path -LiteralPath $workerCmd){Remove-Item -LiteralPath $workerCmd -Force -ErrorAction SilentlyContinue}
})
[void]$form.ShowDialog()
