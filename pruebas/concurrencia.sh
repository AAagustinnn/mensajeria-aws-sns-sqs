#!/usr/bin/env bash
# Act. 2 sec. 7 / Act. 3 sec. 1:  bash concurrencia.sh <prefijo> <cantidad>
# ej: bash concurrencia.sh c 10   |   bash concurrencia.sh d 10   |   bash concurrencia.sh r 20
P=${1:-c}; N=${2:-10}; API=${API:-http://localhost:8080}
for i in $(seq 1 $N); do
  curl -s -X POST $API/ordenes -H "Content-Type: application/json" \
    -d "{\"id\":\"$P$i\",\"cliente\":\"Cliente 2\",\"monto\":1000}"; echo
done
