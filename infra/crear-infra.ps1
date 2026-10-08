# Version PowerShell de crear-infra.sh (requiere AWS CLI v2 en Windows).
# Antes define $env:AWS_ACCESS_KEY_ID, $env:AWS_SECRET_ACCESS_KEY, $env:AWS_SESSION_TOKEN
# Uso:  .\crear-infra.ps1 -Email tu_correo@ejemplo.com
param([string]$Email = "")
$ErrorActionPreference = "Stop"
$env:AWS_DEFAULT_REGION = "us-east-1"
$tmp = New-Item -ItemType Directory -Path (Join-Path $env:TEMP ("infra-" + [guid]::NewGuid()))

Write-Host "==> 1. ordenes-dlq (retencion 14 dias)"
$dlqUrl = aws sqs create-queue --queue-name ordenes-dlq --attributes MessageRetentionPeriod=1209600 --query QueueUrl --output text
$dlqArn = aws sqs get-queue-attributes --queue-url $dlqUrl --attribute-names QueueArn --query Attributes.QueueArn --output text
Write-Host "    $dlqArn"

function Write-Attrs($path, $extra) {
  $redrive = (@{ deadLetterTargetArn = $dlqArn; maxReceiveCount = "3" } | ConvertTo-Json -Compress)
  $extra["RedrivePolicy"] = $redrive
  $extra | ConvertTo-Json | Set-Content -Path $path -Encoding ascii
}

Write-Host "==> 2. ordenes-q (visibility 10 s, DLQ, maxReceiveCount 3)"
$f1 = Join-Path $tmp "ordenes-q.json"; Write-Attrs $f1 @{ VisibilityTimeout = "10" }
aws sqs create-queue --queue-name ordenes-q --attributes "file://$f1" --query QueueUrl --output text

Write-Host "==> 3. prueba-ttl-q (retencion 60 s) + 1 mensaje"
$f2 = Join-Path $tmp "ttl.json"; Write-Attrs $f2 @{ MessageRetentionPeriod = "60" }
$ttlUrl = aws sqs create-queue --queue-name prueba-ttl-q --attributes "file://$f2" --query QueueUrl --output text
aws sqs send-message --queue-url $ttlUrl --message-body "mensaje de prueba TTL" | Out-Null

Write-Host "==> 4. Topico SNS alertas-dlq"
$topicArn = aws sns create-topic --name alertas-dlq --query TopicArn --output text
if ($Email) {
  aws sns subscribe --topic-arn $topicArn --protocol email --notification-endpoint $Email | Out-Null
  Write-Host "    Suscripcion creada para $Email -> CONFIRMA EL CORREO"
}

Write-Host "==> 5. Alarma CloudWatch dlq-ordenes-con-mensajes"
aws cloudwatch put-metric-alarm --alarm-name dlq-ordenes-con-mensajes `
  --namespace AWS/SQS --metric-name ApproximateNumberOfMessagesVisible `
  --dimensions Name=QueueName,Value=ordenes-dlq `
  --statistic Maximum --period 60 --evaluation-periods 1 `
  --threshold 0 --comparison-operator GreaterThanThreshold `
  --treat-missing-data notBreaching --alarm-actions $topicArn

Remove-Item -Recurse -Force $tmp
aws sqs list-queues --output table
