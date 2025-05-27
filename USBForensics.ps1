# Script para detectar arquivos copiados/movidos para pendrives
# Versão simplificada e funcional

param(
    [int]$Dias = 1,
    [string]$SalvarEm = ""
)

function Get-PendrivesConectados {
    Write-Host "Verificando pendrives conectados..." -ForegroundColor Yellow
    $drives = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { 
        $_.DriveType -eq 2 -and $_.Size -gt 0 
    }
    
    if ($drives) {
        Write-Host "Pendrives encontrados:" -ForegroundColor Green
        foreach ($drive in $drives) {
            $tamanho = [math]::Round($drive.Size / 1GB, 2)
            Write-Host "  → $($drive.DeviceID) - $($drive.VolumeName) ($tamanho GB)" -ForegroundColor Cyan
        }
        return $drives.DeviceID
    } else {
        Write-Host "Nenhum pendrive detectado no momento." -ForegroundColor Red
        return @()
    }
}

function Get-HistoricoArquivos {
    param([string[]]$DrivesPendrive, [int]$Dias)
    
    $resultados = @()
    $dataInicio = (Get-Date).AddDays(-$Dias)
    
    Write-Host "`nAnalisando atividade de arquivos..." -ForegroundColor Yellow
    
    # Verificar arquivos recentes nos pendrives
    foreach ($drive in $DrivesPendrive) {
        if (Test-Path $drive) {
            Write-Host "Analisando drive $drive..." -ForegroundColor Gray
            
            try {
                $arquivos = Get-ChildItem -Path $drive -Recurse -File -ErrorAction SilentlyContinue | 
                           Where-Object { 
                               $_.CreationTime -gt $dataInicio -or 
                               $_.LastWriteTime -gt $dataInicio 
                           } |
                           Select-Object -First 100
                
                foreach ($arquivo in $arquivos) {
                    $resultados += [PSCustomObject]@{
                        DataHora = $arquivo.CreationTime
                        UltimaModificacao = $arquivo.LastWriteTime
                        Arquivo = $arquivo.Name
                        CaminhoCompleto = $arquivo.FullName
                        Tamanho = $arquivo.Length
                        Drive = $drive
                        Status = if ($arquivo.CreationTime -gt $dataInicio) { "Copiado" } else { "Modificado" }
                    }
                }
            } catch {
                Write-Warning "Erro ao acessar $drive - Pode estar protegido ou desconectado"
            }
        }
    }
    
    # Verificar logs do Windows (Event Viewer)
    Write-Host "Verificando logs do sistema..." -ForegroundColor Gray
    
    try {
        # Eventos de dispositivos USB
        $eventosUSB = Get-WinEvent -FilterHashtable @{
            LogName = 'System'
            StartTime = $dataInicio
            ID = 20001, 20003, 6416
        } -ErrorAction SilentlyContinue -MaxEvents 50
        
        foreach ($evento in $eventosUSB) {
            if ($evento.Message -match "USB" -or $evento.Message -match "removable") {
                $resultados += [PSCustomObject]@{
                    DataHora = $evento.TimeCreated
                    UltimaModificacao = $evento.TimeCreated
                    Arquivo = "Evento USB"
                    CaminhoCompleto = $evento.Message
                    Tamanho = 0
                    Drive = "Sistema"
                    Status = "Dispositivo conectado/desconectado"
                }
            }
        }
    } catch {
        Write-Warning "Não foi possível acessar todos os logs do sistema"
    }
    
    # Verificar histórico do Explorer (arquivos recentes)
    Write-Host "Verificando arquivos recentes do Windows..." -ForegroundColor Gray
    
    $recentPath = "$env:APPDATA\Microsoft\Windows\Recent"
    if (Test-Path $recentPath) {
        $arquivosRecentes = Get-ChildItem -Path $recentPath -Filter "*.lnk" -ErrorAction SilentlyContinue |
                           Where-Object { $_.CreationTime -gt $dataInicio } |
                           Select-Object -First 20
        
        foreach ($link in $arquivosRecentes) {
            # Tentar obter o caminho real do arquivo
            try {
                $shell = New-Object -ComObject WScript.Shell
                $shortcut = $shell.CreateShortcut($link.FullName)
                $caminhoReal = $shortcut.TargetPath
                
                # Verificar se aponta para um pendrive
                foreach ($drive in $DrivesPendrive) {
                    if ($caminhoReal -like "$drive*") {
                        $resultados += [PSCustomObject]@{
                            DataHora = $link.CreationTime
                            UltimaModificacao = $link.LastWriteTime
                            Arquivo = [System.IO.Path]::GetFileName($caminhoReal)
                            CaminhoCompleto = $caminhoReal
                            Tamanho = 0
                            Drive = $drive
                            Status = "Acessado recentemente"
                        }
                    }
                }
            } catch {
                # Ignorar links inválidos
            }
        }
    }
    
    return $resultados | Sort-Object DataHora -Descending
}

function Show-Relatorio {
    param($Dados, [string]$ArquivoSaida = "")
    
    if ($Dados.Count -eq 0) {
        Write-Host "`nNenhuma atividade de arquivo detectada nos pendrives." -ForegroundColor Yellow
        return
    }
    
    $relatorio = @"
================================================================
         RELATORIO DE ATIVIDADE EM PENDRIVES
================================================================
Data da analise: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')
Periodo analisado: Ultimos $Dias dias
Total de itens encontrados: $($Dados.Count)

"@
    
    $dadosAgrupados = $Dados | Group-Object Drive
    
    foreach ($grupo in $dadosAgrupados) {
        $relatorio += "`n" + "="*60 + "`n"
        $relatorio += "DRIVE: $($grupo.Name)`n"
        $relatorio += "="*60 + "`n"
        
        foreach ($item in $grupo.Group) {
            $tamanhoMB = if ($item.Tamanho -gt 0) { 
                [math]::Round($item.Tamanho / 1MB, 2).ToString() + " MB" 
            } else { 
                "N/A" 
            }
            
            $relatorio += @"
Data/Hora: $($item.DataHora.ToString('dd/MM/yyyy HH:mm:ss'))
Status: $($item.Status)
Arquivo: $($item.Arquivo)
Caminho: $($item.CaminhoCompleto)
Tamanho: $tamanhoMB
Ultima modificacao: $($item.UltimaModificacao.ToString('dd/MM/yyyy HH:mm:ss'))
$("-" * 50)

"@
        }
    }
    
    $relatorio += "`n" + "="*60 + "`n"
    $relatorio += "Fim do relatorio`n"
    
    Write-Host $relatorio
    
    if ($ArquivoSaida) {
        try {
            $relatorio | Out-File -FilePath $ArquivoSaida -Encoding UTF8 -Force
            Write-Host "Relatorio salvo em: $ArquivoSaida" -ForegroundColor Green
        } catch {
            Write-Error "Erro ao salvar arquivo: $_"
        }
    }
}

# Execução principal
Clear-Host
Write-Host @"
================================================================
    DETECTOR DE ARQUIVOS EM PENDRIVES
================================================================
"@ -ForegroundColor Cyan

# Detectar pendrives
$drives = Get-PendrivesConectados

if ($drives.Count -eq 0) {
    Write-Host "`nNenhum pendrive conectado. Conecte um pendrive e execute novamente." -ForegroundColor Red
    Write-Host "Pressione qualquer tecla para sair..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

# Analisar atividade
$atividades = Get-HistoricoArquivos -DrivesPendrive $drives -Dias $Dias

# Mostrar relatório
Show-Relatorio -Dados $atividades -ArquivoSaida $SalvarEm

Write-Host @"


"@ -ForegroundColor Gray

Write-Host "`nPressione qualquer tecla para sair..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")