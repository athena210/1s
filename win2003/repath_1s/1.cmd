@echo off

chcp 1251
SET "EXEC="C:\Python34\python.exe" "repath.py""

REM ====== REPLACE =======
REM %EXEC%	V:\1sdb\a7\B\		T:\1sdb\a7b\
REM %EXEC%	http://oldserver/dir/base1		http://cloud/base1

REM ====== JUST SEARCH =======
REM %EXEC%	http://oldserver		http://oldserver
REM %EXEC%	ldserv		ldserv

echo =====================



REM %EXEC% L:\1sdb\p K:\1sdb\p

echo =====================
pause
