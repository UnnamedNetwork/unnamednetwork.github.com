#Requires -Version 5.1
# First, set PS's security protocol to TLS1.2 to avoid Github Releases download problems.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$CHANNEL="stable"
$BRANCH="stable"
$NAME="UNWDS"
$BUILD_URL=""
$FILENAME="$NAME.phar"

# we'll port these function later, first we will focus on porting some default functions of the script.
# $update="off"
# $forcecompile="off"
# $alldone="no"
$checkAdmin="off" #checkRoot in the original script.
# $alternateurl="off"

$INSTALL_DIRECTORY="./"
#$IGNORE_CERT="no"

if ([Environment]::Is64BitOperatingSystem) {
} 
else {
    Write-Host "[ERROR] PocketMine-MP is no longer supported on 32-bit systems.";
    exit 1
}

#certificate things, Windows just need to use Invoke-WebRequest, skipped port determine function using 'wget' or 'curl' like *nix.
#set alias for later use.
Set-Alias -Name download_file -Value "Invoke-WebRequest"

if ( "$checkAdmin" -eq "on" ) {
	if ( [bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")) { # thank to https://superuser.com/questions/749243/detect-if-powershell-is-running-as-administrator
		Write-Output "This script is running as administrator, this is discouraged."
		Write-Output "It is recommended to run it as a normal user as it doesn't need further permissions."
		#Write-Output "If you want to run it as administrator, add the -r flag."
		exit 1
    }
}

if ( "$CHANNEL" -eq "soft" ) {
    $NAME="PocketMine-Soft"
}

if ( "$BUILD_URL", "$CHANNEL" -eq "", "custom"){
    $BASE_VERSION="custom"
	$BUILD="unknown"
	$VERSION_DATE_STRING="unknown"
	#$ENABLE_GPG="no"
	$VERSION_DOWNLOAD="$BUILD_URL"
	$MCPE_VERSION="unknown"
	$PHP_VERSION="unknown"
} else {
    Write-Output "[*] Retrieving latest build data for channel: $CHANNEL"
    Write-Output "`n"
    $VERSION_DATA = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/UnnamedNetwork/unnamednetwork.github.io/main/UNWDS/update/api.json" -UseBasicParsing | ConvertFrom-Json
    if ( "$VERSION_DATA" -eq "" ){
        $error_detail="Parse JSON data $VERSION_DATA error."
        if ( $error_detail -eq "" ){
            Write-Output "`n"
            Write-Output "[!] Failed to get download information: $error_detail"
            exit 1
        }
    }
    $BASE_VERSION = $VERSION_DATA.base_version
    $BUILD = $VERSION_DATA.build
    $MCPE_VERSION = $VERSION_DATA.mcpe_version
    $PHP_VERSION = $VERSION_DATA.php_version
    $VERSION_DATE = $VERSION_DATA.date
    $VERSION_DOWNLOAD = $VERSION_DATA.download_url

    # In PocketMine-MP *nix installer, they determine what OS/distro the script run on, to use the epoch time converter correctly
    # But in Windows, we just use Windows, so port the OS check is not mandatory.

    $VERSION_DATE_STRING=(Get-Date 01.01.1970)+([System.TimeSpan]::fromseconds($VERSION_DATE))

    # GPG key/certificate things, skipped

    if ( "$BASE_VERSION" -eq "" ) {
    Write-Output "`n"
    Write-Host "[!] Couldn't get the latest $NAME version"
    exit 1
    # Another GPG key/certificate things, skipped
    # } else {
    #     Write-Output "`n"
    #     Write-Output "[!] Failed to download version information: Empty response from API"
	# 	  exit 1
    # } # I don't know why this is not working as expected. Commented out.
    }
}

Write-Output "`n"
Write-Output "[*] Found $NAME $BASE_VERSION (build $BUILD) for Minecraft: PE v$MCPE_VERSION (PHP $PHP_VERSION)"
Write-Output "[*] This $CHANNEL build was released on $VERSION_DATE_STRING"

# Another GPG key/certificate things, skipped

Write-Output "`n"
Write-Output "[*] Installing/updating $NAME on directory $INSTALL_DIRECTORY"
Write-Output "`n"
Write-Output "[1/3] Cleaning..."
Remove-Item "$NAME.phar" -Force -ErrorAction 'silentlycontinue' #avoid this file not exist.
Remove-Item bin -Force -Recurse -ErrorAction 'silentlycontinue'
Remove-Item vc_redist.x64.exe -Force -ErrorAction 'silentlycontinue'
Remove-Item README.md -Force -ErrorAction 'silentlycontinue'
Remove-Item CONTRIBUTING.md -Force -ErrorAction 'silentlycontinue'
Remove-Item LICENSE -Force -ErrorAction 'silentlycontinue'
Remove-Item CMNOTES -Force -ErrorAction 'silentlycontinue'
Remove-Item start.sh -Force -ErrorAction 'silentlycontinue'
Remove-Item start.cmd -Force -ErrorAction 'silentlycontinue'

#Old installations
Remove-Item PocketMine-MP.php -Force -ErrorAction 'silentlycontinue'
Remove-Item src -Force -Recurse -ErrorAction 'silentlycontinue'

Write-Output "`n"
Write-Output -n "[2/3] Downloading $NAME phar..."
download_file "$VERSION_DOWNLOAD" -UseBasicParsing -OutFile "$FILENAME"
if (Test-Path -Path UNWDS.phar){
} else {
    Write-Output "`n"
	Write-Output "Failed!"
	Write-Output "[!] Couldn't download $NAME automatically from $VERSION_DOWNLOAD"
	exit 1
}

# hacks
$pharContent = Get-Content "$FILENAME" -Tail 1
if ( "$pharContent" -eq "<!DOCTYPE html>" ) {
    Remove-Item "$NAME.phar" -Force -ErrorAction 'silentlycontinue'
    Write-Output "`n"
	Write-Output " Failed!"
	Write-Output "[!] Couldn't download $NAME automatically from $VERSION_DOWNLOAD"
	exit 1
} else {
    if ( "$CHANNEL" -eq "soft" ){
        download_file "https://raw.githubusercontent.com/UnnamedNetwork/UNWDS-alt/${BRANCH}/resources/start.cmd" -UseBasicParsing -OutFile "start.cmd"
    }else{
        download_file "https://raw.githubusercontent.com/UnnamedNetwork/UNWDS/${BRANCH}/start.cmd" -UseBasicParsing -OutFile "start.cmd"
    }
    download_file "https://raw.githubusercontent.com/UnnamedNetwork/UNWDS/${BRANCH}/LICENSE" -UseBasicParsing -OutFile "LICENSE"
    download_file "https://raw.githubusercontent.com/UnnamedNetwork/UNWDS/${BRANCH}/README.md" -UseBasicParsing -OutFile "README.md"
    download_file "https://raw.githubusercontent.com/UnnamedNetwork/UNWDS/${BRANCH}/CMNOTES" -UseBasicParsing -OutFile "CMNOTES"
}

# Another GPG key/certificate things, skipped

# Because we're using Windows, we don't need to determine OS for PHP download. So we just need to download it and configure timezone.
# Update task skipped. In here we just download and install.

Write-Output "`n"
Write-Host "[3/3] Downloading PHP $PHP_VERSION (Windows x64)...";
download_file "https://jenkins.pmmp.io/job/PHP-$PHP_VERSION-Aggregate/lastSuccessfulBuild/artifact/PHP-$PHP_VERSION-Windows-x64.zip" -UseBasicParsing -OutFile "$PSScriptRoot/PHP-$PHP_VERSION-Windows-x64.zip"
Expand-Archive -LiteralPath $PSScriptRoot/PHP-$PHP_VERSION-Windows-x64.zip -Force
Get-ChildItem -Path "$PSScriptRoot/PHP-$PHP_VERSION-Windows-x64" -Recurse |  Move-Item -Destination .
Remove-Item $PSScriptRoot/PHP-$PHP_VERSION-Windows-x64.zip -Force -erroraction 'silentlycontinue'
Remove-Item $PSScriptRoot/PHP-$PHP_VERSION-Windows-x64 -Recurse -Force -erroraction 'silentlycontinue'
Write-Output "`n"
Write-Output "[*] Testing downloaded PHP..."
$PHP_TEST_DIGIT = ./bin/php/php.exe -r "echo 1;"
if ( "$PHP_TEST_DIGIT" -eq "1" ) {
    Write-Output "[OK] Done"
} else {
    Write-Output "`n"
	Write-Output "Failed!"
	Write-Output "[!] Couldn't download PHP $PHP_VERSION automatically"
    exit 1
}


Write-Output "`n"
Write-Output "[*] Everything done! Run ./start.cmd to start $NAME"
Write-Host "[*] Make sure you have installed Microsoft Visual C++ 2015-19 Redistributable (x64) on your PC.";
Write-Host "[*] If not, you can run vc_redist.x64.exe in your cuurent folder to install it."
exit 0
