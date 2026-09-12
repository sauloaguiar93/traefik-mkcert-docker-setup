#!/bin/bash

###############################################################################
# Projeto      : Traefik + mkcert
# Descrição    : Provisionamento automatizado de HTTPS para Docker
#
# Autor        : Saulo Aguiar
# Data         : 14/10/2024
# Versão       : 1.0
#
# Tecnologias  : Bash | Docker | Traefik 2.9 | mkcert
#
# Objetivo     :
#   Automatizar a criação do certificado wildcard e a implantação do
#   Traefik 2.9 como reverse proxy HTTPS em ambiente Docker.
#
###############################################################################

clear

echo "###############################################################################"
echo "#                                                                             #"
echo "#                    TRAEFIK + MKCERT - SETUP                                 #"
echo "#                                                                             #"
echo "#  Autor       : Saulo Aguiar                                                 #"
echo "#  Data        : 14/10/2024                                                   #"
echo "#  Versão      : 1.0                                                          #"
echo "#                                                                             #"
echo "#  Tecnologias : Bash | Docker | Traefik 2.9 | mkcert                         #"
echo "#                                                                             #"
echo "###############################################################################"
echo

set -e

###############################################################################
# CONFIGURAÇÕES
###############################################################################

DOMAIN="DIGITE O DOMÍNIO AQUI"  # Exemplo: example.com
NETWORKDOCKER="DIGITE O NOME DA REDE DOCKER AQUI"  # Exemplo: minha_rede

PATH_CERT="DIGITE O CAMINHO PARA O DIRETÓRIO DE CERTIFICADOS AQUI"  # Exemplo: /home/usuario/certificados
PATH_CONFIG="DIGITE O CAMINHO PARA O DIRETÓRIO DE CONFIGURAÇÃO AQUI"  # Exemplo: /home/usuario/config

TRAEFIK_CONTAINER="traefik"
TRAEFIK_IMAGE="traefik:2.9"

###############################################################################
# CORES E MENSAGENS
###############################################################################

log() {
    echo
    echo "============================================================"
    echo "$1"
    echo "============================================================"
}

###############################################################################
# VALIDAÇÕES
###############################################################################

log "Validando dependências"

if ! command -v docker >/dev/null 2>&1; then
    echo "ERRO: Docker não está instalado."
    exit 1
fi

if ! command -v wget >/dev/null 2>&1; then
    echo "ERRO: wget não está instalado."
    exit 1
fi

###############################################################################
# INSTALAÇÃO DO LIBNSS3-TOOLS
###############################################################################

log "Instalando libnss3-tools"

sudo apt update

sudo apt install -y libnss3-tools || {
    echo "ERRO: Falha na instalação do libnss3-tools."
    exit 1
}

###############################################################################
# INSTALAÇÃO DO MKCERT
###############################################################################

log "Baixando e configurando mkcert"

wget "https://dl.filippo.io/mkcert/latest?for=linux/amd64" \
    -O mkcert || {
        echo "ERRO: Falha ao baixar o mkcert."
        exit 1
    }

sudo mv mkcert /usr/local/bin/mkcert
sudo chmod +x /usr/local/bin/mkcert

###############################################################################
# GERAÇÃO DO CERTIFICADO
###############################################################################

log "Gerando certificado wildcard"

mkcert "*.$DOMAIN"

###############################################################################
# PREPARAÇÃO DOS DIRETÓRIOS
###############################################################################

log "Preparando diretórios"

mkdir -p "$PATH_CERT"
mkdir -p "$PATH_CONFIG"

###############################################################################
# CÓPIA DOS CERTIFICADOS
###############################################################################

log "Copiando certificados"

cp "*_wildcard.$DOMAIN.pem" \
    "$PATH_CERT"

cp "*_wildcard.$DOMAIN-key.pem" \
    "$PATH_CERT"

###############################################################################
# CONFIGURAÇÃO DINÂMICA DO TRAEFIK
###############################################################################

log "Criando configuração dinâmica do Traefik"

cat <<EOF > "$PATH_CONFIG/dynamic_conf.yml"

http:

  middlewares:

    redirect-to-https:

      redirectScheme:
        scheme: https
        permanent: true

tls:

  certificates:

    - certFile: "/etc/traefik/certificados/_wildcard.$DOMAIN.pem"
      keyFile: "/etc/traefik/certificados/_wildcard.$DOMAIN-key.pem"

EOF

###############################################################################
# REDE DOCKER
###############################################################################

log "Validando rede Docker"

if ! docker network inspect "$NETWORKDOCKER" >/dev/null 2>&1; then

    echo "Criando rede Docker: $NETWORKDOCKER"

    docker network create "$NETWORKDOCKER"

else

    echo "Rede Docker já existe: $NETWORKDOCKER"

fi

###############################################################################
# REMOÇÃO DE CONTAINER EXISTENTE
###############################################################################

if docker container inspect "$TRAEFIK_CONTAINER" >/dev/null 2>&1; then

    log "Removendo container Traefik existente"

    docker rm -f "$TRAEFIK_CONTAINER"

fi

###############################################################################
# EXECUÇÃO DO TRAEFIK
###############################################################################

log "Subindo Traefik 2.9"

docker run \
    --name "$TRAEFIK_CONTAINER" \
    --network "$NETWORKDOCKER" \
    --restart=always \
    -p 80:80 \
    -p 443:443 \
    \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    -v "$PATH_CONFIG:/etc/traefik/config" \
    -v "$PATH_CERT:/etc/traefik/certificados" \
    \
    -l 'traefik.enable=true' \
    -l 'traefik.http.routers.traefik.tls=true' \
    -l 'traefik.http.routers.traefik.entrypoints=websecure' \
    -l 'traefik.http.routers.traefik.service=api@internal' \
    \
    -l 'traefik.http.routers.http-catchall.rule=hostregexp(`{host:.+}`)' \
    -l 'traefik.http.routers.http-catchall.entrypoints=web' \
    -l 'traefik.http.routers.http-catchall.middlewares=redirect-to-https@file' \
    \
    -d "$TRAEFIK_IMAGE" \
    \
    --api \
    --api.dashboard=true \
    --log.level=error \
    \
    --entrypoints.web.address=":80" \
    --entrypoints.websecure.address=":443" \
    \
    --providers.docker \
    --providers.docker.endpoint="unix:///var/run/docker.sock" \
    --providers.docker.exposedbydefault=false \
    \
    --providers.file.directory=/etc/traefik/config \
    --providers.file.watch=true

###############################################################################
# VALIDAÇÃO FINAL
###############################################################################

log "Validando Traefik"

if docker ps --filter "name=$TRAEFIK_CONTAINER" --filter "status=running" \
    --format '{{.Names}}' | grep -q "^${TRAEFIK_CONTAINER}$"; then

    echo "Traefik iniciado com sucesso."
    echo
    echo "Domínio : $DOMAIN"
    echo "Rede    : $NETWORKDOCKER"
    echo "HTTPS   : https://*.$DOMAIN"
    echo "Container: $TRAEFIK_CONTAINER"

else

    echo "ERRO: O container Traefik não está em execução."
    echo
    echo "Verifique os logs com:"
    echo "docker logs $TRAEFIK_CONTAINER"

    exit 1

fi

###############################################################################
# FINALIZAÇÃO
###############################################################################

log "Provisionamento concluído"

echo "Traefik 2.9 configurado com sucesso."