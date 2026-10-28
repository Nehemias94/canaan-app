@echo off
REM Abre la app Canaan en Google Chrome con doble clic (para ir viendo como queda mientras se programa)
REM Esta ventana NO se debe cerrar mientras se usa: en ella se pulsan las teclas r (actualizar), R (reiniciar) y q (apagar)

REM Titulo de la ventana (para reconocerla en la barra de tareas)
title Canaan - App en Chrome

REM Se ubica en la carpeta donde esta este archivo (canaan_app), aunque se abra desde otro lugar
cd /d "%~dp0"

REM Agrega Flutter a la lista de programas conocidos (solo para esta ventana)
set "PATH=C:\src\flutter\bin;%PATH%"

REM Explica las teclas antes de arrancar
echo.
echo  ===============================================
echo   App Canaan - se abrira en Chrome en 1 o 2 min
echo  ===============================================
echo.
echo   En ESTA ventana puedes pulsar:
echo     r  = ver los cambios nuevos al instante
echo     R  = reiniciar la app completa
echo     q  = apagar la app
echo.
echo   Vista de telefono en Chrome: F12 y luego Ctrl+Shift+M
echo.

REM Arranca la app en Chrome ("call" para que la ventana siga abierta al terminar Flutter)
call flutter run -d chrome

REM Cuando la app se apaga (tecla q o error), espera una tecla antes de cerrar la ventana (asi se puede leer cualquier mensaje)
echo.
echo  La app se apago. Pulsa una tecla para cerrar esta ventana.
pause > nul
