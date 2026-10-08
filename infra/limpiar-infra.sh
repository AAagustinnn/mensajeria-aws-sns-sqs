#!/usr/bin/env bash
# Elimina colas, topico y alarma creados en el bloque (seccion "Limpieza").
set -uo pipefail
export AWS_DEFAULT_REGION="${AWS_REGION:-us-east-1}"
aws cloudwatch delete-alarms --alarm-names dlq-ordenes-con-mensajes && echo "alarma eliminada"
for q in ordenes-q ordenes-dlq prueba-ttl-q cliente-101-q; do
  url=$(aws sqs get-queue-url --queue-name "$q" --query QueueUrl --output text 2>/dev/null) \
    && aws sqs delete-queue --queue-url "$url" && echo "cola $q eliminada"
done
arn=$(aws sns list-topics --query "Topics[?ends_with(TopicArn, ':alertas-dlq')].TopicArn" --output text)
[ -n "$arn" ] && aws sns delete-topic --topic-arn "$arn" && echo "topico alertas-dlq eliminado"
