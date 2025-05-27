# USBForensics
Este script analisa a atividade de arquivos em dispositivos USB removíveis, identificando arquivos que foram copiados ou modificados em um período específico. Útil para auditoria de segurança e controle de dados.

## 🚀 Recursos
- ✅ Detecção automática de pendrives
- 📊 Estatísticas detalhadas
- 🎯 Categorização de arquivos
- 📋 Relatórios exportáveis
- 🔍 Análise de logs do sistema

## 🚀 Recursos Profissionais:

✅ Documentação completa com .SYNOPSIS, .DESCRIPTION, .EXAMPLE

✅ Parâmetros validados e com help

✅ Tratamento robusto de erros

✅ Interface visual com emojis e cores

✅ Estatísticas detalhadas por categoria e dispositivo

✅ Categorização automática de arquivos

✅ Progress feedback para operações longas

## 🚀 Funcionalidades Avançadas:

📊 Estatísticas: Por categoria, dispositivo e tamanho

🎯 Categorização: Imagens, vídeos, documentos, etc.

📋 Relatórios: Simples ou detalhados

💾 Export: Salvar em arquivo de texto

🔍 Logs do Sistema: Análise de eventos USB

⚡ Performance: Processamento otimizado


## 📖 Como usar
```powershell
# Análise básica (último dia)
.\USBFileMonitor.ps1

# Últimos 7 dias com detalhes
.\USBFileMonitor.ps1 -Dias 7 -Detalhado

# Salvar relatório
.\USBFileMonitor.ps1 -SalvarEm "relatorio.txt"
```

## 🔧 Requisitos

* PowerShell 5.0+
* Windows 10/11
* Execute como Admin para melhor precisão

