# traefik-mkcert-docker-setup

# Traefik + mkcert + Docker

Automação em Bash para provisionamento de um ambiente **HTTPS com Traefik 2.9**, utilizando **mkcert** para geração de certificados wildcard e integração com o Docker Provider.

A proposta é simplificar a configuração inicial de um ambiente com **Reverse Proxy + HTTPS**, centralizando as principais configurações em variáveis no início do script.

## 🚀 O que o script faz

O script automatiza todo o processo de preparação do ambiente:

* Instala o `libnss3-tools`
* Baixa e configura o `mkcert`
* Gera certificado wildcard para o domínio informado
* Cria os diretórios necessários
* Copia os certificados para o diretório configurado
* Gera a configuração dinâmica do Traefik
* Cria a rede Docker caso ela não exista
* Provisiona o container do Traefik 2.9
* Configura HTTP → HTTPS
* Configura o Docker Provider
* Habilita o Dashboard do Traefik
* Configura o carregamento dinâmico da configuração
* Configura o certificado TLS wildcard

## 🏗️ Arquitetura

```text
                         ┌──────────────────────┐
                         │       Cliente        │
                         │      HTTPS :443      │
                         └──────────┬───────────┘
                                    │
                                    ▼
                         ┌──────────────────────┐
                         │      Traefik 2.9     │
                         │    Reverse Proxy     │
                         └──────────┬───────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
                    ▼                               ▼
             ┌─────────────┐                 ┌─────────────┐
             │  Container  │                 │  Container  │
             │     App     │                 │     API     │
             └─────────────┘                 └─────────────┘

                         Docker Network
```

## 📋 Requisitos

O ambiente precisa possuir:

* Linux
* Docker
* Bash
* `wget`
* Acesso `sudo`
* Conexão com a Internet

O próprio script instala:

```text
libnss3-tools
mkcert
```

## ⚙️ Configuração

As principais configurações ficam concentradas no início do script:

```bash
DOMAIN="example.local"
NETWORKDOCKER="docker_network"

PATH_CERT="/path/to/certificates"
PATH_CONFIG="/path/to/config"
```

### Domínio

Defina o domínio utilizado no ambiente:

```bash
DOMAIN="example.local"
```

O certificado wildcard será gerado para:

```text
*.example.local
```

### Rede Docker

Defina a rede utilizada pelos containers:

```bash
NETWORKDOCKER="docker_network"
```

Caso a rede não exista, o script irá criá-la automaticamente.

### Diretório dos certificados

```bash
PATH_CERT="/path/to/certificates"
```

### Diretório das configurações

```bash
PATH_CONFIG="/path/to/config"
```

## 🔐 Certificado HTTPS

O projeto utiliza o **mkcert** para gerar certificados locais confiáveis.

O certificado wildcard permite utilizar o mesmo certificado para diferentes subdomínios, por exemplo:

```text
app.example.local
api.example.
```
