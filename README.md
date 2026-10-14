# 🚀 Instalador Oficial AMANDA

Suite oficial de instalação, atualização e gerenciamento 100% Docker para a plataforma **AMANDA**.

---

### 📥 Download do Instalador & Primeira Instalação:

Execute no terminal da sua VPS Linux (Ubuntu / Debian como root):

```bash
sudo apt update && sudo apt install -y git && git clone https://github.com/alansuporteamanda/Instalador-AMANDA.git instalador && cd instalador && sudo chmod -R 775 *.sh tools/*.sh && sudo ./instalador_single.sh
```

---

### 🔄 Para Abrir Novamente ou Atualizar o Instalador:

```bash 
cd /root/instalador && git pull && sudo chmod -R 775 *.sh tools/*.sh && sudo ./instalador_single.sh
```

---

### 🌟 Destaques da Suite Oficial v1.0.0:
- **100% Docker-Only:** Orquestração completa de 9 contêineres otimizados (PostgreSQL 17, PgBouncer, Redis 7.4, AMANDA Backend Node 20 + Rust Nativo, AMANDA Frontend React, WhatsApp Meta Cloud API Oficial, WuzAPI WhatsMeow, Go Campaign Dispatcher e API de Transcrição).
- **Modo Sem Domínio (Apenas IP / Localhost):** Suporte nativo para testes locais, WSL ou VPS sem domínio público, com acesso direto pelas portas HTTP (3000, 8080 e 6000) e bypass automático de checagens de DNS e SSL.
- **Gerenciador de URLs Interativo:** Permite inspecionar e alterar individualmente as URLs de todos os microsserviços, com teste de conectividade (DNS/Ping/HTTP) e reinício automático imediato dos contêineres afetados.
- **Identidade Visual Roxa AMANDA:** Interface moderna harmonizada na paleta roxa oficial (`#8B5CF6` / `#7C3AED`).
- **Credenciais Oficiais Configuradas:** `admin@amanda.com.br` / `adminamanda`.
- **Banco de Dados Oficial:** `DB_USER=amanda` / `DB_NAME=amanda` / `Acertitech13@`.
- **Repositório da Aplicação Conectado:** Baixa e atualiza automaticamente o código de [https://github.com/alansuporteamanda/AMANDA.git](https://github.com/alansuporteamanda/AMANDA.git).