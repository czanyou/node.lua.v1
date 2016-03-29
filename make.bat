
cmake -H. -Bbuild/win32

cmake --build build/win32 --config Release

copy build\win32\Release\lnode.exe bin\lnode.exe

pause
