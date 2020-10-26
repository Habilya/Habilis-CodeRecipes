
rem This script outputs paths of all files foound in folders and subfolders with filessize less than 1kb.
@echo off & for /R "E:\PATH\TO\FOLDER" %A in (*.*) do if %~zA LSS 1024 echo %~fA