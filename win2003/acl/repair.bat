@echo off

chcp 1251
call vars.bat


SET "EXEC="C:\Python34\python.exe" "acl.py""

EVENTCREATE /L APPLICATION /T INFORMATION /SO "1S ACL" /ID 995 /D "Начат процесс восстановления ACL [1]"
%EXEC%  repair "%ROOTDIR1%" "%ACLDIR%"

EVENTCREATE /L APPLICATION /T INFORMATION /SO "1S ACL" /ID 995 /D "Завершен процесс восстановления ACL"

REM %EXEC%  clean "%ROOTDIR1%" "%ROOTDIR2%" "%ROOTDIR99%" %ACLDIR% 
%EXEC%  clean "%ROOTDIR1%"  "%ACLDIR%"


REM pause
