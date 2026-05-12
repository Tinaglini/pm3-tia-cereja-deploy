-- Grants para o backend Tia Cereja acessar o banco festasdb
-- Substituir placeholders antes de executar:
--   __BACKEND_IP__         = IP da VM do backend (ex: 192.168.1.17)
--   __DB_USER_PASSWORD__   = senha do usuario cereja_app (solicitar privado)
--
-- Exemplo:
--   sed -i 's/__BACKEND_IP__/192.168.1.17/g; s|__DB_USER_PASSWORD__|<SENHA>|g' grants.sql
--   mariadb -u root -p < grants.sql

CREATE USER IF NOT EXISTS 'cereja_app'@'__BACKEND_IP__' IDENTIFIED BY '__DB_USER_PASSWORD__';
GRANT ALL PRIVILEGES ON festasdb.* TO 'cereja_app'@'__BACKEND_IP__';

CREATE USER IF NOT EXISTS 'cereja_app'@'localhost' IDENTIFIED BY '__DB_USER_PASSWORD__';
GRANT ALL PRIVILEGES ON festasdb.* TO 'cereja_app'@'localhost';

FLUSH PRIVILEGES;
