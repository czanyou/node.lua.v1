:: Created by npm, please don't edit manually.
@ECHO OFF

SETLOCAL

SET "NODE_EXE=%~dp0\lnode.exe"
IF NOT EXIST "%NODE_EXE%" (
  SET "NODE_EXE=lnode"
)

SET "NPM_CLI_JS=%~dp0\lpm"

"%NODE_EXE%" "%NPM_CLI_JS%" %*
