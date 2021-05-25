#Requires -Version 5.1
# Require PowerShell v5.1 or above to prevent errors. Windows 10/Server version 1607 or newer have already pre-installed.

$scriptVersion = "1.1.1"
$host.ui.RawUI.WindowTitle = "UNWDS Installer (v$scriptVersion)"
$ProgressPreference = 'SilentlyContinue'

# First, set PS's security protocol to TLS1.2 to avoid Github Releases download problems.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Prepare variables
$repoName = "UnnamedNetwork/UNWDS"
$assetPattern = "UNWDS.phar"
$releasesUri = "https://api.github.com/repos/$repoName/releases/latest"
$asset = (Invoke-WebRequest $releasesUri | ConvertFrom-Json).assets | Where-Object name -like $assetPattern
$downloadUri = $asset.browser_download_url
$CurrentVPath = "$PSScriptRoot\current_version.info"
$CurrentRPath = "$PSScriptRoot\remote_version.info"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/UnnamedNetwork/unnamednetwork.github.io/main/UNWDS/version_control/remote_version.info" -OutFile "$PSScriptRoot\remote_version.info"

function GetServerVersion {
    Write-Output "[*] Contacting updater server to get version..."
    $Rfile = Get-Content "$CurrentRPath"
    $RcontainsWord = $Rfile | ForEach-Object{$_ -match "REMOTE_UNWDS_VERSION"}
    if ($RcontainsWord -contains $true) {
    } else {
        Write-Output "[*] Can't found server latest current version."
    }
    
    $Rfile = Get-Content "$CurrentRPath"
    $RcontainsWord = $Rfile | ForEach-Object{$_ -match "REMOTE_PHP_VERSION"}
    if ($RcontainsWord -contains $true) {
    } else {
        Write-Output "[*] Can't found defined PHP current version."
    }

    $file = Get-Content "$CurrentRPath"
    $containsWord = $file | ForEach-Object{$_ -match "REMOTE_RELEASED"}
    if ($containsWord -contains $true) {
    } else {
        Write-Output "[*] Can't found defined released date"
        $global:remoteReleasedDate = "0"
    }

    $values = Get-Content $CurrentRPath | Out-String | ConvertFrom-StringData
    $global:remotePHPversion = $values.REMOTE_PHP_VERSION
    $global:remoteUNWDSversion = $values.REMOTE_UNWDS_VERSION
    $global:remoteReleasedDate = $values.REMOTE_RELEASED

    Write-Output "[*] Server latest PHP version is: $remotePHPversion"
    Write-Output "[*] Server latest UNWDS version is: $remoteUNWDSversion, released in $remoteReleasedDate "
    Write-Output "`n"
}

function UpdateVersionFile {
    Remove-Item $CurrentVPath -Force -erroraction 'silentlycontinue'
    Rename-Item -Path $CurrentRPath -NewName "current_version.info"
    $filePath = $CurrentVPath
    $tempFilePath = "$env:TEMP\$($filePath | Split-Path -Leaf)"
    $find = 'REMOTE'
    $replace = 'CURRENT'

    (Get-Content -Path $filePath) -replace $find, $replace | Add-Content -Path $tempFilePath
    Get-ChildItem -path "$CurrentVPath" -force | ForEach-Object {$_.Attributes = "Normal"}
    Remove-Item -Path $filePath
    Move-Item -Path $tempFilePath -Destination $filePath
    Get-ChildItem -path "$filePath" -force | ForEach-Object {$_.Attributes = "Hidden"}
}

function UpdateChecker{
    function GetCurrentVersion {
        $file = Get-Content "$CurrentVPath"
        $containsWord = $file | ForEach-Object{$_ -match "CURRENT_UNWDS_VERSION"}
        if ($containsWord -contains $true) {
        } else {
            Write-Output "[*] Can't found current version. But still continue to update the server software."
            $global:currentUNWDSversion = "0"
        }
        
        $file = Get-Content "$CurrentVPath"
        $containsWord = $file | ForEach-Object{$_ -match "CURRENT_PHP_VERSION"}
        if ($containsWord -contains $true) {
        } else {
            Write-Output "[*] Can't found defined PHP current version. But still continue to update PHP binary."
            $global:currentPHPversion = "0"
        }

        $file = Get-Content "$CurrentVPath"
        $containsWord = $file | ForEach-Object{$_ -match "RELEASED"}
        if ($containsWord -contains $true) {
        } else {
            Write-Output "[*] Can't found defined released date"
            $global:currentReleasedDate = "0"
        }

        $values = Get-Content $CurrentVPath | Out-String | ConvertFrom-StringData
        $global:currentPHPversion = $values.CURRENT_PHP_VERSION
        $global:currentUNWDSversion = $values.CURRENT_UNWDS_VERSION
        $global:currentReleasedDate = $values.CURRENT_RELEASED

        Write-Output "[*] Current PHP version is: $currentPHPversion"
        Write-Output "[*] Current UNWDS version is: $currentUNWDSversion, released in $currentReleasedDate"
    }
 
    function UpdatePHP {
        Remove-Item PHP-7.4-Windows-x64 -Recurse -Force -erroraction 'silentlycontinue'
        Remove-Item bin -Recurse -Force -erroraction 'silentlycontinue'
        Remove-Item PHP-7.4-Windows-x64.zip -Force -erroraction 'silentlycontinue'
        Remove-Item vc_redist.x64.exe -erroraction 'silentlycontinue'
        Write-Output "[*] Updating PHP v$remotePHPversion (Windows x64)...";
        Invoke-WebRequest -Uri "https://jenkins.pmmp.io/job/PHP-7.4-Aggregate/lastSuccessfulBuild/artifact/PHP-7.4-Windows-x64.zip" -OutFile "PHP-7.4-Windows-x64.zip"
        Expand-Archive -LiteralPath PHP-7.4-Windows-x64.zip -Force
        Get-ChildItem -Path "PHP-7.4-Windows-x64" -Recurse |  Move-Item -Destination .
        Remove-Item PHP-7.4-Windows-x64.zip -Force -erroraction 'silentlycontinue'
        Remove-Item PHP-7.4-Windows-x64 -Recurse -Force -erroraction 'silentlycontinue'
        Write-Output "[*] Update successfully!"
    }
    function UpdateUNWDS {
        Remove-Item UNWDS.phar -Force -erroraction 'silentlycontinue'
        Remove-Item start.cmd -erroraction 'silentlycontinue'
        Write-Output "[*] Updating UNWDS v$remoteUNWDSversion";
        Invoke-WebRequest -Uri $downloadUri -OutFile "UNWDS.phar"
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/UnnamedNetwork/UNWDS/stable/start.cmd" -OutFile "start.cmd"
        Write-Output "[*] Update successfully!"
    }
    
    function CompareVersion {
        if ($remotePHPversion -le $currentPHPversion) {
            Write-Output "[*] PHP already up-to-date (Server: $remotePHPversion - You have: $currentPHPversion)"
        } else {
            Write-Output "[*] PHP need update (Server: $remotePHPversion - You have: $currentPHPversion)"
            UpdatePHP
        }
        if ($remoteUNWDSversion -le $currentUNWDSversion) {
            Write-Output "[*] UNWDS already up-to-date (Server: $remoteUNWDSversion - You have: $currentUNWDSversion)"
        } else {
            Write-Output "[*] UNWDS need update (Server: $remoteUNWDSversion, released in $remoteReleasedDate - You have: $currentUNWDSversion, released in $currentReleasedDate)"
            UpdateUNWDS
        }
        UpdateVersionFile
    }
    Write-Output "[*] Seems UNWDS has been installed on this directory. Checking for update..."
    GetCurrentVersion
    Write-Output "`n"
    GetServerVersion
    Write-Output "`n"
    CompareVersion
    
}

# Clean up old files
function CleanUp {
    Write-Output "`n"
    Write-Output "[*] Welcome to UNWDS Installer!";
    Write-Output "`n"
    Write-Output "[*] Windows x64 detected. Installing...";
    Write-Output "`n"
    Write-Output "[1/3] Cleaning up";
    Write-Output "`n"
    Remove-Item PHP-7.4-Windows-x64 -Recurse -Force -erroraction 'silentlycontinue'
    Remove-Item bin -Recurse -Force -erroraction 'silentlycontinue'
    Remove-Item PHP-7.4-Windows-x64.zip -Force -erroraction 'silentlycontinue'
    Remove-Item UNWDS.phar -Force -erroraction 'silentlycontinue'
    Remove-Item start.cmd -erroraction 'silentlycontinue'
    Remove-Item current_version.info -Force -erroraction 'silentlycontinue'
    Remove-Item vc_redist.x64.exe -erroraction 'silentlycontinue'
}

function ErrorCleanUp {
    Clear-Host
    Write-Output "[ERR] Installation was failed because an error occurred";
    Write-Output "[*] Cleaning up files because installation errors...";
    Write-Output "`n"
    Remove-Item PHP-7.4-Windows-x64 -Recurse -Force -erroraction 'silentlycontinue'
    Remove-Item bin -Recurse -Force -erroraction 'silentlycontinue'
    Remove-Item PHP-7.4-Windows-x64.zip -Force -erroraction 'silentlycontinue'
    Remove-Item UNWDS.phar -Force -erroraction 'silentlycontinue'
    Remove-Item start.cmd -erroraction 'silentlycontinue'
    Remove-Item vc_redist.x64.exe -erroraction 'silentlycontinue'
    Remove-Item remote_version.info -Force -erroraction 'silentlycontinue'
    Remove-Item current_version.info -Force -erroraction 'silentlycontinue'
    Write-Output "Some file does not exist. UNWDS will not run if missing files. Please try to run install script again."
    $host.ui.RawUI.WindowTitle = "Windows PowerShell" #set the window title back to default
}

function Main {
    # First, download the server software phar and startup script...
    Write-Output "[2/3] Downloading UNWDS v$remoteUNWDSversion, released in $remoteReleasedDate...";
    Invoke-WebRequest -Uri $downloadUri -OutFile "UNWDS.phar"
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/UnnamedNetwork/UNWDS/stable/start.cmd" -OutFile "start.cmd"
    Write-Output "`n"
    # Second, download PHP and extract it.
    Write-Output "[3/3] Downloading PHP $remotePHPVersion (Windows x64)...";
    Invoke-WebRequest -Uri "https://jenkins.pmmp.io/job/PHP-7.4-Aggregate/lastSuccessfulBuild/artifact/PHP-7.4-Windows-x64.zip" -OutFile "PHP-7.4-Windows-x64.zip"
    Expand-Archive -LiteralPath PHP-7.4-Windows-x64.zip -Force
    Get-ChildItem -Path "PHP-7.4-Windows-x64" -Recurse |  Move-Item -Destination .
    Remove-Item PHP-7.4-Windows-x64.zip -Force -erroraction 'silentlycontinue'
    Remove-Item PHP-7.4-Windows-x64 -Recurse -Force -erroraction 'silentlycontinue'
    Write-Output "`n"
}

function CheckFiles {
    if (-not (Test-Path -Path UNWDS.phar)) {
        ErrorCleanUp
        throw 'The file (UNWDS.phar) does not exist. UNWDS will not run if missing files. Please try to run install script again.'
    } else {
    }
    if (-not (Test-Path -Path start.cmd)) {
        ErrorCleanUp
        throw 'The file (start.cmd) does not exist. UNWDS will not run if missing files. Please try to run install script again.'
    } else {
    }
    if (-not (Test-Path -Path bin\php\php.exe)) {
        ErrorCleanUp
        throw 'The file (php.exe) does not exist. UNWDS will not run if missing files. Please try to run install script again.'
    } else {
    }
    Write-Output "[*] Everything done! Run ./start.cmd to start UNWDS";
    Write-Output "[*] Make sure you have installed Microsoft Visual C++ 2015-19 Redistributable (x64) on your PC.";
    Write-Output "[*] If not, you can run vc_redist.x64.exe in your cuurent folder to install it."
}

if ([Environment]::Is64BitProcess -ne [Environment]::Is64BitOperatingSystem)
{
    Write-Output "[ERR] You're running 32-bit system or you're run this UNWDS Installer in PowerShell (x86), these are not supported by UNWDS.";
    Write-Output "[ERR] Please consider upgrade to 64-bit system or use PowerShell (x64) to run UNWDS Installer.";
    exit
}
else
{
    if (-not (Test-Path -Path current_version.info)) {
        CleanUp
        GetServerVersion
        Main
        CheckFiles
        UpdateVersionFile
        $host.ui.RawUI.WindowTitle = "Windows PowerShell" #set the window title back to default
    } else {
        UpdateChecker
    }
}