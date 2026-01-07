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
:Option2
setlocal EnableDelayedExpansion
echo Cleaning and partitioning disk %disknum% for Windows (50%%) and Data (50%%)...

REM --- FIX: Dùng PowerShell để lấy dung lượng MB vì CMD không tính được số Bytes quá lớn ---
set "diskSizeMB="
for /f "usebackq" %%A in (`powershell -command "[math]::Round((Get-Disk -Number %disknum%).Size / 1MB)"`) do set "diskSizeMB=%%A"

if "%diskSizeMB%"=="" (
    echo Error: Could not determine disk size. PowerShell may be missing or disk is invalid.
    pause
    exit /b
)

REM --- Tính toán chia đôi ổ cứng: (Tổng MB - 512MB EFI) chia 2 ---
REM Lưu ý: set /a chỉ hoạt động tốt nếu ổ cứng nhỏ hơn 2TB (2 triệu MB).
set /a windowsSizeMB=(diskSizeMB-512)/2

echo Disk Size: %diskSizeMB% MB
echo Windows Partition Target: %windowsSizeMB% MB

if %windowsSizeMB% lss 20480 (
    echo Calculated Windows partition too small (%windowsSizeMB% MB). Exiting...
    pause
    exit /b
)

REM
(
    echo select disk %disknum%
    echo clean
    echo convert gpt
    echo create partition efi size=512
    echo format quick fs=fat32 label="System"
    echo assign letter="S"
    echo create partition primary size=%windowsSizeMB%
    echo format quick fs=ntfs label="Windows"
    echo assign letter="W"
    echo create partition primary
    echo format quick fs=ntfs label="Data"
    echo assign letter="D"
    echo exit
) | diskpart

echo Applying Windows image to disk %disknum%...
dism /Apply-Image /ImageFile:%InstallFile% /Index:1 /ApplyDir:W:\

echo Configuring boot files...
bcdboot W:\Windows /s S: /f UEFI

echo Installation complete. You can now reboot into Windows.
pause
exit
@REM :Option2
@REM ( setlocal EnableDelayedExpansion
@REM     echo Cleaning and partitioning disk %disknum% for Windows (50%%) and Data (50%%)...

@REM     rem Get disk size in bytes using WMIC (available in WinPE/Windows Setup)
@REM     for /f "tokens=2 delims==" %%s in ('wmic diskdrive where "index=%disknum%" get size /value ^| find "="') do set "diskSizeBytes=%%s"
@REM     if not defined diskSizeBytes (
@REM         echo Could not determine disk size. Exiting...
@REM         exit /b 1
@REM     )

@REM     rem Convert to MB and split the free space (subtract 512 MB for EFI)
@REM     set /a diskSizeMB=diskSizeBytes/1024/1024
@REM     set /a windowsSizeMB=(diskSizeMB-512)/2
@REM     if %windowsSizeMB% lss 20480 (
@REM         echo Calculated Windows partition too small (%windowsSizeMB% MB). Exiting...
@REM         exit /b 1
@REM     )

@REM     (
@REM         echo select disk %disknum%
@REM         echo clean
@REM         echo convert gpt
@REM         echo create partition efi size=512
@REM         echo format quick fs=fat32 label="System"
@REM         echo assign letter="S"
@REM         echo create partition primary size=!windowsSizeMB!
@REM         echo format quick fs=ntfs label="Windows"
@REM         echo assign letter="W"
@REM         echo create partition primary
@REM         echo format quick fs=ntfs label="Data"
@REM         echo assign letter="D"
@REM         echo exit
@REM     ) | diskpart

@REM     echo Applying Windows image to disk %disknum%...
@REM     dism /Apply-Image /ImageFile:%InstallFile% /Index:1 /ApplyDir:W:\
    
@REM     echo Configuring boot files...
@REM     bcdboot W:\Windows /s S: /f UEFI

@REM     echo Installation complete. You can now reboot into Windows.
@REM     pause
@REM     exit
@REM  )
:Error
echo Invalid input. Exiting...