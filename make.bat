
cmake -H. -Bbuild/win32

cmake --build build/win32 --config Release

copy %CD%\build\win32\Release\lnode.exe %CD%\bin
copy %CD%\build\win32\Release\lua53.dll %CD%\bin
copy %CD%\build\win32\Release\lmbedtls.dll %CD%\bin
copy %CD%\build\win32\Release\lsqlite.dll %CD%\bin