@ECHO OFF
CALL %LOCALAPPDATA%\PragNAStic\pragnastic-conf.bat
SET LOCKFILE=%LOCALAPPDATA%\Temp\.pragnastic.syncdrive.lock

IF NOT EXIST "%LOCKFILE%" (
    @copy nul %LOCKFILE% >nul
    echo Starting sync with unison profile %UNISON_PROFILE%
    %UNISON_EXECUTABLE% %UNISON_PROFILE% -ui text -batch
    del %LOCKFILE%
) ELSE (
    echo WARNING: Sync skipped, lockfile %LOCKFILE% already exists
)
