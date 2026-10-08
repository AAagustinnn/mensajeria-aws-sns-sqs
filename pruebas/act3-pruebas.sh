#!/usr/bin/env bash
# Actividad 3 - seccion 4. Uso: bash act3-pruebas.sh colas|pausa|reanudar|dlq-llenar|dlq-reprocesar
API=${API:-http://localhost:8080}; H="Content-Type: application/json"
case "$1" in
  colas)
    curl -X POST   $API/admin/colas/cliente-101-q; echo
    curl           $API/admin/colas/cliente-101-q; echo
    read -p "Toma la captura en la consola SQS y presiona Enter para eliminarla..."
    curl -X DELETE $API/admin/colas/cliente-101-q; echo ;;
  pausa)
    curl -X POST $API/admin/listener/pausar; echo
    for i in 1 2 3 4 5; do curl -s -X POST $API/ordenes -H "$H" -d "{\"id\":\"p$i\",\"cliente\":\"Cliente 2\",\"monto\":1000}"; echo; done
    echo "Mira el panel: 5 en cola sin procesarse. Luego: bash act3-pruebas.sh reanudar" ;;
  reanudar)
    curl -X POST $API/admin/listener/reanudar; echo ;;
  dlq-llenar)   # con mensajeria.simular-fallo=true
    curl -X POST $API/ordenes -H "$H" -d '{"id":"r1","cliente":"Cliente 1","monto":5000}'; echo
    curl -X POST $API/ordenes -H "$H" -d '{"id":"r2","cliente":"Cliente 2","monto":-5}'; echo
    echo "Espera ~30-40 s (3 intentos x visibility 10 s) a que r1 llegue a la DLQ." ;;
  dlq-reprocesar)  # despues de poner simular-fallo=false y reiniciar
    curl -X POST $API/admin/dlq/reprocesar; echo ;;
  *) echo "uso: $0 colas|pausa|reanudar|dlq-llenar|dlq-reprocesar" ;;
esac
