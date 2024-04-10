@echo off
chcp 65001
COLOR 0B
cd %~dp0
cls

set windows_filer_sti="%~dp0windowsfiler"
set verksted_filer_sti="%~dp0verkstedfiler"

:: Sjekk om skript er kjørt som admin.
set adminguid=%random%%random%-%random%-%random%-%random%-%random%%random%%random%
mkdir %windir%\%adminguid%>nul 2>&1
rmdir %windir%\%adminguid%>nul 2>&1

if %errorlevel% neq 0 (
	echo.
	echo 	Kjør skriptet på nytt som admin.
	echo.
	pause
	exit
)

echo.
echo	VIKTIGE STEG - LES OG VERIFISER.
echo.
echo 	1. Husk å kopiere ut evt. nyeste verkstedfiler til verkstedfiler mappen slik at den er oppdatert.
echo 	   Hvis det er første gang du lager et USB verktøy, kan du bare la den være tom.
echo.
echo 	2. Opprett Windows 11 ISO fil med MCT, skriv til USB via Rufus (for å få tweaks), 
echo 	   Kopier dermed alt derfra til windowsfiler mappen.
echo.
echo 	3. Sørg for at ThronicPE.wim ligger i samme mappe som dette skriptet.
echo.
echo 	4. Ta ut og inn USB brikke som skal lages (hvis du brukte den i steg 2).
echo.
echo 	5. Fortsett dette skriptet...
echo.
pause
cls

:: Sjekk at PE ligger klart.
if not exist "ThronicPE.wim" (
	echo.
	echo 	Sjekk at ThronicPE.wim eksisterer i samme mappe!
	echo.
	pause
	exit
)

:diskvalg
set usb_brikke_disknr=ingenvalg
(echo List Disk) | diskpart
echo.
echo.
echo 	Hvilket disk nummer skal bli ny USB brikke? 
echo 	!!!! VÆR VÅKEN HER !!!!
echo.
set /p usb_brikke_disknr=:
cls

if %usb_brikke_disknr%==0 (
	echo.
	echo 	Jeg kan nesten garantere at 0 ikke er USB disken! Prøv igjen...
	echo.
	pause
	goto diskvalg
)

if [%usb_brikke_disknr%]==[ingenvalg] (
	echo.
	echo 	Du må angi et valg.
	echo.
	pause
	goto diskvalg
)

echo.
echo 	Sjekk at stasjonsbokstavene O: og V: ikke brukes til noe annet enn USB brikken.
echo.
echo 	Ved å gå videre forsøkes det å opprette en GPT basert USB oppstartsbar brikke for UEFI.
echo 	Denne vil ha 2 partisjoner; en med windows setup og en for verktøyfiler og diverse.
echo. 
echo 	Bootpartisjonen kan veksle mellom boot.wim filer med bytt_boot_modus.cmd
echo 	Dette kan f.eks. brukes via shift+F10 hvis man booter fra windows setup boot.wim,
echo 	og tilbake igjen ved å dobbeltklikke bytt_boot_modus.cmd mens man er i ThronicPE.
echo.
echo 	Partisjoner som opprettes:
echo 	FAT32 - 10GB Bootpartisjon med bytt_boot_modus skript.
echo 	NTFS - Resten av ledig plass til verktøy og ymse.
echo.
pause


:: Kode for opprettelse av USB brikke.
:diskpart
set diskpartok=0
(echo sel disk %usb_brikke_disknr%
echo clean
echo convert gpt
echo create par pri size=10000
echo format fs=fat32 quick label=USBBOOT
echo assign letter O
echo create par pri
echo format fs=ntfs quick label=USBVERKTOY
echo assign letter V
) | diskpart


:: Vent litt sånn at bokstaver får våknet skikkelig.
timeout /t 3 /nobreak
set /p diskpartok=Ser det greit ut ovenfor? (Ignorer evt. melding om MBR) ([ENTER] = OK, [N] = Prøv på nytt):
if [%diskpartok%]==[n] goto diskpart
if [%diskpartok%]==[N] goto diskpart

:: Opprett bytt_boot_modus skript i boot partisjonen.
echo Oppretter bytt_boot_modus.cmd skript på USB ...
(echo @echo off
echo :: Hvis ThronicPE.wim finnes, byttes det til det og antas at eksisterende er windows setup boot og vice versa.
echo if exist sources\ThronicPE.wim (
echo 	move "sources\boot.wim" "sources\boot_win.wim"
echo 	move "sources\ThronicPE.wim" "sources\boot.wim"
echo 	echo.
echo 	echo Byttet til ThronicPE.
echo 	echo.
echo ^) else (
echo 	move "sources\boot.wim" "sources\ThronicPE.wim"
echo 	move "sources\boot_win.wim" "sources\boot.wim"
echo 	echo.
echo 	echo Byttet til Windows Setup.
echo 	echo.
echo ^)
echo pause
) > O:\bytt_boot_modus.cmd

:: Kopier ThronicPE boot.wim fil til O.
echo Kopierer ThronicPE til USB ...
mkdir O:\sources
ROBOCOPY %~dp0 "O:\sources" "ThronicPE.wim"

:: Splitter install.esd i tilfelle den er for stor.
:: Sjekk at PE ligger klart.
if not exist "%windows_filer_sti%\sources\install.swm" (
	echo Splitter install.esd i mindre deler før kopiering og kopierer den til WinRE mappen for fremtidig WinRE utpakking etter behov ...
	dism /split-image /imagefile:%windows_filer_sti%\sources\install.esd /SWMFile:%windows_filer_sti%\sources\install.swm /filesize:2048
	move %windows_filer_sti%\sources\install.esd %verksted_filer_sti%\WinRE\
)

:: Kopier windowsfiler til O.
echo Kopierer windowsfiler til USB ...
ROBOCOPY %windows_filer_sti% "O:" /E

:: Kopier verkstedfiler til V.
echo Kopierer verkstedfiler til USB ...
ROBOCOPY %verksted_filer_sti% "V:" /E

:: Putt thingy i verktoy partisjonen.
echo På denne partisjonen kan du putte hva som helst, verkstedfiler etc. > V:\info.txt

echo.
echo.
echo 	Ferdig!
echo.
echo 	Du kan nå bytte mellom ThronicPE og Windows Setup oppstart med bytt_boot_modus.cmd
echo 	Denne ligger vanligvis på D:\ når/hvis du bruker shift+f10 CMD i Windows Setup.
echo.
echo.
pause