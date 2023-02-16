@ECHO OFF
CALL %LOCALAPPDATA%\PragNAStic\pragnastic-config.bat

net use %NETDRIVE_LOCAL% /delete
net use %SHAREDDRIVE_LOCAL% /delete
