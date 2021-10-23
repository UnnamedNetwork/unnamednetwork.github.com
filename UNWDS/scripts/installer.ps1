#Requires -Version 5.1
# First, set PS's security protocol to TLS1.2 to avoid Github Releases download problems.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
#TODO: work at 'function as parameter'
$name = "UNWDS"

$scriptVersion = "2.3.1"
$host.ui.RawUI.WindowTitle = "$name Installer (v$scriptVersion)"

$IsWin = $PSVersionTable.Platform -match '^($|(Microsoft )?Win)'

$CurrentVPath = "$PSScriptRoot\currentVersion.json"

$Name = "UNWDS"
$file_name = "$Name.phar"
$ServerName = $Name
$LocalName = $Name



function GetServerVersion {
    Write-Host "[*] Contacting update server to get version..."
    Write-Host "`n"
    Add-Content -Path $PSScriptRoot/log.txt -Value "GetServerVersion activity log:"
    $remoteJsonData = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/UnnamedNetwork/unnamednetwork.github.io/main/UNWDS/update/api.json" -UseBasicParsing | ConvertFrom-Json
    Add-Content -Path $PSScriptRoot/log.txt -Value "Server JSON data:"
    Add-Content -Path $PSScriptRoot/log.txt -Value "$remoteJsonData"
    $Global:remoteTarget= $remoteJsonData.mcpe_version
    $Global:remoteUNWDSversion = $remoteJsonData.base_version
    $Global:remoteBuildNumber = $remoteJsonData.build
    $Global:remotePHPversion = $remoteJsonData.php_version
    $Global:downloadURL = $remoteJsonData.download_url
    $Global:remoteReleasedDate = $remoteJsonData.date
    $Global:ReleaseDetails = $remoteJsonData.details_url
    $Global:remoteHumanDate=(Get-Date 01.01.1970)+([System.TimeSpan]::fromseconds($remoteReleasedDate))
    Write-Host "[*] Server latest PHP version is: $remotePHPversion"
    Write-Host "[*] Server latest $ServerName version is: $remoteUNWDSversion - $remoteBuildNumber (for Minecraft: Bedrock Edition v$remoteTarget), released in $remoteHumanDate "
    Add-Content -Path $PSScriptRoot/log.txt -Value "Fetched download URL: $downloadURL"
    Add-Content -Path $PSScriptRoot/log.txt -Value "Fetched release details: $ReleaseDetails"
    Write-Host "`n"
}

function GetCurrentVersion {
    $currentJsonData = Get-Content $CurrentVPath | ConvertFrom-Json
    Add-Content -Path $PSScriptRoot/log.txt -Value "GetCurrentVersion activity log:"
    Add-Content -Path $PSScriptRoot/log.txt -Value "Current JSON data:"
    Add-Content -Path $PSScriptRoot/log.txt -Value "$currentJsonData"
    $Global:currentTarget = $currentJsonData.mcpe_version
    $Global:currentUNWDSversion = $currentJsonData.base_version
    $Global:currentBuildNumber = $currentJsonData.build
    $Global:currentPHPversion = $currentJsonData.php_version
    $Global:currentReleasedDate = $currentJsonData.date
    $Global:currentHumanDate=(Get-Date 01.01.1970)+([System.TimeSpan]::fromseconds($currentReleasedDate))
    Write-Host "[*] Current PHP version is: $currentPHPversion"
    Write-Host "[*] Current $LocalName version is: $currentUNWDSversion - $currentBuildNumber ($currentTarget), released in $currentHumanDate"
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
        Write-Host "[*] $ServerName already up-to-date (Server: $remoteUNWDSversion - You have: $currentUNWDSversion)"
    } else {
        Write-Host "[*] $ServerName need update (Server: $remoteUNWDSversion, released in $remoteHumanDate - You have: $currentUNWDSversion, released in $currentHumanDate)"
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
    $host.ui.RawUI.WindowTitle = "PowerShell" #set the window title back to default
}

function Install {
    Add-Content -Path $PSScriptRoot/log.txt -Value "Install log:"
    Write-Host "[2/3] Downloading $ServerName v$remoteUNWDSversion (for $remoteTarget), released in $remoteHumanDate...";
    Add-Content -Path $PSScriptRoot/log.txt -Value "Use download URL with file name: $downloadURL"
    Invoke-WebRequest -Uri $downloadURL -UseBasicParsing -OutFile "$file_name"
    Write-Host "Downloading $downloadURL" #Debugging only
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/UnnamedNetwork/UNWDS/stable/start.cmd" -UseBasicParsing -OutFile "$PSScriptRoot/start.cmd"
    Write-Host "`n"
    Write-Host "[3/3] Downloading PHP $remotePHPVersion (Windows x64)...";
    Invoke-WebRequest -Uri "https://jenkins.pmmp.io/job/PHP-$remotePHPversion-Aggregate/lastSuccessfulBuild/artifact/PHP-$remotePHPversion-Windows-x64.zip" -UseBasicParsing -OutFile "$PSScriptRoot/PHP-$remotePHPversion-Windows-x64.zip"
    Expand-Archive -LiteralPath $PSScriptRoot/PHP-$remotePHPversion-Windows-x64.zip -Force
    Get-ChildItem -Path "$PSScriptRoot/PHP-$remotePHPversion-Windows-x64" -Recurse |  Move-Item -Destination .
    Remove-Item $PSScriptRoot/PHP-$remotePHPversion-Windows-x64.zip -Force -erroraction 'silentlycontinue'
    Remove-Item $PSScriptRoot/PHP-$remotePHPversion-Windows-x64 -Recurse -Force -erroraction 'silentlycontinue'
    Write-Host "`n"
}
function UpdatePHP {
    Remove-Item $PSScriptRoot/PHP-$currentPHPversion-Windows-x64 -Recurse -Force -erroraction 'SilentlyContinue'
    Remove-Item $PSScriptRoot/PHP-$remotePHPversion-Windows-x64 -Recurse -Force -erroraction 'silentlycontinue'
    Remove-Item $PSScriptRoot/bin -Recurse -Force -erroraction 'silentlycontinue'
    Remove-Item $PSScriptRoot/PHP-$remotePHPversion-Windows-x64.zip -Force -erroraction 'silentlycontinue'
    Remove-Item $PSScriptRoot/PHP-$currentPHPversion-Windows-x64.zip -Force -erroraction 'silentlycontinue'
    Remove-Item vc_redist.x64.exe -erroraction 'silentlycontinue'
    Write-Host "[*] Updating PHP v$remotePHPversion (Windows x64)...";
    Invoke-WebRequest -Uri "https://jenkins.pmmp.io/job/PHP-$remotePHPversion-Aggregate/lastSuccessfulBuild/artifact/PHP-$remotePHPversion-Windows-x64.zip" -UseBasicParsing -OutFile "$PSScriptRoot/PHP-$remotePHPversion-Windows-x64.zip"
    Expand-Archive -LiteralPath $PSScriptRoot/PHP-$remotePHPversion-Windows-x64.zip -Force
    Get-ChildItem -Path "$PSScriptRoot/PHP-$remotePHPversion-Windows-x64" -Recurse |  Move-Item -Destination .
    Remove-Item $PSScriptRoot/PHP-$remotePHPversion-Windows-x64.zip -Force -erroraction 'silentlycontinue'
    Remove-Item $PSScriptRoot/PHP-$remotePHPversion-Windows-x64 -Recurse -Force -erroraction 'silentlycontinue'
    Write-Host "[*] Update successfully!"
}

function UpdateUNWDS {
    Add-Content -Path $PSScriptRoot/log.txt -Value "Update log:"
    Remove-Item $PSScriptRoot/$file_name -Force -erroraction 'silentlycontinue'
    Remove-Item start.cmd -erroraction 'silentlycontinue'
    Write-Host "[*] Updating UNWDS v$remoteUNWDSversion";
    Invoke-WebRequest -Uri $downloadURL -UseBasicParsing -OutFile "$file_name"
    Add-Content -Path $PSScriptRoot/log.txt -Value "Use download URL with file name: $downloadURL"
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/UnnamedNetwork/UNWDS/stable/start.cmd" -UseBasicParsing -OutFile "start.cmd" 
    Write-Host "[*] Update successfully!"
}

function UpdateVersionFile {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/UnnamedNetwork/unnamednetwork.github.io/main/UNWDS/update/api.json" -UseBasicParsing -OutFile "$PSScriptRoot/remoteVersion.json"
    Remove-Item -Path $CurrentVPath -Force -erroraction 'silentlycontinue'
    Rename-Item -Path "$PSScriptRoot/remoteVersion.json" -NewName "$PSScriptRoot/currentVersion.json"
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
    function 1stCheck { # First, will checking OS and current Powershell instance. 
        if ([Environment]::Is64BitProcess -ne [Environment]::Is64BitOperatingSystem)
        {
            Write-Host "[ERR] You're running 32-bit system or you're run this UNWDS Installer in PowerShell (x86), these are not supported by UNWDS.";
            Write-Host "[ERR] Please consider upgrade to 64-bit system or use PowerShell (x64) to run UNWDS Installer.";
            throw Unsupported current CPU or PowerShell instance (32bit).
        } 
        else
        {
        2ndCheck
        }
    }
    function 2ndCheck { #Second, check OS if whether is Windows or Linux/macOS
        if ($IsWin){
            Write-Host "[*] Windows detected. Continuing..."
            Main
        } else {
            Write-Host "[*] Linux/macOS detected, using bash script to install..."
            UnixInstall
        }
    }
    1stCheck
}
function Update {
    Write-Host "`n"
    Write-Host "[*] Seems $name has been installed on this directory. Checking for update...."
    Write-Host "`n"
    GetCurrentVersion
    GetServerVersion
    CompareVersion
    UpdateVersionFile
}
function Main {
    if (-not (Test-Path -Path currentVersion.json)) {
        Write-Host "`n"
        Write-Host "[*] Welcome to $name Installer!";
        Write-Host "`n"
        Write-Host "[*] Windows x64 detected. Installing...";
        Write-Host "`n"
        Write-Host "[1/3] Cleaning up";
        Write-Host "`n"
        CleanUp
        GetServerVersion
        Install
        CheckFiles
        UpdateVersionFile
        $host.ui.RawUI.WindowTitle = "PowerShell" #set the window title back to default
    } else {
        Update
    }
}

function UnixInstall { #need to test later, currently I don't have any linux/macos machine...
    Invoke-WebRequest -Uri https://unnamednetwork.github.io/UNWDS/scripts/installer.sh -UseBasicParsing -OutFile "$PSScriptRoot/installer.sh"
    bash ./installer.sh
}

StartScript
