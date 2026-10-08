#!/usr/bin/env bash
# Crea toda la infraestructura AWS de las Actividades 2 y 3 (region us-east-1).
# Uso (terminal del Learner Lab, CloudShell o tu PC con AWS CLI y las credenciales exportadas):
#   bash crear-infra.sh tu_correo@ejemplo.com
set -euo pipefail

EMAIL="${1:-}"
export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="$AWS_REGION"
TMP="$(mktemp -d)"

echo "==> 1. ordenes-dlq (retencion 14 dias). Se crea primero: SQS no la crea por ti."
DLQ_URL=$(aws sqs create-queue --queue-name ordenes-dlq \
  --attributes MessageRetentionPeriod=1209600 --query QueueUrl --output text)
DLQ_ARN=$(aws sqs get-queue-attributes --queue-url "$DLQ_URL" \
  --attribute-names QueueArn --query Attributes.QueueArn --output text)
echo "    $DLQ_ARN"

echo "==> 2. ordenes-q (visibility 10 s, DLQ ordenes-dlq, maxReceiveCount 3)"
cat > "$TMP/ordenes-q.json" <<JSON
{
  "VisibilityTimeout": "10",
  "RedrivePolicy": "{\"deadLetterTargetArn\":\"$DLQ_ARN\",\"maxReceiveCount\":\"3\"}"
}
JSON
Q_URL=$(aws sqs create-queue --queue-name ordenes-q \
  --attributes "file://$TMP/ordenes-q.json" --query QueueUrl --output text)
echo "    $Q_URL"

echo "==> 3. Experimento: prueba-ttl-q (retencion 60 s, DLQ ordenes-dlq) + 1 mensaje"
cat > "$TMP/ttl.json" <<JSON
{
  "MessageRetentionPeriod": "60",
  "RedrivePolicy": "{\"deadLetterTargetArn\":\"$DLQ_ARN\",\"maxReceiveCount\":\"3\"}"
}
JSON
TTL_URL=$(aws sqs create-queue --queue-name prueba-ttl-q \
  --attributes "file://$TMP/ttl.json" --query QueueUrl --output text)
aws sqs send-message --queue-url "$TTL_URL" --message-body "mensaje de prueba TTL" >/dev/null
echo "    Mensaje enviado a prueba-ttl-q. Revisa la cola y la DLQ en 2-3 minutos."

echo "==> 4. Topico SNS alertas-dlq"
TOPIC_ARN=$(aws sns create-topic --name alertas-dlq --query TopicArn --output text)
echo "    $TOPIC_ARN"
if [ -n "$EMAIL" ]; then
  aws sns subscribe --topic-arn "$TOPIC_ARN" --protocol email --notification-endpoint "$EMAIL" >/dev/null
  echo "    Suscripcion email creada para $EMAIL -> CONFIRMA EL CORREO que te llega de AWS."
else
  echo "    (Sin correo: ejecuta de nuevo con tu email como argumento para suscribirte)"
fi

echo "==> 5. Alarma CloudWatch dlq-ordenes-con-mensajes"
aws cloudwatch put-metric-alarm \
  --alarm-name dlq-ordenes-con-mensajes \
  --alarm-description "Hay ordenes en la DLQ ordenes-dlq" \
  --namespace AWS/SQS --metric-name ApproximateNumberOfMessagesVisible \
  --dimensions Name=QueueName,Value=ordenes-dlq \
  --statistic Maximum --period 60 --evaluation-periods 1 \
  --threshold 0 --comparison-operator GreaterThanThreshold \
  --treat-missing-data notBreaching \
  --alarm-actions "$TOPIC_ARN"

rm -rf "$TMP"
echo
echo "Listo. Colas:"
aws sqs list-queues --output table
