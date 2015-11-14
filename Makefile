all: consul-machine tsuru-server-machine consul-keys runner-machine
dev: check-var-dockerized-setup consul-machine tsuru-server-machine-dev consul-keys runner-machine
rm-all: rm-runner-machine rm-tsuru-server-machine rm-consul-machine
start: start-consul-machine start-tsuru-server-machine start-runner-machine

consul-machine: create-consul-machine deploy-consul
tsuru-server-machine: create-tsuru-server-machine set-dns-tsuru-server-machine deploy-tsuru-server
tsuru-server-machine-dev: check-var-dockerized-setup create-tsuru-server-machine set-dns-tsuru-server-machine deploy-tsuru-server-dev
runner-machine: create-runner-machine set-dns-runner-machine

create-consul-machine:
	@docker-machine create \
	    -d virtualbox consul \
			|| echo consul machine already created

create-tsuru-server-machine:
	$(eval CONSUL_IP=$(shell docker-machine ip consul))
	@docker-machine create \
	    --engine-opt dns=${CONSUL_IP} \
	    --engine-opt dns-search=service.consul \
	    --engine-opt tlsverify=false \
	    -d virtualbox tsuru-server \
			|| echo tsuru-server machine already created

create-runner-machine:
	$(eval CONSUL_IP=$(shell docker-machine ip consul))
	@docker-machine create \
		--engine-opt dns=${CONSUL_IP} \
		--engine-opt dns-search=service.consul \
		--engine-opt host=tcp://0.0.0.0:2375 \
		--engine-env DOCKER_TLS=no \
		--engine-insecure-registry registry.service.consul:5000 \
		-d virtualbox runner \
			|| echo runner machine already created

set-dns-tsuru-server-machine: start-tsuru-server-machine
	$(eval CONSUL_IP=$(shell docker-machine ip consul))
	@docker-machine ssh tsuru-server \
		"sudo sh -c 'echo -e \"nameserver ${CONSUL_IP}\nsearch service.consul\nnameserver 192.168.0.1\nnameserver 0.0.0.0\" > /etc/resolv.conf'"
	@docker-machine ssh tsuru-server \
		"sudo sh -c 'sed \"s/--dns=192.168.*$\/--dns=${CONSUL_IP}/\" -i /var/lib/boot2docker/profile'"
	@docker-machine ssh tsuru-server \
		"sudo sh -c 'sudo /etc/init.d/docker restart'"

set-dns-runner-machine: start-runner-machine
	$(eval CONSUL_IP=$(shell docker-machine ip consul))
	$(eval TSURU_SERVER_IP=$(shell docker-machine ip tsuru-server))
	@docker-machine ssh runner \
		"sudo sh -c 'echo -e \"nameserver ${CONSUL_IP}\nsearch service.consul\nnameserver 192.168.0.1\nnameserver 0.0.0.0\" > /etc/resolv.conf'"
	@docker-machine ssh runner \
		"sudo sh -c 'grep -q \"${TSURU_SERVER_IP} registry.service.consul\" /etc/hosts || echo -e \"${TSURU_SERVER_IP} registry.service.consul\" >> /etc/hosts'"
	@docker-machine ssh runner \
		"sudo sh -c 'grep -q \"${TSURU_SERVER_IP} tsuru-api.service.consul\" /etc/hosts || echo -e \"${TSURU_SERVER_IP} tsuru-api.service.consul\" >> /etc/hosts'"
	@docker-machine ssh runner \
		"sudo sh -c 'sed \"s/--dns=192.168.*$\/--dns=${CONSUL_IP}/\" -i /var/lib/boot2docker/profile'"
	@docker-machine ssh runner \
		"sudo sh -c 'sudo /etc/init.d/docker restart'"

deploy-consul: start-consul-machine compose-up-consul
deploy-tsuru-server: start-tsuru-server-machine compose-up
deploy-tsuru-server-dev: start-tsuru-server-machine build-images compose-up-dev

start-consul-machine:
	@[[ "$$(docker-machine status consul)" != "Running" ]] \
		&& docker-machine start consul \
		|| echo consul machine is running

start-tsuru-server-machine:
	@[[ "$$(docker-machine status tsuru-server)" != "Running" ]] \
		&& docker-machine start tsuru-server \
		|| echo tsuru-server machine is running

start-runner-machine:
	@[[ "$$(docker-machine status runner)" != "Running" ]] \
		&& docker-machine start runner \
		|| echo runner machine is running

check-var-dockerized-setup:
	@[[ -z "${DOCKERIZED_SETUP_DIR}" ]] && echo Variable DOCKERIZED_SETUP_DIR not set \
		&& exit 1 || true

build-images: check-var-dockerized-setup
	@eval "$$(docker-machine env tsuru-server)" \
		&& cd ${DOCKERIZED_SETUP_DIR}/tsuru-api && docker build -t local/tsuru-api . \
		&& cd ${DOCKERIZED_SETUP_DIR}/gandalf && docker build -t local/gandalf . \
		&& cd ${DOCKERIZED_SETUP_DIR}/archive-server && docker build -t local/archive-server . \
		&& cd ${DOCKERIZED_SETUP_DIR}/consul-template && docker build -t local/consul-template . \
		&& cd ${DOCKERIZED_SETUP_DIR}/router-hipache && docker build -t local/router-hipache .

compose-up-consul:
	@eval "$$(docker-machine env consul)" \
		&& COMPOSE_FILE=docker-compose-consul.yml \
		CONSUL_IP=$$(docker-machine ip consul) \
		docker-compose up -d

compose-up:
	@eval "$$(docker-machine env tsuru-server)" \
		&& CONSUL_IP=$$(docker-machine ip consul) \
		TSURU_SERVER_IP=$$(docker-machine ip tsuru-server) \
		HUB_DIR=tsuru \
		docker-compose up -d

compose-up-dev:
	@eval "$$(docker-machine env tsuru-server)" \
		&& CONSUL_IP=$$(docker-machine ip consul) \
		TSURU_SERVER_IP=$$(docker-machine ip tsuru-server) \
		HUB_DIR=local \
		docker-compose up -d

consul-keys:
	$(eval TSURU_SERVER_IP=$(shell docker-machine ip tsuru-server))
	$(eval consul_ip=$(shell docker-machine ip consul))
	@echo Settings consul key tsuru/git/rw-host
	@curl -X PUT -d "${TSURU_SERVER_IP}:2222" http://${consul_ip}:8500/v1/kv/tsuru/git/rw-host
	@echo
	@echo Settings consul key hipache/domain
	@curl -X PUT -d "${TSURU_SERVER_IP}.nip.io" http://${consul_ip}:8500/v1/kv/hipache/domain
	@echo

rm-consul-machine:
	@docker-machine rm consul || true

rm-tsuru-server-machine:
	@docker-machine rm tsuru-server || true

rm-runner-machine:
	@docker-machine rm runner || true

test: set-target setup-user setup-runner add-python-platform add-key deploy-dashboard remove-key
set-target:
	$(eval TSURU_SERVER_IP=$(shell docker-machine ip tsuru-server))
	tsuru target-remove machine-${TSURU_SERVER_IP}
	tsuru target-add -s machine-${TSURU_SERVER_IP} http://${TSURU_SERVER_IP}:8000
setup-user:
	$(eval TSURU_SERVER_IP=$(shell docker-machine ip tsuru-server))
	curl -d "{\"email\":\"clark@dailyplanet.com\",\"password\":\"superman\"}" http://${TSURU_SERVER_IP}:8000/users
	ruby login.rb ${TSURU_SERVER_IP}:8000 clark@dailyplanet.com superman
	tsuru team-create admin || true
	tsuru-admin pool-add default || true
	tsuru-admin pool-teams-add default admin || true
	tsuru key-remove test_tsuru_abcd123 -y || true
setup-runner:
	$(eval tsuru_docker_ip=$(shell docker-machine ip runner))
	tsuru-admin docker-node-add --register address=http://${tsuru_docker_ip}:2375 pool=default
	until tsuru-admin docker-node-list | grep -q ready; do echo Waiting for docker node...; sleep 5; done
add-python-platform:
	tsuru-admin platform-add python --dockerfile https://raw.githubusercontent.com/tsuru/basebuilder/master/python/Dockerfile || true
deploy-tsuru-test:
	$(eval TSURU_SERVER_IP=$(shell docker-machine ip tsuru-server))
	tsuru app-remove -a tsuru-test-abcd123 -y || true
	tsuru app-create tsuru-test-abcd123 python
	rm -rf /tmp/tsuru-test-abcd123
	git clone https://github.com/saliceti/tsuru-test.git /tmp/tsuru-test-abcd123 || true
	cd /tmp/tsuru-test-abcd123 && git push ssh://git@${TSURU_SERVER_IP}:2222/tsuru-test-abcd123.git
	$(eval TIMESTAMP=$(shell date '+%s'))
	curl -sL tsuru-test-abcd123.${TSURU_SERVER_IP}.nip.io/print?string=${TIMESTAMP} | grep -q ${TIMESTAMP}
deploy-dashboard:
	$(eval TSURU_SERVER_IP=$(shell docker-machine ip tsuru-server))
	tsuru app-remove -a dashboard-abcd123 -y || true
	tsuru app-create dashboard-abcd123 python
	rm -rf /tmp/tsuru-dashboard-abcd123
	git clone https://github.com/tsuru/tsuru-dashboard.git /tmp/tsuru-dashboard-abcd123 || true
	cd /tmp/tsuru-dashboard-abcd123 && git push ssh://git@${TSURU_SERVER_IP}:2222/dashboard-abcd123.git
	curl -sL dashboard-abcd123.${TSURU_SERVER_IP}.nip.io | grep -q  "tsuru web dashboard"
add-key:
	rm -f ~/.id_rsa_test_tsuru_abcd123
	ssh-keygen -f ~/.id_rsa_test_tsuru_abcd123 -N ""
	tsuru key-add test_tsuru_abcd123 ~/.id_rsa_test_tsuru_abcd123.pub
	eval $(ssh-agent)
	ssh-add ~/.id_rsa_test_tsuru_abcd123
remove-key:
	tsuru key-remove -y test_tsuru_abcd123
	ssh-add -d ~/.id_rsa_test_tsuru_abcd123
	rm -f ~/.id_rsa_test_tsuru_abcd123
