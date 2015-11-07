.PHONY: smoke-test

all: docker-consul deploy-consul docker-tsuru-admin deploy-tsuru-admin docker-no-tls consul-keys

dev: docker-consul deploy-consul docker-tsuru-admin deploy-tsuru-admin-dev docker-no-tls consul-keys

docker-no-tls: create-docker-no-tls set-dns

create-docker-no-tls:
	$(eval CONSUL_IP=$(shell docker-machine ip docker-consul))
	@docker-machine create \
		--engine-opt dns=${CONSUL_IP} \
		--engine-opt dns=8.8.8.8 \
		--engine-opt dns-search=service.consul \
		--engine-opt host=tcp://0.0.0.0:2375 \
		--engine-env DOCKER_TLS=no \
		--engine-insecure-registry registry.service.consul:5000 \
		-d virtualbox docker-no-tls \
			|| echo Already created

set-dns: start-docker-no-tls
	$(eval CONSUL_IP=$(shell docker-machine ip docker-consul))
	@docker-machine ssh docker-no-tls \
		"sudo sh -c 'echo -e \"nameserver ${CONSUL_IP}\nsearch service.consul\nnameserver 192.168.0.1\nnameserver 0.0.0.0\" > /etc/resolv.conf'"

set-dns-tsuru-admin: start-tsuru-admin
	$(eval CONSUL_IP=$(shell docker-machine ip docker-consul))
	@docker-machine ssh docker-tsuru-admin \
		"sudo sh -c 'echo -e \"nameserver ${CONSUL_IP}\nsearch service.consul\nnameserver 192.168.0.1\nnameserver 0.0.0.0\" > /etc/resolv.conf'"

rm-docker-no-tls:
	@docker-machine rm docker-no-tls

docker-consul:
	@docker-machine create \
	    -d virtualbox docker-consul \
			|| echo Already created

docker-tsuru-admin:
	$(eval CONSUL_IP=$(shell docker-machine ip docker-consul))
	@docker-machine create \
	    --engine-opt dns=${CONSUL_IP} \
	    --engine-opt dns=8.8.8.8 \
	    --engine-opt dns-search=service.consul \
	    --engine-opt tlsverify=false \
	    -d virtualbox docker-tsuru-admin \
			|| echo Already created

rm-docker-tsuru-admin:
	@docker-machine rm docker-tsuru-admin

start-docker-consul:
	@[[ "$$(docker-machine status docker-consul)" != "Running" ]] \
		&& docker-machine start docker-consul \
		|| echo docker-consul is running

start-tsuru-admin:
	@[[ "$$(docker-machine status docker-tsuru-admin)" != "Running" ]] \
		&& docker-machine start docker-tsuru-admin \
		|| echo docker-tsuru-admin is running

deploy-tsuru-admin-dev: start-tsuru-admin render-compose-yaml render-compose-yaml-dev build-images compose-up

build-images:
	@[[ -z "${DOCKERIZED_SETUP_DIR}" ]] && echo Variable DOCKERIZED_SETUP_DIR not set \
		&& exit 1 || true

	@eval "$$(docker-machine env docker-tsuru-admin)" \
		&& cd ${DOCKERIZED_SETUP_DIR}/tsuru-api && docker build -t tsuru-api . \
		&& cd ${DOCKERIZED_SETUP_DIR}/gandalf && docker build -t gandalf . \
		&& cd ${DOCKERIZED_SETUP_DIR}/archive-server && docker build -t archive-server . \
		&& cd ${DOCKERIZED_SETUP_DIR}/consul-template && docker build -t consul-template . \
		&& cd ${DOCKERIZED_SETUP_DIR}/router-hipache && docker build -t router-hipache .

render-compose-yaml-dev:
	@sed -e "s/CONSUL_IP/$$(docker-machine ip docker-consul)/g" \
		-e "s/TSURU_ADMIN_IP/$$(docker-machine ip docker-tsuru-admin)/g" \
		-e "s@image: tsuru/@image: @g" docker-compose.yml.tpl \
		> docker-compose.yml

deploy-tsuru-admin: start-tsuru-admin render-compose-yaml compose-up
deploy-consul: start-docker-consul render-compose-yaml-consul compose-up-consul

compose-up:
	@eval "$$(docker-machine env docker-tsuru-admin)" \
		&& docker-compose up -d

compose-up-consul:
	@eval "$$(docker-machine env docker-consul)" \
		&& COMPOSE_FILE=docker-compose-consul.yml docker-compose up -d

render-compose-yaml:
	@sed "s/CONSUL_IP/$$(docker-machine ip docker-consul)/g" docker-compose.yml.tpl > docker-compose.yml

render-compose-yaml-consul:
	@sed "s/CONSUL_IP/$$(docker-machine ip docker-consul)/g" docker-compose-consul.yml.tpl > docker-compose-consul.yml

start-docker-no-tls:
	@[[ "$$(docker-machine status docker-no-tls)" != "Running" ]] \
		&& docker-machine start docker-no-tls \
		|| echo docker-no-tls is running

consul-keys:
	$(eval tsuru_admin_ip=$(shell docker-machine ip docker-tsuru-admin))
	$(eval consul_ip=$(shell docker-machine ip docker-consul))
	@echo Settings consul key tsuru/git/rw-host
	@curl -X PUT -d "${tsuru_admin_ip}:2222" http://${consul_ip}:8500/v1/kv/tsuru/git/rw-host
	@echo
	@echo Settings consul key hipache/domain
	@curl -X PUT -d "${tsuru_admin_ip}.nip.io" http://${consul_ip}:8500/v1/kv/hipache/domain
	@echo

test:
	$(eval tsuru_admin_ip=$(shell docker-machine ip docker-tsuru-admin))
	tsuru target-remove machine-${tsuru_admin_ip}
	tsuru target-add -s machine-${tsuru_admin_ip} http://${tsuru_admin_ip}:8000
	curl -d "{\"email\":\"clark@dailyplanet.com\",\"password\":\"superman\"}" http://${tsuru_admin_ip}:8000/users
	ruby login.rb ${tsuru_admin_ip}:8000 clark@dailyplanet.com superman
	tsuru team-create admin || echo ok
	tsuru-admin pool-add default || echo ok
	tsuru-admin pool-teams-add default admin || echo ok
	$(eval tsuru_docker_ip=$(shell docker-machine ip docker-no-tls))
	tsuru-admin docker-node-add --register address=http://${tsuru_docker_ip}:2375 pool=default
	until tsuru-admin docker-node-list | grep -q ready; do echo Waiting for docker node...; sleep 1; done
	tsuru-admin platform-add python --dockerfile https://raw.githubusercontent.com/tsuru/basebuilder/master/python/Dockerfile || echo ok
	tsuru key-remove test_tsuru_abcd123 -y || echo ok
	rm -f ~/.id_rsa_test_tsuru_abcd123
	ssh-keygen -f ~/.id_rsa_test_tsuru_abcd123 -N ""
	tsuru key-add test_tsuru_abcd123 ~/.id_rsa_test_tsuru_abcd123.pub
	tsuru app-remove -a dashboard-abcd123 -y || echo ok
	tsuru app-create dashboard-abcd123 python
	git clone https://github.com/tsuru/tsuru-dashboard.git /tmp/tsuru-dashboard-abcd123 || echo ok
	eval $(ssh-agent)
	ssh-add ~/.id_rsa_test_tsuru_abcd123
	cd /tmp/tsuru-dashboard-abcd123 && git push ssh://git@${tsuru_admin_ip}:2222/dashboard-abcd123.git
	curl -sL dashboard-abcd123.${tsuru_admin_ip}.nip.io | grep -q  "tsuru web dashboard"
