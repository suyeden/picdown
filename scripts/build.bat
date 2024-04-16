@echo off

set current_dir=%CD%
set script_dir=%~dp0
cd %script_dir%\..\lib

if exist .\eprintf.dll (
   del .\eprintf.dll
)

gcc -I ./ -shared -o eprintf.dll eprintf.c

cd %script_dir%\..\

if exist .\release (
   rmdir /S /Q .\release
)

mkdir .\release
mkdir .\release\picdown
mkdir .\release\picdown\lib

copy .\bin\picdown.bat .\release\picdown.bat
copy .\configs\picdown.txt .\release\picdown.txt
copy .\src\picdown.el .\release\picdown\picdown.el
copy .\lib\eprintf.dll .\release\picdown\lib\eprintf.dll
copy .\lib\master-lib.el .\release\picdown\lib\master-lib.el

powershell compress-archive .\release\* .\release\picdown

cd %current_dir%
