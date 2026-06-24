@echo off
title DATAGO Development Server
echo ===================================================
echo   DATAGO - Starting Django Development Server
echo ===================================================
echo.
echo Menghubungi server lokal... 
echo Silakan buka browser Anda di: http://127.0.0.1:8000/
echo.
echo Tekan Ctrl+C di terminal ini untuk mematikan server.
echo ===================================================
echo.

python manage.py runserver

pause
