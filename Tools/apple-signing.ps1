param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('CreateRequest','ExportP12')]
    [string]$Stage,
    [Parameter(Mandatory=$true)]
    [string]$OutputDirectory,
    [string]$CertificatePath,
    [string]$OpenSSLPath = 'openssl'
)

# Run this later on your own Windows computer. It never uploads signing material.
# OpenSSL prompts interactively for passphrases; no password is a CLI argument.
$ErrorActionPreference = 'Stop'
$taskSigningDirectory = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($taskSigningDirectory) | Out-Null
$privateKey = Join-Path $taskSigningDirectory 'FirstMove-Distribution.key'
$requestFile = Join-Path $taskSigningDirectory 'FirstMove-Distribution.csr'
$pemFile = Join-Path $taskSigningDirectory 'FirstMove-Distribution.pem'
$p12File = Join-Path $taskSigningDirectory 'FirstMove-Distribution.p12'

if (-not (Get-Command $OpenSSLPath -ErrorAction SilentlyContinue)) {
    throw 'OpenSSL was not found. Install a trusted OpenSSL distribution, or pass -OpenSSLPath to the openssl.exe included with Git for Windows.'
}

function Invoke-OpenSSL([string[]]$Arguments) {
    & $OpenSSLPath @Arguments
    if ($LASTEXITCODE -ne 0) { throw 'OpenSSL did not complete. No upload was attempted.' }
}

if ($Stage -eq 'CreateRequest') {
    if ((Test-Path -LiteralPath $privateKey) -or (Test-Path -LiteralPath $requestFile)) {
        throw 'A key or request already exists in that folder. Choose a new folder to avoid replacing it.'
    }
    Write-Host 'Choose a strong passphrase for the encrypted private key. Keep this key and passphrase private.'
    Invoke-OpenSSL -Arguments @('genpkey','-algorithm','RSA','-pkeyopt','rsa_keygen_bits:2048','-aes-256-cbc','-out',$privateKey)
    Invoke-OpenSSL -Arguments @('req','-new','-key',$privateKey,'-out',$requestFile,'-subj','/CN=First Move Distribution')
    Write-Host "Request created: $requestFile"
    Write-Host 'Upload only the .csr file to your own Apple developer account when creating an Apple Distribution certificate. Never upload the .key to Apple or commit it to GitHub.'
} else {
    if (-not (Test-Path -LiteralPath $privateKey)) { throw 'The original encrypted private key is missing.' }
    if (-not $CertificatePath -or -not (Test-Path -LiteralPath $CertificatePath)) { throw 'Pass -CertificatePath with the .cer downloaded from your Apple developer account.' }
    if ((Test-Path -LiteralPath $pemFile) -or (Test-Path -LiteralPath $p12File)) { throw 'Export files already exist. Choose a new output folder or move the existing exported files first.' }
    $certificateFile = (Resolve-Path -LiteralPath $CertificatePath).Path
    Invoke-OpenSSL -Arguments @('x509','-inform','DER','-in',$certificateFile,'-out',$pemFile)
    Write-Host 'Enter the private-key passphrase, then choose a strong export password for the .p12.'
    Invoke-OpenSSL -Arguments @('pkcs12','-export','-inkey',$privateKey,'-in',$pemFile,'-out',$p12File,'-name','Apple Distribution')
    Write-Host "Encrypted signing bundle created: $p12File"
    Write-Host 'Keep this file and its password private. Add its base64 only as a repository Actions secret; never put it in a source file, issue, or chat.'
}
