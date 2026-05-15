@echo off

call vars.bat

SET "BAKLIST=list.txt"
SET "EXECARCH="C:\Python34\python.exe" "arch.py""
SET "EXECRBCP=robocopy.exe"
SET "DSTDIR=M:"


set "COMMAND=%~1"

if "%COMMAND%"=="" (
    echo ERROR: Need a command.
    exit /b 1
)


EVENTCREATE /L APPLICATION /T INFORMATION /SO "1S backup" /ID 995 /D "Начало архивирования локальных баз 1С (%COMMAND%)"

%EXECARCH%  "%BAKLIST%"  "%DSTDIR%"  "%COMMAND%"


REM %EXECARCH%  "%BAKLIST%"  "%DSTDIR%"  once dontclean


EVENTCREATE /L APPLICATION /T INFORMATION /SO "1S backup" /ID 995 /D "Завершено архивирование локальных баз 1С (%COMMAND%)"

net use "%REMOTEDIR%" "/user:%REMOTEUSER%" "%REMOTEPASS%"

EVENTCREATE /L APPLICATION /T INFORMATION /SO "1S backup" /ID 995 /D "Начало копирования архивов в хранилище (%COMMAND%)"

%EXECRBCP% "%DSTDIR%" "%REMOTEDIR%" /E /COPY:D /R:3 /W:5 /XD "RECYCLER" "System Volume Information"

EVENTCREATE /L APPLICATION /T INFORMATION /SO "1S backup" /ID 995 /D "Завершено копирование архивов в хранилище (%COMMAND%)"

net use "%REMOTEDIR%" /delete /yes

EVENTCREATE /L APPLICATION /T INFORMATION /SO "1S backup" /ID 995 /D "Сетевая папка отключена, выходим (%COMMAND%)"

exit /b 0
