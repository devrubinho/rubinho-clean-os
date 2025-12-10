# 🧹 Rubinho Clean OS

<div align="center">

![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)
![macOS](https://img.shields.io/badge/macOS-000000?style=for-the-badge&logo=apple&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)

**Professional disk space analysis and cleanup scripts for Linux and macOS**

[🇺🇸](#-english) • [🇧🇷](#-português)

</div>

---

## 🇺🇸 English

> Professional disk space analysis and cleanup scripts for **Linux** and **macOS**. Analyze what's taking up space and safely clean development caches, temporary files, and more.

### 🚀 Quick Start

#### 1. Clone the repository

```bash
git clone https://github.com/devrubinho/rubinho-clean-os.git
cd rubinho-clean-os
```

#### 2. Use the Interactive Menu (Recommended)

The easiest way to get started is using the main `run.sh` script:

```bash
bash run.sh
```

This will show you an interactive menu with options to:
- 📊 **Analyze disk space**: See what's taking up space on your system
- 🧹 **Clean up files**: Remove unnecessary files and free up space

**Command-line options:**
```bash
bash run.sh --force      # Skip all confirmation prompts
bash run.sh --verbose    # Enable verbose logging
bash run.sh --help       # Show help message
```

#### 3. Manual Usage (Alternative)

If you prefer to run scripts manually:

**🐧 Linux:**
```bash
# Analyze disk space
./linux/scripts/utils/analyze_space.sh

# Clean up files
./linux/scripts/utils/clean_space.sh
```

**🍎 macOS:**
```bash
# Analyze disk space
./macos/scripts/utils/analyze_space.sh

# Clean up files
./macos/scripts/utils/clean_space.sh
```

---

### 🌟 Features

**📊 Space Analysis (`analyze_space.sh`)**
- Interactive configuration: choose how many items to analyze (10-500, default: 50)
- Top largest folders and files in your system
- Per-user breakdown (home directory, caches, trash, logs, Xcode data)
- Development artifacts count (`node_modules`, `.next`, `dist`, Python caches, etc.)
- Color-coded ranking (top items in red, medium in yellow, rest in blue)
- System-wide cleanup summary with Docker status
- Disk space summary with capacity, used, and available space

**🧹 Space Cleanup (`clean_space.sh`)**
- **Docker**: All containers, images, volumes, and networks (with confirmation)
- **Node.js/JavaScript**: All `node_modules`, `.next`, `dist`, `build` folders, and build caches
- **Python**: `__pycache__`, `.venv`, `venv`, `.pytest_cache`, and compiled files
- **Xcode** (macOS only): DerivedData, old archives, caches, old logs
- **System**: All user trash bins, application caches, system logs, temporary files
- **Development Tools**: Package manager caches (npm, pip, apt, yum, dnf, pacman)
- **Preview mode**: See what will be deleted before confirming
- **Logging**: Optional log file generation for audit trail

#### 📋 Requirements

- **Linux** or **macOS** (any recent version)
- **Bash** (pre-installed on both systems)
- **sudo access** (for system-wide operations)

#### 🚀 Usage

**Analyze Disk Space:**
```bash
# Using the interactive menu (recommended)
bash run.sh
# Then select option 1

# Or run directly (Linux)
./linux/scripts/utils/analyze_space.sh
sudo ./linux/scripts/utils/analyze_space.sh  # For complete system analysis

# Or run directly (macOS)
./macos/scripts/utils/analyze_space.sh
sudo ./macos/scripts/utils/analyze_space.sh  # For complete system analysis
```

**Clean Disk Space:**
```bash
# Using the interactive menu (recommended)
bash run.sh
# Then select option 2

# Or run directly (Linux)
./linux/scripts/utils/clean_space.sh              # Current user only
sudo ./linux/scripts/utils/clean_space.sh         # All users
./linux/scripts/utils/clean_space.sh --dry-run    # Preview only
./linux/scripts/utils/clean_space.sh --log        # Save log to file

# Or run directly (macOS)
./macos/scripts/utils/clean_space.sh              # Current user only
sudo ./macos/scripts/utils/clean_space.sh         # All users
./macos/scripts/utils/clean_space.sh --dry-run    # Preview only
./macos/scripts/utils/clean_space.sh --log        # Save log to file
```

⚠️ **Warning**: The cleanup script will remove development files! Projects will need to reinstall dependencies (`npm install`, etc.) after cleanup.

#### 🛡️ Safety Features

- ✅ Confirmation required before any deletion
- ✅ Shows exactly what will be removed before proceeding
- ✅ Per-user separation
- ✅ OS verification (macOS scripts only run on macOS, Linux scripts only run on Linux)
- ✅ Detailed logging of freed space
- ✅ Keeps essential system files
- ✅ Dry-run mode to preview changes

---

### 📁 Repository Structure

```
rubinho-clean-os/
├── LICENSE                  # MIT License
├── README.md               # This file
├── run.sh                  # Main interactive menu
│
├── lib/                    # Shared modules
│   ├── cleanup_preview.sh # Cleanup preview system
│   ├── disk_analysis.sh   # Disk analysis module
│   ├── logging.sh         # Logging functionality
│   └── platform.sh        # Platform detection
│
├── linux/                  # 🐧 Linux scripts
│   └── scripts/
│       └── utils/
│           ├── analyze_space.sh
│           └── clean_space.sh
│
└── macos/                  # 🍎 macOS scripts
    └── scripts/
        └── utils/
            ├── analyze_space.sh
            └── clean_space.sh
```

---

### 🐛 Troubleshooting

#### Scripts won't run
**Problem:** `Permission denied` when running scripts

**Solution:**
```bash
chmod +x run.sh
chmod +x linux/scripts/utils/*.sh
chmod +x macos/scripts/utils/*.sh
```

#### Analysis takes too long
**Problem:** Script seems to hang during analysis

**Solution:**
- Run with `sudo` for faster access to system directories
- The script is processing large directories, be patient
- You can interrupt with `Ctrl+C` if needed
- Reduce the number of items to analyze (the script will prompt you)

#### Cleanup didn't free much space
**Problem:** Cleanup completed but space freed is minimal

**Solution:**
- Run analysis first to see what's taking up space
- Some files may be protected or in use
- Try running with `sudo` for system-wide cleanup
- Use `--dry-run` first to preview what will be cleaned

#### Script fails with "Platform detection module not found"
**Problem:** Error when running `run.sh`

**Solution:**
- Make sure you're running from the repository root directory
- Verify that `lib/platform.sh` exists
- Check that all files were cloned correctly

---

### 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🇧🇷 Português

> Scripts profissionais de análise e limpeza de espaço em disco para **Linux** e **macOS**. Analise o que está ocupando espaço e limpe com segurança caches de desenvolvimento, arquivos temporários e muito mais.

### 🚀 Início Rápido

#### 1. Clonar o repositório

```bash
git clone https://github.com/devrubinho/rubinho-clean-os.git
cd rubinho-clean-os
```

#### 2. Usar o Menu Interativo (Recomendado)

A forma mais fácil de começar é usar o script principal `run.sh`:

```bash
bash run.sh
```

Isso mostrará um menu interativo com opções para:
- 📊 **Analisar espaço em disco**: Veja o que está ocupando espaço no seu sistema
- 🧹 **Limpar arquivos**: Remova arquivos desnecessários e libere espaço

**Opções de linha de comando:**
```bash
bash run.sh --force      # Pular todos os prompts de confirmação
bash run.sh --verbose    # Habilitar logging verboso
bash run.sh --help       # Mostrar mensagem de ajuda
```

#### 3. Uso Manual (Alternativa)

Se preferir executar os scripts manualmente:

**🐧 Linux:**
```bash
# Analisar espaço em disco
./linux/scripts/utils/analyze_space.sh

# Limpar arquivos
./linux/scripts/utils/clean_space.sh
```

**🍎 macOS:**
```bash
# Analisar espaço em disco
./macos/scripts/utils/analyze_space.sh

# Limpar arquivos
./macos/scripts/utils/clean_space.sh
```

---

### 🌟 Funcionalidades

**📊 Análise de Espaço (`analyze_space.sh`)**
- Configuração interativa: escolha quantos itens analisar (10-500, padrão: 50)
- Top maiores pastas e arquivos do sistema
- Análise por usuário (diretório home, caches, lixeira, logs, dados do Xcode)
- Contagem de artefatos de desenvolvimento (`node_modules`, `.next`, `dist`, caches Python, etc.)
- Classificação com cores (top itens em vermelho, médios em amarelo, resto em azul)
- Resumo de limpeza em todo o sistema com status do Docker
- Resumo de espaço em disco com capacidade, usado e disponível

**🧹 Limpeza de Espaço (`clean_space.sh`)**
- **Docker**: Todos os containers, imagens, volumes e redes (com confirmação)
- **Node.js/JavaScript**: Todas as pastas `node_modules`, `.next`, `dist`, `build` e caches de build
- **Python**: `__pycache__`, `.venv`, `venv`, `.pytest_cache` e arquivos compilados
- **Xcode** (apenas macOS): DerivedData, arquivos antigos, caches, logs antigos
- **Sistema**: Todas as lixeiras de usuário, caches de aplicativos, logs do sistema, arquivos temporários
- **Ferramentas de Desenvolvimento**: Caches de gerenciadores de pacotes (npm, pip, apt, yum, dnf, pacman)
- **Modo preview**: Veja o que será deletado antes de confirmar
- **Logging**: Geração opcional de arquivo de log para auditoria

#### 📋 Requisitos

- **Linux** ou **macOS** (qualquer versão recente)
- **Bash** (pré-instalado em ambos os sistemas)
- **Acesso sudo** (para operações em todo o sistema)

#### 🚀 Uso

**Analisar Espaço em Disco:**
```bash
# Usando o menu interativo (recomendado)
bash run.sh
# Depois selecione a opção 1

# Ou executar diretamente (Linux)
./linux/scripts/utils/analyze_space.sh
sudo ./linux/scripts/utils/analyze_space.sh  # Para análise completa do sistema

# Ou executar diretamente (macOS)
./macos/scripts/utils/analyze_space.sh
sudo ./macos/scripts/utils/analyze_space.sh  # Para análise completa do sistema
```

**Limpar Espaço em Disco:**
```bash
# Usando o menu interativo (recomendado)
bash run.sh
# Depois selecione a opção 2

# Ou executar diretamente (Linux)
./linux/scripts/utils/clean_space.sh              # Apenas usuário atual
sudo ./linux/scripts/utils/clean_space.sh         # Todos os usuários
./linux/scripts/utils/clean_space.sh --dry-run    # Apenas visualizar
./linux/scripts/utils/clean_space.sh --log        # Salvar log em arquivo

# Ou executar diretamente (macOS)
./macos/scripts/utils/clean_space.sh              # Apenas usuário atual
sudo ./macos/scripts/utils/clean_space.sh         # Todos os usuários
./macos/scripts/utils/clean_space.sh --dry-run    # Apenas visualizar
./macos/scripts/utils/clean_space.sh --log        # Salvar log em arquivo
```

⚠️ **Aviso**: O script de limpeza removerá arquivos de desenvolvimento! Os projetos precisarão reinstalar dependências (`npm install`, etc.) após a limpeza.

#### 🛡️ Recursos de Segurança

- ✅ Confirmação necessária antes de qualquer exclusão
- ✅ Mostra exatamente o que será removido antes de prosseguir
- ✅ Separação por usuário
- ✅ Verificação de SO (scripts macOS só rodam no macOS, scripts Linux só rodam no Linux)
- ✅ Registro detalhado do espaço liberado
- ✅ Mantém arquivos essenciais do sistema
- ✅ Modo dry-run para visualizar mudanças

---

### 📁 Estrutura do Repositório

```
rubinho-clean-os/
├── LICENSE                  # Licença MIT
├── README.md               # Este arquivo
├── run.sh                  # Menu interativo principal
│
├── lib/                    # Módulos compartilhados
│   ├── cleanup_preview.sh # Sistema de preview de limpeza
│   ├── disk_analysis.sh   # Módulo de análise de disco
│   ├── logging.sh         # Funcionalidade de logging
│   └── platform.sh        # Detecção de plataforma
│
├── linux/                  # 🐧 Scripts Linux
│   └── scripts/
│       └── utils/
│           ├── analyze_space.sh
│           └── clean_space.sh
│
└── macos/                  # 🍎 Scripts macOS
    └── scripts/
        └── utils/
            ├── analyze_space.sh
            └── clean_space.sh
```

---

### 🐛 Solução de Problemas

#### Scripts não executam
**Problema:** `Permission denied` ao executar scripts

**Solução:**
```bash
chmod +x run.sh
chmod +x linux/scripts/utils/*.sh
chmod +x macos/scripts/utils/*.sh
```

#### Análise demora muito
**Problema:** Script parece travar durante a análise

**Solução:**
- Execute com `sudo` para acesso mais rápido a diretórios do sistema
- O script está processando diretórios grandes, seja paciente
- Você pode interromper com `Ctrl+C` se necessário
- Reduza o número de itens para analisar (o script irá perguntar)

#### Limpeza não liberou muito espaço
**Problema:** Limpeza concluída mas espaço liberado é mínimo

**Solução:**
- Execute a análise primeiro para ver o que está ocupando espaço
- Alguns arquivos podem estar protegidos ou em uso
- Tente executar com `sudo` para limpeza em todo o sistema
- Use `--dry-run` primeiro para visualizar o que será limpo

#### Script falha com "Platform detection module not found"
**Problema:** Erro ao executar `run.sh`

**Solução:**
- Certifique-se de estar executando do diretório raiz do repositório
- Verifique se `lib/platform.sh` existe
- Verifique se todos os arquivos foram clonados corretamente

---

### 📝 Licença

Este projeto está licenciado sob a Licença MIT - veja o arquivo [LICENSE](LICENSE) para detalhes.
