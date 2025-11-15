@echo off
REM ============================================
REM Create Admin User
REM ============================================

echo.
echo ================================================
echo  Create Admin User
echo ================================================
echo.

REM Activate virtual environment
if exist "venv\Scripts\activate.bat" (
    call venv\Scripts\activate.bat
) else (
    echo [ERROR] Virtual environment not found
    echo Please run run_app.bat first
    pause
    exit /b 1
)

REM Run Flask CLI command
flask create-admin

echo.
pause