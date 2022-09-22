@ECHO OFF

REM Lets delete some shadows
ECHO This script will attempt to delete volume shadows
PAUSE

vssadmin.exe delete shadows /all

