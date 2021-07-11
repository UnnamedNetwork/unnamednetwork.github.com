#Requires -Version 5.1

#TODO: work at 'function as parameter'

# HOW UNWDS INSTALLER (WINDOWS) WORK?
# UNWDS Installer are based on PowerShell script.
# First, the installer download a file named "remoteVersion.json" contains some version strings that helps some update tasks easier.
# Based on that file, installer have some info for builds they are working with and define it to current version, file named "currentVersion.json"
# Then the installer download the server software from Github and PHP from pmmp's Jenkins servers
# HOW UPDATE WORK?

# When update, the installer compare strings from server and current (so that changing contents in "currentVersion.json" are not recommended.)
# If the installer detect the new version, it's will download from Github (for server software) or pmmp's Jenkins (for PHP) automatically.
# Then, the installer delete "currentVersion.json" file and rename "remoteVersion.json" to "currentVersion.json" 
# Update completed!
#
# Enjoy your installer and don't delete currentVersion.json. This will trigger cleanup and delete ALL FILE in working folder.
# Thanks for using this tool.

$scriptVersion = "2.0.0"
$host.ui.RawUI.WindowTitle = "UNWDS Installer (v$scriptVersion)"

# First, set PS's security protocol to TLS1.2 to avoid Github Releases download problems.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$repo = "UnnamedNetwork/UNWDS"
$file = "UNWDS.phar"
$CurrentVPath = "$PSScriptRoot\currentVersion.json"
$CurrentRPath = "$PSScriptRoot\remoteVersion.json"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/UnnamedNetwork/unnamednetwork.github.io/main/UNWDS/version_control/remoteVersion.json" -OutFile "remoteVersion.json"

function GetServerVersion {
    Write-Output "[*] Contacting update server to get version..."
    Write-Output "`n"
    $remoteJsonData = Get-Content $CurrentRPath | ConvertFrom-Json
    $Global:remoteJsonVersion= $remoteJsonData[0].Value
    $Global:remoteTarget= $remoteJsonData[1].Value
    $Global:remoteUNWDSversion = $remoteJsonData[2].Value
    $Global:remoteBuildNumber = $remoteJsonData[3].Value
    $Global:remotePHPversion = $remoteJsonData[4].Value
    $Global:remoteReleasedDate = $remoteJsonData[5].Value
    Write-Output "[*] Server JSON configuration version: $remoteJsonVersion"
    Write-Output "[*] Server latest PHP version is: $remotePHPversion"
    Write-Output "[*] Server latest UNWDS version is: $remoteUNWDSversion - $remoteBuildNumber ($remoteTarget), released in $remoteReleasedDate "
    Write-Output "`n"
}

function GetCurrentVersion {
    $currentJsonData = Get-Content $CurrentVPath | ConvertFrom-Json
    $Global:currentJsonVersion = $currentJsonData[0].Value
    $Global:currentTarget = $currentJsonData[1].Value
    $Global:currentUNWDSversion = $currentJsonData[2].Value
    $Global:currentBuildNumber = $currentJsonData[3].Value
    $Global:currentPHPversion = $currentJsonData[4].Value
    $Global:currentReleasedDate = $currentJsonData[5].Value
    Write-Output "[*] Current JSON configuraton version: $currentJsonVersion"
    Write-Output "[*] Current PHP version is: $currentPHPversion"
    Write-Output "[*] Current UNWDS version is: $currentUNWDSversion - $currentBuildNumber ($currentTarget), released in $currentReleasedDate"
    Write-Output "`n"
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

function CleanUp {
    Write-Output "`n"
    Write-Output "[*] Welcome to UNWDS Installer!";
    Write-Output "`n"
    Write-Output "[*] Windows x64 detected. Installing...";
    Write-Output "`n"
    Write-Output "[1/3] Cleaning up";
    Write-Output "`n"
    Remove-Item PHP-$remotePHPversion-Windows-x64 -Recurse -Force -erroraction 'silentlycontinue'
    Remove-Item bin -Recurse -Force -erroraction 'silentlycontinue'
    Remove-Item PHP-$remotePHPversion-Windows-x64.zip -Force -erroraction 'silentlycontinue'
    Remove-Item UNWDS.phar -Force -erroraction 'silentlycontinue'
    Remove-Item start.cmd -erroraction 'silentlycontinue'
    Remove-Item current_version.info -Force -erroraction 'silentlycontinue'
    Remove-Item vc_redist.x64.exe -erroraction 'silentlycontinue'
}

function ErrorCleanUp {
    Clear-Host
    Write-Output "[ERR] Install was failed because an error occurred";
    Write-Output "[*] Cleaning up files because installation errors...";
    Write-Output "`n"
    Remove-Item PHP-$remotePHPversion-Windows-x64 -Recurse -Force -erroraction 'silentlycontinue'
    Remove-Item bin -Recurse -Force -erroraction 'silentlycontinue'
    Remove-Item PHP-$remotePHPversion-Windows-x64.zip -Force -erroraction 'silentlycontinue'
    Remove-Item UNWDS.phar -Force -erroraction 'silentlycontinue'
    Remove-Item start.cmd -erroraction 'silentlycontinue'
    Remove-Item vc_redist.x64.exe -erroraction 'silentlycontinue'
    Remove-Item remoteVersion.json -Force -erroraction 'silentlycontinue'
    Remove-Item currentVersion.json -Force -erroraction 'silentlycontinue'
    Write-Output "Some file does not exist. UNWDS will not run if missing files. Please try to run install script again."
    $host.ui.RawUI.WindowTitle = "Windows PowerShell" #set the window title back to default
}

function Install {
    GetServerVersion
    Write-Output "[2/3] Downloading UNWDS v$remoteUNWDSversion ($remoteTarget), released in $remoteReleasedDate...";
    $DownloadURL = "https://github.com/$repo/releases/download/v$remoteUNWDSVersion/$file"
    Invoke-WebRequest $DownloadURL -Out $file
    Write-Host $DownloadURL
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/UnnamedNetwork/UNWDS/stable/start.cmd" -OutFile "start.cmd"
    Write-Output "`n"
    Write-Output "[3/3] Downloading PHP $remotePHPVersion (Windows x64)...";
    Invoke-WebRequest -Uri "https://jenkins.pmmp.io/job/PHP-$remotePHPversion-Aggregate/lastSuccessfulBuild/artifact/PHP-$remotePHPversion-Windows-x64.zip" -OutFile "PHP-$remotePHPversion-Windows-x64.zip"
    Expand-Archive -LiteralPath PHP-$remotePHPversion-Windows-x64.zip -Force
    Get-ChildItem -Path "PHP-$remotePHPversion-Windows-x64" -Recurse |  Move-Item -Destination .
    Remove-Item PHP-$remotePHPversion-Windows-x64.zip -Force -erroraction 'silentlycontinue'
    Remove-Item PHP-$remotePHPversion-Windows-x64 -Recurse -Force -erroraction 'silentlycontinue'
    Write-Output "`n"
}
function UpdatePHP {
    Remove-Item PHP-$currentPHPversion-Windows-x64 -Recurse -Force -erroraction 'SilentlyContinue'
    Remove-Item PHP-$remotePHPversion-Windows-x64 -Recurse -Force -erroraction 'silentlycontinue'
    Remove-Item bin -Recurse -Force -erroraction 'silentlycontinue'
    Remove-Item PHP-$remotePHPversion-Windows-x64.zip -Force -erroraction 'silentlycontinue'
    Remove-Item PHP-$currentPHPversion-Windows-x64.zip -Force -erroraction 'silentlycontinue'
    Remove-Item vc_redist.x64.exe -erroraction 'silentlycontinue'
    Write-Output "[*] Updating PHP v$remotePHPversion (Windows x64)...";
    Invoke-WebRequest -Uri "https://jenkins.pmmp.io/job/PHP-$remotePHPversion-Aggregate/lastSuccessfulBuild/artifact/PHP-$remotePHPversion-Windows-x64.zip" -OutFile "PHP-$remotePHPversion-Windows-x64.zip"
    Expand-Archive -LiteralPath PHP-$remotePHPversion-Windows-x64.zip -Force
    Get-ChildItem -Path "PHP-$remotePHPversion-Windows-x64" -Recurse |  Move-Item -Destination .
    Remove-Item PHP-$remotePHPversion-Windows-x64.zip -Force -erroraction 'silentlycontinue'
    Remove-Item PHP-$remotePHPversion-Windows-x64 -Recurse -Force -erroraction 'silentlycontinue'
    Write-Output "[*] Update successfully!"
}

function UpdateUNWDS {
    $DownloadURL = "https://github.com/$repo/releases/download/v$remoteUNWDSVersion/$file"
    Remove-Item UNWDS.phar -Force -erroraction 'silentlycontinue'
    Remove-Item start.cmd -erroraction 'silentlycontinue'
    Write-Output "[*] Updating UNWDS v$remoteUNWDSversion";
    Invoke-WebRequest $DownloadURL -Out $file
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/UnnamedNetwork/UNWDS/stable/start.cmd" -OutFile "start.cmd"
    Write-Output "[*] Update successfully!"
}

function UpdateVersionFile {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/UnnamedNetwork/unnamednetwork.github.io/main/UNWDS/version_control/remoteVersion.json" -OutFile "remoteVersion.json"
    Remove-Item -Path $CurrentVPath -Force -erroraction 'silentlycontinue'
    Rename-Item -Path $CurrentRPath -NewName "currentVersion.json"
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

function StartS {
    function PlatformCheck {
        if ([Environment]::Is64BitProcess -ne [Environment]::Is64BitOperatingSystem)
        {
            Write-Output "[ERR] You're running 32-bit system or you're run this UNWDS Installer in PowerShell (x86), these are not supported by UNWDS.";
            Write-Output "[ERR] Please consider upgrade to 64-bit system or use PowerShell (x64) to run UNWDS Installer.";
            throw Unsupported current CPU or PowerShell instance (32bit).
        } 
        else
        {
        Main
        }
    }
    PlatformCheck
}
function Update {
    GetCurrentVersion
    GetServerVersion
    CompareVersion
    UpdateVersionFile
}
function Main {
    if (-not (Test-Path -Path currentVersion.json)) {
        CleanUp
        Install
        CheckFiles
        UpdateVersionFile
        $host.ui.RawUI.WindowTitle = "Windows PowerShell" #set the window title back to default
    } else {
        Update
    }
}
StartS