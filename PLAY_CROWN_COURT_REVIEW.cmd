@echo off
setlocal
set "GAME=%~dp0build\crown-court-0.12.0\CrownCourt.exe"
if /I "%PROCESSOR_ARCHITECTURE%"=="x86" if not defined PROCESSOR_ARCHITEW6432 set "GAME=%~dp0build\crown-court-0.12.0\CrownCourt32.exe"
start "Crown Court review" "%GAME%"
