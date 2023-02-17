@ECHO OFF

SET NETDRIVE_LOCAL=N:
SET NETDRIVE_REMOTE=\\sshfs.kr\alice@example.com/vol/data/alice/netdrive

SET SHAREDDRIVE_LOCAL=S:
SET SHAREDDRIVE_REMOTE=\\sshfs.kr\alice@example.com/vol/data/shared

SET UNISON_EXECUTABLE=C:\"Program Files"\Unison\bin\unison.exe
SET UNISON_PROFILE=alice
