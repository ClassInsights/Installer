Add-Type -AssemblyName System.Web;

$year = (Get-Date).year
Write-Host @'
  ____ _               ___           _       _     _       
 / ___| | __ _ ___ ___|_ _|_ __  ___(_) __ _| |__ | |_ ___ 
| |   | |/ _` / __/ __|| || '_ \/ __| |/ _` | '_ \| __/ __|
| |___| | (_| \__ \__ \| || | | \__ \ | (_| | | | | |_\__ \
 \____|_|\__,_|___/___/___|_| |_|___/_|\__, |_| |_|\__|___/
                                       |___/               
'@

Write-Host "
Komplettlösung für Energieeffizienz und Computerhandling in Schulen
Copyright 2024-${year}, ClassInsights, GbR
https://classinsights.at, https://github.com/ClassInsights

===================================================
"

Write-Host "

Bitte besuchen Sie: https://classinsights.at/installation um eine Anleitung für die Installation zu erhalten!


"

# Variables
$baseUrl = "https://raw.githubusercontent.com/classinsights/installer/refs/heads/main"
$msiUrl = "https://github.com/ClassInsights/WinService/releases/latest/download/ClassInsights.msi"

# Ask
Write-Host "Bitte gib deinen ClassInsights Lizenz Key ein"
$license = Read-Host 'Lizenz: '

Write-Host 'Was ist die IP Addresse des ClassInsights API Server? (Die Clients sollten die API unter dieser Adresse erreichen können)'
$ip = Read-Host 'IP: '
$localApi = "https://" + $ip + ":52001" # important: no /api

# Function to log errors
function Log-Error {
    param (
        [string]$Message
    )
    Write-Error "$(Get-Date -Format o) - $Message"
}

function Random {
    param (
        [int] $length
    )
    
    return ([System.Web.Security.Membership]::GeneratePassword($length, 4)).Replace("$", "!").Replace(";", "?").Replace("}", "&").Replace("{", "&").Replace(":", "#")
}

# Download scripts and files
try {
    # Create folders
    New-Item -ItemType Directory -Force -Path "$PSScriptRoot/gpo"
    New-Item -ItemType Directory -Force -Path "$PSScriptRoot/api"

    Invoke-WebRequest -Uri "$baseUrl/gpo/gpo_install.ps1" -OutFile "$PSScriptRoot/gpo/gpo_install.ps1" -UseBasicParsing -ErrorAction Stop
    Invoke-WebRequest -Uri $msiUrl -OutFile "$PSScriptRoot/gpo/ClassInsights.msi" -UseBasicParsing -ErrorAction Stop
    Invoke-WebRequest -Uri "$baseUrl/api/classinsights.sh" -OutFile "$PSScriptRoot/api/classinsights.sh" -UseBasicParsing -ErrorAction Stop

    Invoke-WebRequest -Uri "$baseUrl/api/docker-compose.yml" -OutFile "$PSScriptRoot/api/docker-compose.yml" -UseBasicParsing -ErrorAction Stop    
    Invoke-WebRequest -Uri "$baseUrl/api/api.env" -OutFile "$PSScriptRoot/api/api.env" -UseBasicParsing -ErrorAction Stop
} catch {
    Log-Error "Failed to download all scripts. $_"
    exit 1
}

# Create PFX
Write-Host "Erstelle Root Zertifikat"
$rootCert = New-SelfSignedCertificate -Subject "CN=ClassInsights CA" -CertStoreLocation "Cert:\LocalMachine\My" -KeyExportPolicy Exportable -KeyUsage CertSign, CRLSign, DigitalSignature -KeyLength 4096 -HashAlgorithm SHA256 -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider" -NotAfter (Get-Date).AddYears(15)
Export-Certificate -Cert $rootCert -FilePath "$PSScriptRoot/gpo/ClassInsights_CA.cer"

Write-Host "Erstelle SSL Zertifikat"
$sslCert = New-SelfSignedCertificate -Subject "CN=$ip" -TextExtension @("2.5.29.17={text}IPAddress=$ip") -Signer $rootCert -NotAfter (Get-Date).AddYears(15) -CertStoreLocation "Cert:\LocalMachine\My" -KeyExportPolicy Exportable -KeySpec Signature -KeyLength 2048 -KeyAlgorithm RSA -HashAlgorithm SHA256

$certPassword = Random 20
Export-PfxCertificate -Cert $sslCert -FilePath "$PSScriptRoot/api/cert.pfx" -Password (ConvertTo-SecureString $certPassword -AsPlainText -Force)


# Modify files
$computerToken = Random 32
$postgresPassword = Random 32

Write-Host "Finalisiere gpo_install.ps1"
$gpoInstaller = (Get-Content "$PSScriptRoot/gpo/gpo_install.ps1").Replace("[API_TOKEN]", $computerToken).Replace("[API_URL]", $localApi)
Set-Content -Path "$PSScriptRoot/gpo/gpo_install.ps1" -Value $gpoInstaller

Write-Host "Finalisiere api.env für Api"
$apiSettings = (Get-Content "$PSScriptRoot/api/api.env").Replace("[JWT_KEY]", (Random 60)).Replace("[COMPUTER_TOKEN]", $computerToken).Replace("[LICENSE_KEY]", $license).Replace("[PFX_PASSWORD]", $certPassword).Replace("[POSTGRES_PASSWORD]", $postgresPassword)
Set-Content -Path "$PSScriptRoot/api/api.env" -Value $apiSettings

Write-Host "Finalisiere docker-compose.yml für Api"
$dockerCompose = (Get-Content "$PSScriptRoot/api/docker-compose.yml").Replace("[POSTGRES_PASSWORD]", $postgresPassword)
Set-Content -Path "$PSScriptRoot/api/docker-compose.yml" -Value $dockerCompose


# Ask to upload files
Write-Host "Es wurden alle Dateien erzeugt."
$uploadFiles = Read-Host "Wollen Sie die Dateien für die lokale API nun auf den Server hochladen? (J/N)"
if ($uploadFiles.ToLower() -eq 'j') {
    $username = Read-Host "Username: "
    $serverIp = Read-Host "IP des Servers: "
    & scp -o StrictHostKeyChecking=accept-new -r api "${username}@${serverIp}:~/."
    
    Write-Host "Die Daten wurden erfolgreich auf den Server kopiert!"    
}

# Ask to create GPO
$proceed = Read-Host "Wollen Sie nun zu der Erstellung des Gruppenrichtlinienobjekts übergehen? (J/N)"
if ($proceed.ToLower() -eq 'j') {
    & "$PSScriptRoot\gpo\gpo_install.ps1"
}

