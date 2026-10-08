# Version PowerShell de las pruebas (Windows).  Uso:  .\pruebas.ps1 act2 | concurrencia c 10 | colas | pausa | reanudar | dlq-llenar | dlq-reprocesar
param([string]$Caso = "act2", [string]$Prefijo = "c", [int]$N = 10)
$API = "http://localhost:8080"
function Orden($id, $cliente, $monto, $ruta = "/ordenes") {
  $body = @{ id = $id; cliente = $cliente; monto = $monto } | ConvertTo-Json
  $sw = [Diagnostics.Stopwatch]::StartNew()
  try { $r = Invoke-RestMethod -Method Post -Uri "$API$ruta" -ContentType "application/json" -Body $body }
  catch { $r = "ERROR " + $_.Exception.Response.StatusCode.value__ + " " + $_.ErrorDetails.Message }
  "{0}  ({1:N3}s)" -f $r, $sw.Elapsed.TotalSeconds
}
switch ($Caso) {
  "act2" {
    "--- Normal";      Orden "1" "Cliente 2" 9990; Orden "2" "Cliente 2" 9990 "/ordenes/sync"
    "--- Transitoria"; Orden "3" "Cliente 1" 15000; Orden "4" "Cliente 1" 15000 "/ordenes/sync"
    "--- Definitiva";  Orden "5" "Cliente 2" -5
    "--- Duplicado";   Orden "1" "Cliente 2" 9990
  }
  "concurrencia" { 1..$N | ForEach-Object { Orden "$Prefijo$_" "Cliente 2" 1000 } }
  "colas" {
    Invoke-RestMethod -Method Post   "$API/admin/colas/cliente-101-q"
    Invoke-RestMethod                "$API/admin/colas/cliente-101-q"
    Read-Host "Captura la consola SQS y presiona Enter para eliminar"
    Invoke-RestMethod -Method Delete "$API/admin/colas/cliente-101-q"
  }
  "pausa"    { Invoke-RestMethod -Method Post "$API/admin/listener/pausar"; 1..5 | ForEach-Object { Orden "p$_" "Cliente 2" 1000 } }
  "reanudar" { Invoke-RestMethod -Method Post "$API/admin/listener/reanudar" }
  "dlq-llenar"     { Orden "r1" "Cliente 1" 5000; Orden "r2" "Cliente 2" -5 }
  "dlq-reprocesar" { Invoke-RestMethod -Method Post "$API/admin/dlq/reprocesar" }
}
