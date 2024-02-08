# Makefile

# Load environment variables from .env using dotenv
-include .env

# Define a target that uses the environment variables
up:
	COMPOSE_PROJECT_NAME=$(PROJECT_NAME) docker-compose up -d --build

down:
	COMPOSE_PROJECT_NAME=$(PROJECT_NAME) docker-compose down

destroy:
	COMPOSE_PROJECT_NAME=$(PROJECT_NAME) docker-compose down -v

restart:
	COMPOSE_PROJECT_NAME=$(PROJECT_NAME) docker-compose restart

install-bedrock:
	composer create-project roots/bedrock src

generate-bedrock-env:
	echo "# Database global variables" > src/.env
	echo "DB_NAME='$(MYSQL_DATABASE)'" >> src/.env
	echo "DB_USER='$(MYSQL_USER)'" >> src/.env
	echo "DB_PASSWORD='$(MYSQL_PASSWORD)'" >> src/.env
	echo "DB_HOST='$(MYSQL_HOST)'" >> src/.env
	echo "" >> src/.env
	echo "# WP global variables" >> src/.env
	echo "WP_ENV='development'" >> src/.env
	echo "WP_HOME='https://$(PROJECT_NAME).local'" >> src/.env
	echo "WP_SITEURL='https://$(PROJECT_NAME).local/wp'" >> src/.env
	echo "" >> src/.env
	echo "# Salt keys" >> src/.env
	echo "# https://api.wordpress.org/secret-key/1.1/salt/" >> src/.env
	echo "AUTH_KEY='generateme'" >> src/.env
	echo "SECURE_AUTH_KEY='generateme'" >> src/.env
	echo "LOGGED_IN_KEY='generateme'" >> src/.env
	echo "NONCE_KEY='generateme'" >> src/.env
	echo "AUTH_SALT='generateme'" >> src/.env
	echo "SECURE_AUTH_SALT='generateme'" >> src/.env
	echo "LOGGED_IN_SALT='generateme'" >> src/.env
	echo "NONCE_SALT='generateme'" >> src/.env

docker-exec-nginx:
	docker exec -ti $(PROJECT_NAME)_nginx sh

docker-exec-php:
	docker exec -ti $(PROJECT_NAME)_php sh

docker-exec-mysql:
	docker exec -ti $(PROJECT_NAME)_mysql sh

docker-exec-varnish:
	docker exec -ti $(PROJECT_NAME)_varnish sh

backup: backup-code backup-mysql

backup-code:
	mkdir -p backups
	docker exec -ti $(PROJECT_NAME)_php tar -zcvf /tmp/code.tar.gz /code
	docker cp $(PROJECT_NAME)_php:/tmp/code.tar.gz backups/$(PROJECT_NAME)_code.tar.gz
	docker exec -ti $(PROJECT_NAME)_php rm -rf /tmp/code.tar.gz

backup-mysql:
	mkdir -p backups
	docker exec -ti $(PROJECT_NAME)_mysql sh -c 'mysqldump -u$${MYSQL_USER} -p$${MYSQL_PASSWORD} --databases $${MYSQL_DATABASE} --add-drop-database | gzip -c > /tmp/dump.sql.gz'
	docker cp $(PROJECT_NAME)_mysql:/tmp/dump.sql.gz backups/$(PROJECT_NAME)_dump.sql.gz
	docker exec -ti $(PROJECT_NAME)_mysql rm -rf /tmp/dump.sql.gz

recover: recover-code recover-mysql

generate-certs:
	#!/bin/bash
	set -e
	mkdir -p certs
	mkcert -install "${DOMAIN}"
	find . -type f -name "*.pem" -exec mv {} ./certs \;

recover-code:
	docker cp backups/$(PROJECT_NAME)_code.tar.gz $(PROJECT_NAME)_php:/tmp/code.tar.gz
	docker exec -ti $(PROJECT_NAME)_php sh -c 'rm -rf /code/* && tar -zxvf /tmp/code.tar.gz --strip-components=1 -C /code && rm /tmp/code.tar.gz'

recover-mysql:
	docker cp backups/$(PROJECT_NAME)_dump.sql.gz $(PROJECT_NAME)_mysql:/tmp/dump.sql.gz
	docker exec -ti $(PROJECT_NAME)_mysql sh -c 'zcat /tmp/dump.sql.gz | mysql -u$${MYSQL_USER} -p$${MYSQL_PASSWORD} && rm /tmp/dump.sql.gz'

nginx-proxy-start:
	docker run -d --restart=always --net=host -p 80:80 -p 443:443 -v $(dir $(abspath $(lastword $(MAKEFILE_LIST))))certs:/etc/nginx/certs:ro -v /var/run/docker.sock:/tmp/docker.sock:ro jwilder/nginx-proxy

nginx-proxy-stop:
	docker rm $$(docker stop $$(docker ps -a -q --filter ancestor=jwilder/nginx-proxy --format="{{.ID}}"))

nginx-proxy-restart:
	-make nginx-proxy-stop
	make nginx-proxy-start
