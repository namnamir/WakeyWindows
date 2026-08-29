<#
.SYNOPSIS
  Free local Authenticode code signing script for WakeyWindows.

.DESCRIPTION
  Creates a local SHA256 Code Signing certificate, imports it to the local Trusted Publisher
  and Root stores, and digitally signs the WakeyWindows executable with an RFC3161 timestamp.
  After running this script, the file Properties -> Digital Signatures tab will display a valid,
  trusted signature for free.

.PARAMETER FilePath
  Path to the .exe file to sign. If omitted, searches for the compiled executable in bin/ or local folder.

.EXAMPLE
  .\Sign-Binary.ps1

.EXAMPLE
  .\Sign-Binary.ps1 -FilePath ".\bin\Release\net8.0-windows\win-x64\publish\WakeyWindows.exe"
#>

param(
    [string]$FilePath
)

$ErrorActionPreference = "Stop"

# 1. Locate the executable to sign
if (-not $FilePath) {
    $candidates = @(
        "$PSScriptRoot\bin\Release\net8.0-windows\win-x64\publish\WakeyWindows.exe",
        "$PSScriptRoot\bin\Release\net8.0-windows\win-x64\publish\PowerManager.exe",
        "$PSScriptRoot\bin\Release\net8.0-windows\WakeyWindows.exe",
        "$PSScriptRoot\bin\Release\net8.0-windows\PowerManager.exe",
        "$PSScriptRoot\WakeyWindows.exe",
        "$PSScriptRoot\PowerManager.exe"
    )
    foreach ($cand in $candidates) {
        if (Test-Path $cand) {
            $FilePath = $cand
            break
        }
    }
}

if (-not $FilePath -or -not (Test-Path $FilePath)) {
    Write-Warning "Could not find a compiled executable to sign. Specify -FilePath or build the project first."
    Write-Host "Usage: .\Sign-Binary.ps1 -FilePath '<path-to-exe>'"
    exit 1
}

Write-Host "Target executable: $FilePath" -ForegroundColor Cyan

# 2. Check for or create a Code Signing certificate
$CertSubject = "CN=WakeyWindows Code Signing"
$cert = Get-ChildItem -Path "Cert:\CurrentUser\My" -CodeSigningCert | Where-Object { $_.Subject -eq $CertSubject } | Select-Object -First 1

if (-not $cert) {
    Write-Host "Creating local Code Signing certificate ($CertSubject)..." -ForegroundColor Yellow
    $cert = New-SelfSignedCertificate `
        -Type CodeSigning `
        -Subject $CertSubject `
        -CertStoreLocation "Cert:\CurrentUser\My" `
        -NotAfter (Get-Date).AddYears(5) `
        -HashAlgorithm "SHA256" `
        -KeyLength 2048
    
    Write-Host "Certificate created: $($cert.Thumbprint)" -ForegroundColor Green
} else {
    Write-Host "Using existing certificate: $($cert.Thumbprint)" -ForegroundColor Green
}

# 3. Ensure the certificate is trusted locally (adds to TrustedPublisher & Root)
try {
    $rootStore = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "CurrentUser")
    $rootStore.Open("ReadWrite")
    $rootStore.Add($cert)
    $rootStore.Close()

    $pubStore = New-Object System.Security.Cryptography.X509Certificates.X509Store("TrustedPublisher", "CurrentUser")
    $pubStore.Open("ReadWrite")
    $pubStore.Add($cert)
    $pubStore.Close()
} catch {
    Write-Warning "Note: Could not automatically add certificate to Root store (may require user consent): $_"
}

# 4. Sign the binary with RFC3161 timestamping
Write-Host "Applying digital signature with DigiCert timestamp..." -ForegroundColor Yellow

$timestampServers = @(
    "http://timestamp.digicert.com",
    "http://timestamp.sectigo.com",
    "http://tsa.starfieldtech.com"
)

$sig = $null
foreach ($ts in $timestampServers) {
    try {
        $sig = Set-AuthenticodeSignature `
            -FilePath $FilePath `
            -Certificate $cert `
            -TimestampServer $ts `
            -HashAlgorithm "SHA256" `
            -ErrorAction SilentlyContinue
        
        if ($sig -and $sig.Status -eq "Valid") {
            Write-Host "Successfully signed with timestamp server: $ts" -ForegroundColor Green
            break
        }
    } catch {
        # Try next timestamp server
    }
}

# Fallback: sign without timestamp if offline
if (-not $sig -or $sig.Status -ne "Valid") {
    Write-Host "Signing without timestamp server (offline fallback)..." -ForegroundColor Yellow
    $sig = Set-AuthenticodeSignature -FilePath $FilePath -Certificate $cert -HashAlgorithm "SHA256"
}

# 5. Verify and display result
Write-Host "`n--- Signature Status ---" -ForegroundColor Cyan
$verify = Get-AuthenticodeSignature -FilePath $FilePath
Write-Host "Status:        $($verify.Status)" -ForegroundColor ($verify.Status -eq "Valid" ? "Green" : "Yellow")
Write-Host "StatusMessage: $($verify.StatusMessage)"
Write-Host "Signer:        $($verify.SignerCertificate.Subject)"
Write-Host "Algorithm:     $($verify.SignerCertificate.SignatureAlgorithm.FriendlyName)"
Write-Host "Timestamp:     $(if ($verify.TimeStamperCertificate) { $verify.TimeStamperCertificate.Subject } else { 'None' })"
Write-Host "------------------------`n"

if ($verify.Status -eq "Valid") {
    Write-Host "Executable successfully signed! Check Properties -> Digital Signatures in Windows Explorer." -ForegroundColor Green
} else {
    Write-Host "Signature created (Status: $($verify.Status))." -ForegroundColor Yellow
}
