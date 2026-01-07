@echo off
setlocal Enabledelayedexpansion
title Find Fileimage 
set "InstallFile="
for %%i in (C D E F G H I J K L M N O P Q R S T U V W Y Z) do (
    if exist "%%i:\sources\install.esd" (
        set "InstallFile=%%i:\sources\install.esd"
        goto :FoundSource
    )
    if exist "%%i:\sources\install.wim" (
        set "InstallFile=%%i:\sources\install.wim"
        goto :FoundSource
    )
)
:FoundSource
if "%InstallFile%"=="" (
    echo no install.esd or install.wim found on any drive.
    pause
    exit
)
echo Found installation file: %InstallFile%
title list disks n sel disk to install windows
(echo list disk & echo exit) | diskpart
set /p disknum=Select disk number to install Windows:
if "%disknum%"=="" goto :Error

echo You selected disk %disknum%
title cleaning and partitioning disk %disknum%


echo Select option to install Windows:
echo 1. Full GPT + Part NTFS Windows
echo 2. Full GPT + Part NTFS Windows + Part NTFS Data
set /p option=Choose 1 or 2:
if "%option%"=="1" goto :Option1
if "%option%"=="2" goto :Option2
goto :Error
:Option1
(
    echo Cleaning and partitioning disk %disknum% for Windows only...
    (
        echo select disk %disknum%
        echo clean
        echo convert gpt
        echo create partition efi size=512
        echo format quick fs=fat32 label="System"
        echo assign letter="S"
        echo create partition primary
        echo format quick fs=ntfs label="Windows"
        echo assign letter="W"
        echo exit
    ) | diskpart

    echo Applying Windows image to disk %disknum%...
    dism /Apply-Image /ImageFile:%InstallFile% /Index:1 /ApplyDir:W:\
    
    echo Configuring boot files...
    bcdboot W:\Windows /s S: /f UEFI

    echo Installation complete. You can now reboot into Windows.
    pause
    exit
)


:Error
echo Invalid input. Exiting...