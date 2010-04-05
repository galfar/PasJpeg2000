@echo OFF
echo Deleting ugly files...

set ROOTDIR=..
set EXTS=*.dcu *.ppu *.a *.dpu *.o *.rst *.bak *.bk? *.~* *.*~ *.or *.obj
set EXTS=%EXTS% *.tgs *.tgw *.identcache *.local *.stat *.cfg *.dsk

call :DELINDIR %ROOTDIR%\
call :DELINTREE %ROOTDIR%\Samples
goto :END

:DELINDIR
  pushd %1
  echo Processing dir: %1
  del /q /f %EXTS% 2>nul 1>nul
  popd
goto :EOF 

:DELINTREE
  pushd %1
  echo Processing dir tree: %1
  del /q /f /s %EXTS% 2>nul 1>nul
  popd
goto :EOF


:END
echo Clean finished
