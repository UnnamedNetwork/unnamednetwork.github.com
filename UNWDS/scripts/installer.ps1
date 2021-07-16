#Requires -Version 5.1

#TODO: work at 'function as parameter'

$scriptVersion = "2.0.1"
$host.ui.RawUI.WindowTitle = "UNWDS Installer (v$scriptVersion)"

# First, set PS's security protocol to TLS1.2 to avoid Github Releases download problems.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$repo = "UnnamedNetwork/UNWDS"
$file = "UNWDS.phar"
$CurrentVPath = "$PSScriptRoot\currentVersion.json"

function GetServerVersion {
    Write-Host "[*] Contacting update server to get version..."
    Write-Host "`n"
    $remoteJsonData = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/UnnamedNetwork/unnamednetwork.github.io/main/UNWDS/version_control/remoteVersion.json" | ConvertFrom-Json
    $Global:remoteJsonVersion= $remoteJsonData[0].Value
    $Global:remoteTarget= $remoteJsonData[1].Value
    $Global:remoteUNWDSversion = $remoteJsonData[2].Value
    $Global:remoteBuildNumber = $remoteJsonData[3].Value
    $Global:remotePHPversion = $remoteJsonData[4].Value
    $Global:remoteReleasedDate = $remoteJsonData[5].Value
    Write-Host "[*] Server JSON configuration version: $remoteJsonVersion"
    Write-Host "[*] Server latest PHP version is: $remotePHPversion"
    Write-Host "[*] Server latest UNWDS version is: $remoteUNWDSversion - $remoteBuildNumber ($remoteTarget), released in $remoteReleasedDate "
    Write-Host "`n"
}

function GetCurrentVersion {
    $currentJsonData = Get-Content $CurrentVPath | ConvertFrom-Json
    $Global:currentJsonVersion = $currentJsonData[0].Value
    $Global:currentTarget = $currentJsonData[1].Value
    $Global:currentUNWDSversion = $currentJsonData[2].Value
    $Global:currentBuildNumber = $currentJsonData[3].Value
    $Global:currentPHPversion = $currentJsonData[4].Value
    $Global:currentReleasedDate = $currentJsonData[5].Value
    Write-Host "[*] Current JSON configuraton version: $currentJsonVersion"
    Write-Host "[*] Current PHP version is: $currentPHPversion"
    Write-Host "[*] Current UNWDS version is: $currentUNWDSversion - $currentBuildNumber ($currentTarget), released in $currentReleasedDate"
    Write-Host "`n"
}

function CompareVersion {
    Write-Host "[*] Comparing version..."
    Write-Host "`n"
    if ($remotePHPversion -le $currentPHPversion) {
        Write-Host "[*] PHP already up-to-date (Server: $remotePHPversion - You have: $currentPHPversion)"
    } else {
        Write-Host "[*] PHP need update (Server: $remotePHPversion - You have: $currentPHPversion)"
        UpdatePHP
    }
    if ($remoteUNWDSversion -le $currentUNWDSversion) {
        Write-Host "[*] UNWDS already up-to-date (Server: $remoteUNWDSversion - You have: $currentUNWDSversion)"
    } else {
        Write-Host "[*] UNWDS need update (Server: $remoteUNWDSversion, released in $remoteReleasedDate - You have: $currentUNWDSversion, released in $currentReleasedDate)"
        UpdateUNWDS
    }
    UpdateVersionFile
    }

function CleanUp {
    Remove-Item ./* -Exclude installer.ps1 -Recurse -ErrorAction 'silentlycontinue'
}

function ErrorCleanUp {
    Clear-Host
    Write-Host "[ERR] Installation was failed because an error occurred";
    Write-Host "[*] Cleaning up files because installation errors...";
    Write-Host "`n"
    Remove-Item ./* -Exclude installer.ps1 -Recurse -ErrorAction 'silentlycontinue'
    Write-Host "Some file does not exist. UNWDS will not run if missing files. Please try to run install script again."
    $host.ui.RawUI.WindowTitle = "Windows PowerShell" #set the window title back to default
}

function Install {
    GetServerVersion
    Write-Host "[2/3] Downloading UNWDS v$remoteUNWDSversion ($remoteTarget), released in $remoteReleasedDate...";
    $DownloadURL = "https://github.com/$repo/releases/download/v$remoteUNWDSVersion/$file"
    Invoke-WebRequest $DownloadURL -Out $file
    #Write-Host $DownloadURL #Debugging only
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/UnnamedNetwork/UNWDS/stable/start.cmd" -OutFile "start.cmd"
    Write-Host "`n"
    Write-Host "[3/3] Downloading PHP $remotePHPVersion (Windows x64)...";
    Invoke-WebRequest -Uri "https://jenkins.pmmp.io/job/PHP-$remotePHPversion-Aggregate/lastSuccessfulBuild/artifact/PHP-$remotePHPversion-Windows-x64.zip" -OutFile "PHP-$remotePHPversion-Windows-x64.zip"
    Expand-Archive -LiteralPath PHP-$remotePHPversion-Windows-x64.zip -Force
    Get-ChildItem -Path "PHP-$remotePHPversion-Windows-x64" -Recurse |  Move-Item -Destination .
    Remove-Item PHP-$remotePHPversion-Windows-x64.zip -Force -erroraction 'silentlycontinue'
    Remove-Item PHP-$remotePHPversion-Windows-x64 -Recurse -Force -erroraction 'silentlycontinue'
    Write-Host "`n"
}
function UpdatePHP {
    Remove-Item PHP-$currentPHPversion-Windows-x64 -Recurse -Force -erroraction 'SilentlyContinue'
    Remove-Item PHP-$remotePHPversion-Windows-x64 -Recurse -Force -erroraction 'silentlycontinue'
    Remove-Item bin -Recurse -Force -erroraction 'silentlycontinue'
    Remove-Item PHP-$remotePHPversion-Windows-x64.zip -Force -erroraction 'silentlycontinue'
    Remove-Item PHP-$currentPHPversion-Windows-x64.zip -Force -erroraction 'silentlycontinue'
    Remove-Item vc_redist.x64.exe -erroraction 'silentlycontinue'
    Write-Host "[*] Updating PHP v$remotePHPversion (Windows x64)...";
    Invoke-WebRequest -Uri "https://jenkins.pmmp.io/job/PHP-$remotePHPversion-Aggregate/lastSuccessfulBuild/artifact/PHP-$remotePHPversion-Windows-x64.zip" -OutFile "PHP-$remotePHPversion-Windows-x64.zip"
    Expand-Archive -LiteralPath PHP-$remotePHPversion-Windows-x64.zip -Force
    Get-ChildItem -Path "PHP-$remotePHPversion-Windows-x64" -Recurse |  Move-Item -Destination .
    Remove-Item PHP-$remotePHPversion-Windows-x64.zip -Force -erroraction 'silentlycontinue'
    Remove-Item PHP-$remotePHPversion-Windows-x64 -Recurse -Force -erroraction 'silentlycontinue'
    Write-Host "[*] Update successfully!"
}

function UpdateUNWDS {
    $DownloadURL = "https://github.com/$repo/releases/download/v$remoteUNWDSVersion/$file"
    Remove-Item UNWDS.phar -Force -erroraction 'silentlycontinue'
    Remove-Item start.cmd -erroraction 'silentlycontinue'
    Write-Host "[*] Updating UNWDS v$remoteUNWDSversion";
    Invoke-WebRequest $DownloadURL -Out $file
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/UnnamedNetwork/UNWDS/stable/start.cmd" -OutFile "start.cmd"
    Write-Host "[*] Update successfully!"
}

function UpdateVersionFile {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/UnnamedNetwork/unnamednetwork.github.io/main/UNWDS/version_control/remoteVersion.json" -OutFile "remoteVersion.json"
    Remove-Item -Path $CurrentVPath -Force -erroraction 'silentlycontinue'
    Rename-Item -Path "remoteVersion.json" -NewName "currentVersion.json"
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
    Write-Host "[*] Everything done! Run ./start.cmd to start UNWDS";
    Write-Host "[*] Make sure you have installed Microsoft Visual C++ 2015-19 Redistributable (x64) on your PC.";
    Write-Host "[*] If not, you can run vc_redist.x64.exe in your cuurent folder to install it."
}

function StartScript {
    function PlatformCheck {
        if ([Environment]::Is64BitProcess -ne [Environment]::Is64BitOperatingSystem)
        {
            Write-Host "[ERR] You're running 32-bit system or you're run this UNWDS Installer in PowerShell (x86), these are not supported by UNWDS.";
            Write-Host "[ERR] Please consider upgrade to 64-bit system or use PowerShell (x64) to run UNWDS Installer.";
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
}
function Main {
    if (-not (Test-Path -Path currentVersion.json)) {
        Write-Host "`n"
        Write-Host "[*] Welcome to UNWDS Installer!";
        Write-Host "`n"
        Write-Host "[*] Windows x64 detected. Installing...";
        Write-Host "`n"
        Write-Host "[1/3] Cleaning up";
        Write-Host "`n"
        CleanUp
        Install
        CheckFiles
        UpdateVersionFile
        $host.ui.RawUI.WindowTitle = "Windows PowerShell" #set the window title back to default
    } else {
        Update
    }
}
StartScript