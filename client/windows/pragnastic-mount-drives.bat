@ECHO OFF
CALL %LOCALAPPDATA%\PragNAStic\pragnastic-conf.bat

net use %NETDRIVE_LOCAL% %NETDRIVE_REMOTE%
net use %SHAREDDRIVE_LOCAL% %SHAREDDRIVE_REMOTE%
