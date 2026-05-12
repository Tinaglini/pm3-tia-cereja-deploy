# Certificados SSL

Este projeto exige certificados TLS validos em todas as camadas (Nginx, Tomcat, MariaDB, Keycloak).

## Opcao 1 - Reusar a cadeia UNIAMERICA do nosso grupo

Pedir ao grupo Tia Cereja os seguintes arquivos:

- `ca.crt` (CA raiz "CA Projeto Mensal" para instalar no Mac/Keychain como "Always Trust")
- `intermediario.crt` (assinada pela CA)
- `wildcard-fullchain.crt` (cert wildcard `*.local.projetomensal.com.br` + intermediario)
- `wildcard.key` (chave do wildcard)
- `sistemas-fullchain.crt` (cert SAN para `sistema1.net`/`sistema2.net`)
- `sistemas.key` (chave do SAN)

## Opcao 2 - Gerar sua propria cadeia

```bash
# 1. CA raiz
openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 \
  -out ca.crt \
  -subj "/C=BR/ST=PR/L=Foz do Iguacu/O=ProjetoMensal/CN=CA Projeto Mensal"

# 2. Intermediario
openssl genrsa -out intermediario.key 4096
cat > intermediario.cnf <<EOF
[ v3_ca ]
basicConstraints = CA:TRUE
keyUsage = digitalSignature, keyCertSign, cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
EOF
openssl req -new -key intermediario.key -out intermediario.csr \
  -subj "/C=BR/ST=PR/L=Foz do Iguacu/O=ProjetoMensal/CN=Intermediario Projeto Mensal"
openssl x509 -req -in intermediario.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out intermediario.crt -days 1825 -sha256 \
  -extfile intermediario.cnf -extensions v3_ca

# 3. Wildcard *.local.projetomensal.com.br
openssl genrsa -out wildcard.key 2048
cat > wildcard.cnf <<EOF
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[ dn ]
C = BR
ST = PR
L = FOZ DO IGUACU
O = UNIAMERICA
CN = *.local.projetomensal.com.br

[ v3_req ]
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = *.local.projetomensal.com.br
DNS.2 = local.projetomensal.com.br
EOF
openssl req -new -key wildcard.key -out wildcard.csr -config wildcard.cnf
openssl x509 -req -in wildcard.csr -CA intermediario.crt -CAkey intermediario.key -CAcreateserial \
  -out wildcard.crt -days 365 -sha256 \
  -extfile wildcard.cnf -extensions v3_req

# 4. Fullchain
cat wildcard.crt intermediario.crt > wildcard-fullchain.crt

# 5. Cert adicional para sistema1.net e sistema2.net
openssl genrsa -out sistemas.key 2048
cat > sistemas.cnf <<EOF
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[ dn ]
C = BR
ST = PR
L = FOZ DO IGUACU
O = UNIAMERICA
CN = sistema1.net

[ v3_req ]
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = sistema1.net
DNS.2 = sistema2.net
DNS.3 = www.sistema1.net
DNS.4 = www.sistema2.net
EOF
openssl req -new -key sistemas.key -out sistemas.csr -config sistemas.cnf
openssl x509 -req -in sistemas.csr -CA intermediario.crt -CAkey intermediario.key -CAcreateserial \
  -out sistemas.crt -days 365 -sha256 \
  -extfile sistemas.cnf -extensions v3_req
cat sistemas.crt intermediario.crt > sistemas-fullchain.crt
```

## Keystore PKCS12 para o Tomcat

```bash
openssl pkcs12 -export \
  -in wildcard-fullchain.crt \
  -inkey wildcard.key \
  -out keystore.p12 \
  -name tomcat -password pass:changeit
```

Mover para `backend/ssl/keystore.p12`.

## Confiar na CA no Mac (cadeado verde)

1. Duplo clique em `ca.crt` (abre Keychain Access)
2. Adicionar ao **System keychain** (nao Login)
3. Duplo clique no cert dentro do Keychain Access
4. Expandir secao "Trust" / "Confiar"
5. Em "Secure Sockets Layer (SSL)" selecionar "Always Trust" / "Sempre Confiar"
6. Fechar e digitar senha do Mac

## Distribuicao dos certificados

| Pasta | Arquivos |
|-------|----------|
| `frontend/ssl/` | `wildcard-fullchain.crt`, `wildcard.key`, `sistemas-fullchain.crt`, `sistemas.key` |
| `backend/ssl/` | `keystore.p12`, `wildcard-fullchain.crt` (para truststore) |
| `banco/ssl/` | `wildcard-fullchain.crt`, `wildcard.key` |
| `keycloak/certs/` | `keycloak.crt` (= wildcard-fullchain.crt), `keycloak.key` (= wildcard.key) |
