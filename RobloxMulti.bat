@echo off
set "SELF=%~f0"
echo Starting RobloxMulti... Keep this window open.
powershell -NoProfile -ExecutionPolicy Bypass -STA -Command "$t=[IO.File]::ReadAllText($env:SELF); $m=':'+':PSCODE'+':'; $p=$t.IndexOf($m); if ($p -lt 0) { throw 'PSCODE marker not found' }; $j=$t.IndexOf([char]10,$p); Invoke-Expression $t.Substring($j+1)"
echo.
echo Program finished. If you saw a red error above, copy it and send it to me.
pause
exit /b
::PSCODE::
trap {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(($_.Exception.Message + "`r`n`r`n" + $_.InvocationInfo.PositionMessage), "RobloxMulti error") | Out-Null
    exit 1
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$global:handles = @()
$runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$profile2Root = Join-Path $env:USERPROFILE "RobloxProfile2"
$profile2Local = Join-Path $profile2Root "Local"
$copyVersions = Join-Path $profile2Local "Roblox\Versions"

$nativeCode = @'
using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;

public static class Fs {
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern bool CreateHardLink(string newFile, string existingFile, IntPtr sec);

    public static string Mirror(string src, string dst) {
        int[] c = new int[3];
        MirrorDir(new DirectoryInfo(src), dst, c);
        return c[0] + " linked, " + c[1] + " copied, " + c[2] + " failed";
    }

    static void MirrorDir(DirectoryInfo s, string d, int[] c) {
        Directory.CreateDirectory(d);
        foreach (FileInfo f in s.GetFiles()) {
            string t = Path.Combine(d, f.Name);
            if (File.Exists(t)) continue;
            if (CreateHardLink(t, f.FullName, IntPtr.Zero)) { c[0]++; }
            else {
                try { File.Copy(f.FullName, t); c[1]++; } catch { c[2]++; }
            }
        }
        foreach (DirectoryInfo sub in s.GetDirectories()) {
            MirrorDir(sub, Path.Combine(d, sub.Name), c);
        }
    }
}

public static class NtDir {
    [StructLayout(LayoutKind.Sequential)]
    public struct UNICODE_STRING { public ushort Length; public ushort MaximumLength; public IntPtr Buffer; }
    [StructLayout(LayoutKind.Sequential)]
    public struct OBJECT_ATTRIBUTES {
        public int Length; public IntPtr RootDirectory; public IntPtr ObjectName;
        public uint Attributes; public IntPtr SecurityDescriptor; public IntPtr SecurityQualityOfService;
    }
    [DllImport("ntdll.dll")] static extern int NtOpenDirectoryObject(out IntPtr h, uint access, ref OBJECT_ATTRIBUTES oa);
    [DllImport("ntdll.dll")] static extern int NtQueryDirectoryObject(IntPtr h, IntPtr buf, int len, bool single, bool restart, ref uint ctx, out uint ret);
    [DllImport("ntdll.dll")] static extern int NtClose(IntPtr h);

    public static List<string> List(string path) {
        List<string> res = new List<string>();
        IntPtr strBuf = Marshal.StringToHGlobalUni(path);
        IntPtr us = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(UNICODE_STRING)));
        UNICODE_STRING u = new UNICODE_STRING();
        u.Length = (ushort)(path.Length * 2);
        u.MaximumLength = (ushort)(u.Length + 2);
        u.Buffer = strBuf;
        Marshal.StructureToPtr(u, us, false);
        OBJECT_ATTRIBUTES oa = new OBJECT_ATTRIBUTES();
        oa.Length = Marshal.SizeOf(typeof(OBJECT_ATTRIBUTES));
        oa.ObjectName = us;
        oa.Attributes = 0x40;
        IntPtr h;
        int st = NtOpenDirectoryObject(out h, 3, ref oa);
        if (st != 0) {
            res.Add("ERROR opening " + path + " status 0x" + st.ToString("X"));
            Marshal.FreeHGlobal(strBuf); Marshal.FreeHGlobal(us);
            return res;
        }
        int bufLen = 0x10000;
        IntPtr buf = Marshal.AllocHGlobal(bufLen);
        uint ctx = 0; uint ret; bool restart = true;
        int usz = Marshal.SizeOf(typeof(UNICODE_STRING));
        while (true) {
            int s = NtQueryDirectoryObject(h, buf, bufLen, false, restart, ref ctx, out ret);
            restart = false;
            if (s != 0 && s != 0x105) break;
            IntPtr p = buf;
            while (true) {
                UNICODE_STRING nm = (UNICODE_STRING)Marshal.PtrToStructure(p, typeof(UNICODE_STRING));
                if (nm.Buffer == IntPtr.Zero) break;
                UNICODE_STRING tp = (UNICODE_STRING)Marshal.PtrToStructure(new IntPtr(p.ToInt64() + usz), typeof(UNICODE_STRING));
                res.Add(Marshal.PtrToStringUni(tp.Buffer, tp.Length / 2) + "\t" + Marshal.PtrToStringUni(nm.Buffer, nm.Length / 2));
                p = new IntPtr(p.ToInt64() + 2 * usz);
            }
            if (s == 0) break;
        }
        Marshal.FreeHGlobal(buf); Marshal.FreeHGlobal(strBuf); Marshal.FreeHGlobal(us);
        NtClose(h);
        return res;
    }
}
'@

# ---------------------------------------------------------------- UI
$form = New-Object System.Windows.Forms.Form
$form.Text = "RobloxMulti - 2 Roblox windows"
$form.Size = New-Object System.Drawing.Size(560, 740)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false

$title = New-Object System.Windows.Forms.Label
$title.Text = "RobloxMulti"
$title.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$title.Location = New-Object System.Drawing.Point(16, 10)
$title.AutoSize = $true
$form.Controls.Add($title)

$banner = New-Object System.Windows.Forms.Label
$banner.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$banner.Location = New-Object System.Drawing.Point(18, 48)
$banner.Size = New-Object System.Drawing.Size(508, 40)
$banner.Text = "Checking your system..."
$form.Controls.Add($banner)

$count = New-Object System.Windows.Forms.Label
$count.Text = "Roblox windows running: 0"
$count.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$count.Location = New-Object System.Drawing.Point(18, 92)
$count.AutoSize = $true
$form.Controls.Add($count)

$lockLabel = New-Object System.Windows.Forms.Label
$lockLabel.Text = "Game locks: NOT held"
$lockLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$lockLabel.ForeColor = [System.Drawing.Color]::Firebrick
$lockLabel.Location = New-Object System.Drawing.Point(300, 92)
$lockLabel.AutoSize = $true
$form.Controls.Add($lockLabel)

function New-Btn($text, $x, $y, $w, $h) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text
    $b.Location = New-Object System.Drawing.Point($x, $y)
    $b.Size = New-Object System.Drawing.Size($w, $h)
    $form.Controls.Add($b)
    return $b
}

$btnCopy  = New-Btn "1. Create / update the 2nd Roblox copy (needed once)" 18 120 508 36
$btnLocks = New-Btn "2. Hold game locks (closes Roblox first)" 18 162 508 36
$btnAcc1  = New-Btn "3. Roblox app: Account 1 (normal)" 18 206 248 44
$btnAcc2  = New-Btn "4. Roblox app: Account 2 (separate copy)" 278 206 248 44
$btnKill  = New-Btn "Close all Roblox" 18 258 248 30
$btnAuto  = New-Btn "Disable Roblox autostart" 278 258 248 30
$btnDiag  = New-Btn "Diagnose (copies report)" 18 296 248 30
$btnFind  = New-Btn "Find Roblox lock names" 278 296 248 30

$log = New-Object System.Windows.Forms.TextBox
$log.Multiline = $true
$log.ReadOnly = $true
$log.ScrollBars = "Vertical"
$log.Font = New-Object System.Drawing.Font("Consolas", 9)
$log.Location = New-Object System.Drawing.Point(18, 336)
$log.Size = New-Object System.Drawing.Size(508, 200)
$form.Controls.Add($log)

$help = New-Object System.Windows.Forms.Label
$help.Text = "How to use (Roblox APP):`r`n" +
    "1. Create the 2nd copy once (also again after Roblox updates).`r`n" +
    "2. 'Hold game locks' - keep this window open. It closes Roblox if running.`r`n" +
    "3. Click 'Account 1', then 'Account 2' (log in to your 2nd account there).`r`n" +
    "Do steps 2-4 every time you restart this program or the PC.`r`n" +
    "If it fails: close everything, redo from step 2, then click 'Diagnose'`r`n" +
    "or 'Find Roblox lock names' and send me the copied report."
$help.Location = New-Object System.Drawing.Point(18, 546)
$help.Size = New-Object System.Drawing.Size(508, 120)
$help.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$form.Controls.Add($help)

# ---------------------------------------------------------------- helpers
function Write-Log($msg) {
    $log.AppendText(("[{0}] {1}`r`n" -f (Get-Date -Format "HH:mm:ss"), $msg))
}

function Get-RobloxProcs {
    @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like "Roblox*" })
}

function Ensure-Native {
    try {
        if (-not ("Fs" -as [type])) { Add-Type -TypeDefinition $nativeCode -Language CSharp -ErrorAction Stop }
        return $true
    } catch {
        Write-Log "Could not compile helper: $($_.Exception.Message)"
        return $false
    }
}

function Stop-AllRoblox {
    $procs = Get-RobloxProcs
    if ($procs.Count -eq 0) { Write-Log "No Roblox processes found."; return }
    foreach ($p in $procs) {
        try { Stop-Process -Id $p.Id -Force -ErrorAction Stop; Write-Log "Closed $($p.ProcessName) (PID $($p.Id))" }
        catch { Write-Log "Could not close PID $($p.Id): $($_.Exception.Message)" }
    }
    Start-Sleep -Milliseconds 600
}

function Get-AutostartEntries {
    try {
        $props = Get-ItemProperty -Path $runKey -ErrorAction Stop
        return @($props.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" -and "$($_.Value)" -match "Roblox" })
    } catch { return @() }
}

function Disable-Autostart {
    $found = Get-AutostartEntries
    if ($found.Count -eq 0) { Write-Log "No Roblox autostart entry found."; return }
    foreach ($f in $found) {
        try { Remove-ItemProperty -Path $runKey -Name $f.Name -ErrorAction Stop; Write-Log "Removed startup entry: $($f.Name)" }
        catch { Write-Log "Could not remove $($f.Name): $($_.Exception.Message)" }
    }
}

function Release-Locks {
    foreach ($h in $global:handles) {
        try { $h.ReleaseMutex() } catch {}
        try { $h.Dispose() } catch {}
    }
    $global:handles = @()
    $lockLabel.Text = "Game locks: NOT held"
    $lockLabel.ForeColor = [System.Drawing.Color]::Firebrick
}

function Take-Locks {
    if ($global:handles.Count -gt 0) { return $true }
    if ((Get-RobloxProcs).Count -gt 0) {
        $r = [System.Windows.Forms.MessageBox]::Show(
            "Roblox is running (maybe hidden in the tray). It must be closed before the locks can be taken.`r`nClose all Roblox now?",
            "RobloxMulti", "YesNo", "Question")
        if ($r -ne "Yes") { Write-Log "Cancelled: Roblox still running, locks not taken."; return $false }
        Stop-AllRoblox
    }
    $ok = $true
    foreach ($n in @("ROBLOX_singletonMutex", "ROBLOX_singletonEvent")) {
        try {
            $created = $false
            $m = New-Object System.Threading.Mutex($true, $n, [ref]$created)
            if ($created) {
                $global:handles += $m
                Write-Log "Locked '$n'  [OK]"
            } else {
                $m.Dispose()
                Write-Log "FAILED: '$n' already exists (another process owns it)."
                $ok = $false
            }
        } catch {
            Write-Log "FAILED: '$n' -> $($_.Exception.Message)"
            $ok = $false
        }
    }
    if (-not $ok) {
        Release-Locks
        Write-Log "Could not take the locks. Restart the PC once and run this program BEFORE opening Roblox."
        return $false
    }
    $lockLabel.Text = "Game locks: HELD"
    $lockLabel.ForeColor = [System.Drawing.Color]::ForestGreen
    return $true
}

function Find-RobloxExe {
    $cands = @()
    foreach ($root in @("$env:LocalAppData\Roblox\Versions", "${env:ProgramFiles(x86)}\Roblox\Versions", "$env:ProgramFiles\Roblox\Versions")) {
        if (Test-Path $root) {
            foreach ($v in @(Get-ChildItem $root -Directory -ErrorAction SilentlyContinue)) {
                $exe = Join-Path $v.FullName "RobloxPlayerBeta.exe"
                if (Test-Path $exe) { $cands += (Get-Item $exe) }
            }
        }
    }
    if ($cands.Count -eq 0) { return $null }
    return ($cands | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}

function Get-CopyExe {
    if (-not (Test-Path $copyVersions)) { return $null }
    $cands = @()
    foreach ($v in @(Get-ChildItem $copyVersions -Directory -ErrorAction SilentlyContinue)) {
        $exe = Join-Path $v.FullName "RobloxPlayerBeta.exe"
        if (Test-Path $exe) { $cands += (Get-Item $exe) }
    }
    if ($cands.Count -eq 0) { return $null }
    return ($cands | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}

function New-RobloxCopy {
    $exe = Find-RobloxExe
    if (-not $exe) { Write-Log "Roblox not found. Install it from roblox.com first."; return }
    if (-not (Ensure-Native)) { return }

    $srcDir = Split-Path $exe
    $ver = Split-Path $srcDir -Leaf
    $dstDir = Join-Path $copyVersions $ver

    Write-Log "Source : $srcDir"
    Write-Log "Target : $dstDir"

    # remove outdated copies (hardlinks: deleting them never touches the original files)
    if (Test-Path $copyVersions) {
        foreach ($d in @(Get-ChildItem $copyVersions -Directory -ErrorAction SilentlyContinue)) {
            if ($d.Name -ne $ver) {
                try { Remove-Item -LiteralPath $d.FullName -Recurse -Force -ErrorAction Stop; Write-Log "Removed old copy: $($d.Name)" }
                catch { Write-Log "Could not remove old copy $($d.Name): $($_.Exception.Message)" }
            }
        }
    }

    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    [System.Windows.Forms.Application]::DoEvents()
    try {
        $res = [Fs]::Mirror($srcDir, $dstDir)
        Write-Log "Copy finished: $res"
        if (Test-Path (Join-Path $dstDir "RobloxPlayerBeta.exe")) {
            Write-Log "OK. Now use 'Account 1' and 'Account 2'."
        } else {
            Write-Log "FAILED: RobloxPlayerBeta.exe missing in the copy."
        }
    } catch {
        Write-Log "FAILED: $($_.Exception.Message)"
    }
    $form.Cursor = [System.Windows.Forms.Cursors]::Default
    Update-Banner
}

function Start-RobloxExe($exe, $localAppData, $label) {
    if (-not $exe) { Write-Log "$label : executable not found."; return }
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $exe
        $psi.WorkingDirectory = Split-Path $exe
        $psi.UseShellExecute = $false
        if ($localAppData) {
            New-Item -ItemType Directory -Force -Path $localAppData | Out-Null
            $psi.EnvironmentVariables["LOCALAPPDATA"] = $localAppData
        }
        [void][System.Diagnostics.Process]::Start($psi)
        Write-Log "$label : started $exe"
    } catch { Write-Log "$label : FAILED to start: $($_.Exception.Message)" }
}

function Get-Diagnosis {
    $L = New-Object System.Collections.Generic.List[string]
    $L.Add("=== RobloxMulti report ===")
    $L.Add("Windows: " + [System.Environment]::OSVersion.VersionString)
    $L.Add("Original exe: " + (Find-RobloxExe))
    $ce = Get-CopyExe
    if ($ce) { $L.Add("2nd copy exe: " + $ce) } else { $L.Add("2nd copy exe: NOT created yet") }
    $procs = Get-RobloxProcs
    $L.Add("Roblox processes running: " + $procs.Count)
    foreach ($p in $procs) {
        $path = ""
        try { $path = $p.Path } catch {}
        $L.Add("  - " + $p.ProcessName + " PID " + $p.Id + " " + $path)
    }
    $auto = Get-AutostartEntries
    $L.Add("Game locks held by this tool: " + $global:handles.Count)
    $L.Add("Roblox autostart entries: " + $auto.Count)
    foreach ($a in $auto) { $L.Add("  - " + $a.Name + " = " + $a.Value) }
    return ($L -join "`r`n")
}

function Update-Banner {
    $orig = Find-RobloxExe
    $ce = Get-CopyExe
    if (-not $orig) {
        $banner.Text = "Roblox (roblox.com version) not found. Install Roblox and play once first."
        $banner.ForeColor = [System.Drawing.Color]::Firebrick
        return
    }
    $origVer = Split-Path (Split-Path $orig) -Leaf
    $copyOk = $false
    if ($ce) { $copyOk = ((Split-Path (Split-Path $ce) -Leaf) -eq $origVer) }
    if (-not $ce) {
        $banner.Text = "Step 1 needed: click '1. Create the 2nd Roblox copy' (one time)."
        $banner.ForeColor = [System.Drawing.Color]::DarkOrange
    } elseif (-not $copyOk) {
        $banner.Text = "Roblox was updated. Click '1. Create / update the 2nd Roblox copy' again."
        $banner.ForeColor = [System.Drawing.Color]::DarkOrange
    } else {
        $banner.Text = "Ready. Click 'Account 1', then 'Account 2'."
        $banner.ForeColor = [System.Drawing.Color]::ForestGreen
    }
}

# ---------------------------------------------------------------- events
$btnCopy.Add_Click({ New-RobloxCopy })
$btnKill.Add_Click({ Stop-AllRoblox })
$btnAuto.Add_Click({ Disable-Autostart })

$btnLocks.Add_Click({ [void](Take-Locks) })

$btnAcc1.Add_Click({
    if (-not (Take-Locks)) { return }
    Start-RobloxExe (Find-RobloxExe) $null "Account 1"
})

$btnAcc2.Add_Click({
    $ce = Get-CopyExe
    if (-not $ce) { Write-Log "Create the 2nd copy first (button 1)."; return }
    if (-not (Take-Locks)) { return }
    Start-RobloxExe $ce $profile2Local "Account 2"
    Write-Log "Account 2 uses its own profile folder: $profile2Local"
    Write-Log "If it asks, log in with your 2nd account inside that Roblox window."
})

$btnDiag.Add_Click({
    $rep = Get-Diagnosis
    $log.Text = $rep
    try { [System.Windows.Forms.Clipboard]::SetText($rep); Write-Log "Report copied to clipboard. Paste it to Claude." } catch { Write-Log "Could not copy; select the text manually." }
})

$btnFind.Add_Click({
    if ((Get-RobloxProcs).Count -eq 0) { Write-Log "Open Roblox first (in a game), then click this button."; return }
    if (-not (Ensure-Native)) { return }
    $sid = [System.Diagnostics.Process]::GetCurrentProcess().SessionId
    $dirs = @("\BaseNamedObjects")
    if ($sid -gt 0) { $dirs = @("\Sessions\$sid\BaseNamedObjects", "\BaseNamedObjects") }
    $out = New-Object System.Collections.Generic.List[string]
    $out.Add("=== Roblox lock-name search ===")
    $out.Add("Session id: $sid")
    $out.Add((Get-Diagnosis))
    foreach ($d in $dirs) {
        $out.Add("--- Directory $d ---")
        try {
            $items = [NtDir]::List($d)
            $hits = @($items | Where-Object { $_ -match "(?i)roblox|rbx|\.mtx|\.shm|hyperion|byfron" })
            $out.Add("Matches: " + $hits.Count)
            foreach ($h in $hits) { $out.Add("  " + $h) }
        } catch { $out.Add("  Failed: " + $_.Exception.Message) }
    }
    $txt = ($out -join "`r`n")
    $log.Text = $txt
    try { [System.Windows.Forms.Clipboard]::SetText($txt); Write-Log "Report copied to clipboard. Paste it to Claude." } catch { Write-Log "Could not copy; select the text manually." }
})

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 2000
$timer.Add_Tick({
    $n = (Get-Process -Name "RobloxPlayerBeta" -ErrorAction SilentlyContinue | Measure-Object).Count
    $count.Text = "Roblox windows running: $n"
})
$timer.Start()

$form.Add_FormClosing({ Release-Locks })
$form.Add_Shown({ $form.Activate(); Update-Banner })
Write-Log "Ready."
[void]$form.ShowDialog()
