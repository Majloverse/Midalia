@echo off
rem Downloads the chat model the game needs for texting (2.5 GB). Double-click this file.
rem It is too big for GitHub, so it comes from Hugging Face, where it is published.
rem Safe to run again: a finished download is left alone, an interrupted one carries on.
setlocal
set "NAME=gemma-3-4b-it-Q4_K_M.gguf"
set "FILE=%~dp0models\%NAME%"
set "URL=https://huggingface.co/ggml-org/gemma-3-4b-it-GGUF/resolve/main/%NAME%"
set "SHA=882e8d2db44dc554fb0ea5077cb7e4bc49e7342a1f0da57901c0802ea21a0863"

if not exist "%~dp0models" mkdir "%~dp0models"

if exist "%FILE%" (
	echo Found %NAME%. Checking it is complete...
	call :check && goto done
	echo It is not complete. Carrying on with the download.
)

echo Downloading %NAME% (2.5 GB). This takes a while.
curl.exe -L --fail -C - -o "%FILE%" "%URL%"
if errorlevel 1 (
	echo.
	echo The download stopped. Run this file again to carry on from where it got to.
	goto fail
)

echo Checking the download...
call :check && goto done
echo.
echo The file does not match what was expected. Delete models\%NAME% and run this again.
goto fail

:done
echo.
echo The chat model is ready. Start the game with play.bat.
pause
exit /b 0

:fail
pause
exit /b 1

:check
certutil -hashfile "%FILE%" SHA256 | findstr /i /x "%SHA%" >nul
exit /b %errorlevel%
