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

:: --- BƯỚC 1: Lấy dung lượng ổ cứng từ Diskpart ---
set "dSize="
set "dUnit="
set "totalMB=0"

:: Lấy thông tin Size và Unit (GB/MB)
for /f "tokens=4,5" %%a in ('echo list disk ^| diskpart ^| find "Disk %disknum%"') do (
    set "dSize=%%a"
    set "dUnit=%%b"
)

:: Kiểm tra nếu không lấy được thông tin
if "%dSize%"=="" (
    echo Error: Could not detect disk size.
    pause
    goto :Error
)

:: --- QUAN TRỌNG: Lọc bỏ dấu chấm (.) và dấu phẩy (,) ---
:: Điều này giúp tránh lỗi ". was unexpected" nếu số có dạng 40.5 hoặc 1.000
set "dSize=!dSize:.=!"
set "dSize=!dSize:,=!"

:: --- BƯỚC 2: Quy đổi ra MB ---
if /i "%dUnit%"=="GB" (
    set /a totalMB=!dSize!*1024
) else (
    set /a totalMB=!dSize!
)

echo Detected Disk Size (Integer): !totalMB! MB

:: --- BƯỚC 3: Tính toán chia đôi ---
:: Công thức: (Tổng MB - 512 MB EFI) / 2
set /a partSize=(!totalMB!-512)/2

:: Kiểm tra an toàn: Nếu tính ra nhỏ hơn 10GB thì báo lỗi
if !partSize! lss 10000 (
    echo Error: Partition size too small (!partSize! MB). Check disk size.
    pause
    goto :Error
)

echo Windows Partition Target: !partSize! MB

:: --- BƯỚC 4: Thực thi Diskpart ---
(
    echo select disk %disknum%
    echo clean
    echo convert gpt
    
    REM Tạo phân vùng EFI 512MB
    echo create partition efi size=512
    echo format quick fs=fat32 label="System"
    echo assign letter="S"
    
    REM Tạo phân vùng Windows (Size đã tính ở trên)
    echo create partition primary size=!partSize!
    echo format quick fs=ntfs label="Windows"
    echo assign letter="W"
    
    REM Tạo phân vùng Data (Phần còn lại)
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

:Error
echo Invalid input. Exiting...