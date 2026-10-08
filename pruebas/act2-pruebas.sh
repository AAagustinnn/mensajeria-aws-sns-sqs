#!/usr/bin/env bash
# Actividad 2 - seccion 4. Requiere la app corriendo en 8080.
API=${API:-http://localhost:8080}
H="Content-Type: application/json"
echo "--- 1) Orden normal: /ordenes (segundo plano) vs /ordenes/sync"
curl -w "\n%{time_total}s\n" -X POST $API/ordenes      -H "$H" -d '{"id":"1","cliente":"Cliente 2","monto":9990}'
curl -w "\n%{time_total}s\n" -X POST $API/ordenes/sync -H "$H" -d '{"id":"2","cliente":"Cliente 2","monto":9990}'
echo "--- 2) Falla transitoria (servicio caido)"
curl -X POST $API/ordenes      -H "$H" -d '{"id":"3","cliente":"Cliente 1","monto":15000}'; echo
curl -X POST $API/ordenes/sync -H "$H" -d '{"id":"4","cliente":"Cliente 1","monto":15000}'; echo
echo "--- 3) Falla definitiva (monto invalido)"
curl -X POST $API/ordenes -H "$H" -d '{"id":"5","cliente":"Cliente 2","monto":-5}'; echo
echo "--- 4) Duplicado"
curl -X POST $API/ordenes -H "$H" -d '{"id":"1","cliente":"Cliente 2","monto":9990}'; echo
