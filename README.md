# PM3 - Tia Cereja (Sistema de Gestao de Festas)

Sistema de gestao de eventos e festas. Faz parte do trabalho do Projeto Mensal 3.

## Stack

- **Frontend:** Angular 19 (dist ja buildada inclusa)
- **Backend:** Spring Boot 3.1, Java 17, deployado como WAR no Tomcat 11
- **Banco:** MariaDB 11.4 com TLS habilitado
- **Auth:** Keycloak 24.0 (realm `cereja` exportado em JSON)
- **Web Server:** Nginx Alpine
- **Containers:** Docker + Docker Compose

## Arquitetura distribuida em 3 VMs

| VM | Funcao | Servicos |
|----|--------|----------|
| VM1 | Frontend | Nginx servindo Angular dist (HTTPS 443) |
| VM2 | Backend | Tomcat com WAR Spring Boot (HTTPS 8443 + HTTP 8080) |
| VM3 | Banco + Keycloak | MariaDB (3306 TLS) + Keycloak (HTTP 8080 + HTTPS 8443) |

## Pre-requisitos

- 3 VMs Alpine Linux (ou compatibilidade equivalente)
- Docker + Docker Compose instalados em cada VM
- IPs definidos entre as VMs
- Certificados SSL (ver secao `certs/`)
- Dominio configurado em `/etc/hosts` de cada VM e do cliente
- **Credenciais sensiveis (solicitar privado ao grupo Tia Cereja)** - veja secao abaixo

## Credenciais sensiveis - SOLICITAR NO PRIVADO

Os arquivos commitados neste repositorio contem placeholders `__VARIAVEL__` para todos os dados sensiveis (senhas, secrets, hashes de senha, emails). Antes de fazer o deploy, voce precisa solicitar privadamente ao grupo Tia Cereja o pacote `pm3-cereja-DADOS-PRIVADOS.zip` que contem:

- `CREDENCIAIS.md` - tabela com todos os valores das senhas e como aplicar no repo
- `init-data-sensitive.sql` - INSERTs com usuarios de teste (emails + senhas bcrypt)
- Copias originais dos arquivos com as senhas hardcoded (caso prefira sobrescrever direto)

Placeholders presentes no repo:

| Arquivo | Placeholder | Tipo |
|---------|-------------|------|
| `banco/docker-compose.yml` | `__MARIADB_ROOT_PASSWORD__` | Senha root do MariaDB |
| `banco/grants.sql` | `__BACKEND_IP__`, `__DB_USER_PASSWORD__` | IP da VM2 e senha do usuario do app |
| `backend/docker-compose.yml` | `__DB_USERNAME__`, `__DB_PASSWORD__`, `__JWT_SECRET__`, `__ADMIN_EMAIL__`, `__ADMIN_PASSWORD__`, `__VM3_IP__`, `__TRUSTSTORE_PASSWORD__` | Credenciais do backend |
| `backend/server.xml` | `__KEYSTORE_PASSWORD__` | Senha do keystore PKCS12 |
| `keycloak/docker-compose.yml` | `__KC_DB_PASSWORD__`, `__KEYCLOAK_ADMIN__`, `__KEYCLOAK_ADMIN_PASSWORD__`, `__VM_DB_IP__` | Credenciais do Keycloak |
| `keycloak/realm-cereja-export.json` | `__CLIENT_SECRET__` | Secret do client confidential `cereja-backend` |

Apos receber o `CREDENCIAIS.md`, aplicar com os comandos `sed` documentados nele.

## Estrutura do repositorio

```
pm3-tia-cereja-deploy/
├── README.md                       (este arquivo)
├── frontend/
│   ├── docker-compose.yml
│   ├── default.conf                (Nginx config com TLS + HSTS + headers seguranca)
│   ├── dist/                       (Angular ja buildado, 28 arquivos)
│   └── ssl/                        (colocar fullchain.crt + wildcard.key aqui)
├── backend/
│   ├── docker-compose.yml
│   ├── server.xml                  (Tomcat com SSL connector 8443)
│   ├── ROOT.war                    (Spring Boot ja buildado)
│   └── ssl/                        (colocar keystore.p12 aqui)
├── banco/
│   ├── docker-compose.yml
│   ├── init.sql                    (schema + dados iniciais)
│   ├── grants.sql                  (usuario cereja_app com placeholder __BACKEND_IP__)
│   ├── mariadb-server.cnf          (config com TLS)
│   └── ssl/                        (colocar fullchain.crt + wildcard.key aqui)
├── keycloak/
│   ├── docker-compose.yml
│   ├── realm-cereja-export.json    (4 roles, 4 users, 2 clients - import automatico)
│   ├── user-role-mappings.json     (referencia: quem tem qual role)
│   └── certs/                      (colocar keycloak.crt + keycloak.key aqui)
└── certs/
    └── README.md                   (como gerar/obter certs)
```

---

## Passo a passo de deploy

### 0. Configuracao de IPs e dominios

Em cada uma das 3 VMs e no cliente (Mac/Windows que vai acessar):

`/etc/hosts`:
```
<IP_DA_VM1>  sistema1.net frontend.local.projetomensal.com.br
<IP_DA_VM3>  keycloak.local.projetomensal.com.br
<IP_DA_VM2>  backend.local.projetomensal.com.br
```

### 1. Certificados SSL

Voce precisa de 2 pares de certificados:

**A) Wildcard `*.local.projetomensal.com.br`** (para Nginx, Tomcat, MariaDB e Keycloak HTTPS):
- `fullchain.crt` - cert + intermediario
- `wildcard.key` - chave privada

**B) `sistema1.net` + `sistema2.net`** (para o Nginx servir os dominios literais do PDF com cadeado verde):
- `sistemas-fullchain.crt`
- `sistemas.key`

Veja `certs/README.md` para detalhes.

Distribua os certs assim:
- `frontend/ssl/`: ambos os pares + a CA raiz que assinou (para confiar no Mac)
- `backend/ssl/`: keystore PKCS12 gerado do wildcard
- `banco/ssl/`: wildcard
- `keycloak/certs/`: wildcard (renomeado como `keycloak.crt` e `keycloak.key`)

### 2. VM3 - subir o banco primeiro

```bash
cd banco/
sed -i "s/__BACKEND_IP__/<IP_DA_VM2>/g" grants.sql
docker compose up -d
```

Espera ~10 segundos. Verifica:
```bash
docker logs cereja-mariadb 2>&1 | grep "ready for connections"
```

### 3. VM3 - subir o Keycloak

Editar `keycloak/docker-compose.yml`:
- Trocar `__VM_DB_IP__` pelo IP da VM3 (a propria VM).

Antes de subir, criar o banco do Keycloak no MariaDB:
```bash
docker exec cereja-mariadb mariadb -u root -p"__MARIADB_ROOT_PASSWORD__" -e "CREATE DATABASE keycloak; CREATE USER 'keycloak'@'%' IDENTIFIED BY 'keycloak'; GRANT ALL ON keycloak.* TO 'keycloak'@'%'; FLUSH PRIVILEGES;"
```

Subir Keycloak:
```bash
cd ../keycloak/
docker compose up -d
```

O realm `cereja` sera importado automaticamente. Verifica:
```bash
docker logs cereja-keycloak 2>&1 | tail -20
```

### 4. VM2 - subir o backend

Editar `backend/docker-compose.yml`:
- Trocar `__VM3_IP__` pelo IP da VM3.

Gerar o keystore PKCS12 a partir do wildcard:
```bash
openssl pkcs12 -export \
  -in ssl/wildcard-fullchain.crt \
  -inkey ssl/wildcard.key \
  -out ssl/keystore.p12 \
  -name tomcat -password pass:changeit
```

Subir backend:
```bash
cd backend/
docker compose up -d
```

Verifica:
```bash
docker logs cereja-backend 2>&1 | grep "Started FestasApplication"
curl -sk https://localhost:8443/api/temas
```

### 5. VM1 - subir o frontend

```bash
cd frontend/
docker compose up -d
curl -sk https://localhost/
```

### 6. Validacao end-to-end

No cliente (Mac/Windows), com `/etc/hosts` configurado:

```
https://sistema1.net/                              -> cadeado verde + tela de login
https://sistema1.local.projetomensal.com.br/       -> mesma coisa
https://backend.local.projetomensal.com.br:8443/api/temas  -> JSON publico
https://keycloak.local.projetomensal.com.br:8443/  -> tela admin Keycloak
```

---

## Usuarios de teste (no realm `cereja`)

Senhas: solicitar privado (ver `CREDENCIAIS.md`).

| Username | Role | Acesso |
|----------|------|--------|
| `admin_user` | Admin | Acesso total |
| `user_limitado` | Limitado | Acesso basico (USER) |
| `user_exclusivo1` | Exclusivo1 | Sistema 1 apenas |
| `user_exclusivo2` | Exclusivo2 | Sistema 2 apenas (rejeitado no Sistema 1 com HTTP 403) |

OBS: os hashes de senha foram removidos do realm export sanitizado. Apos importar, redefinir as senhas via Admin Console:
Manage > Users > selecionar user > Credentials > Set password.

Tambem ha login local custom (sem Keycloak) - email e senha em `CREDENCIAIS.md`.

---

## Variaveis de ambiente do backend (referencia)

Definidas no `backend/docker-compose.yml`:

| Variavel | Default | Observacoes |
|----------|---------|-------------|
| `DB_URL` | `jdbc:mysql://__VM3_IP__:3306/festasdb?useSSL=true&...` | TLS exigido (substituir IP) |
| `DB_USERNAME` | `__DB_USERNAME__` | Solicitar valor privado |
| `DB_PASSWORD` | `__DB_PASSWORD__` | Solicitar valor privado |
| `JWT_SECRET` | `__JWT_SECRET__` | Solicitar valor privado |
| `CORS_ALLOWED_ORIGINS` | `https://*.local.projetomensal.com.br,https://sistema1.net,...` | Origens permitidas |
| `KEYCLOAK_ISSUER_URI` | `https://keycloak.local.projetomensal.com.br:8443/realms/cereja` | URL HTTPS do realm |

---

## Mapeamento de roles Keycloak -> Spring (no `KeycloakJwtAuthenticationConverter`)

| Role Keycloak | Spring Authorities |
|---------------|--------------------|
| `Admin` | `ROLE_ADMIN`, `ROLE_USER` |
| `Limitado` | `ROLE_USER`, `ROLE_LIMITADO` |
| `Exclusivo1` | `ROLE_USER`, `ROLE_EXCLUSIVO1` |
| `Exclusivo2` | `ROLE_EXCLUSIVO2` (rejeitado em qualquer endpoint protegido) |

---

## Troubleshooting

**`Address already in use` ao subir containers:**
- Outras portas 80/443/3306/8080/8443 podem estar em uso. Parar servicos nativos antes ou ajustar `docker-compose.yml`.

**Keycloak nao consegue conectar no MariaDB:**
- Confirme que o banco subiu primeiro (`docker logs cereja-mariadb`)
- Confirme que o IP em `KC_DB_URL_HOST` esta correto
- Confirme que existem `CREATE DATABASE keycloak` e o usuario `keycloak`

**Backend falha com 401/403 em todos endpoints com tokens Keycloak:**
- Verifique se o `KEYCLOAK_ISSUER_URI` aponta para o realm correto via HTTPS
- O backend precisa ter a CA do Keycloak no truststore Java (se cert auto-assinado)

**`Host '<ip>' is not allowed to connect to this MariaDB server`:**
- O `grants.sql` precisa do IP correto da VM2. Edite `__BACKEND_IP__`.

**Frontend mostra 'connection refused' ao chamar backend:**
- Confirme que o backend esta em `https://backend.local.projetomensal.com.br:8443`
- Confirme `/etc/hosts` do cliente

---

## Repositorios fonte (caso precise modificar)

- Frontend: https://github.com/Tinaglini/frontend-cereja
- Backend: https://github.com/Tinaglini/backend-cereja

Para rebuildar:

```bash
# Frontend
git clone https://github.com/Tinaglini/frontend-cereja.git
cd frontend-cereja
# Ajuste src/environments/environment.ts (URL do backend)
npm install --legacy-peer-deps
npm run build
# A dist resultante vai em dist/festa-frontend/browser/

# Backend
git clone https://github.com/Tinaglini/backend-cereja.git
cd backend-cereja
mvn clean package -DskipTests
# WAR resultante: target/festas-0.0.1-SNAPSHOT.war
```
