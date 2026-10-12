@echo off
cd /d "%~dp0"
if exist "CrownCourt.exe" (
  start "" "CrownCourt.exe"
) else if exist "build\crown-court-0.13.0\CrownCourt.exe" (
  start "" "build\crown-court-0.13.0\CrownCourt.exe"
) else (
  echo Crown Court has not been built yet. See crown-court\README.md.
  pause
)
