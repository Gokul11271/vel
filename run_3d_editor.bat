@echo off
echo ===================================================
echo   Starting 3D Map Node Creator (Three.js)
echo ===================================================

cd /d "D:\vel"
echo Serving 3D Editor on http://localhost:3000 ...
start http://localhost:3000
python -m http.server 3000
pause
