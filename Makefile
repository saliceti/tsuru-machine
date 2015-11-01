.PHONY: smoke-test

all: docker-tsuru-admin deploy-tsuru-admin docker-no-tls consul-keys

dev: docker-tsuru-admin deploy-tsuru-admin-dev docker-no-tls

docker-no-tls:
	$(eval TSURU_ADMIN_IP=$(shell docker-machine ip docker-tsuru-admin))
	@docker-machine create \
		--engine-opt dns=${TSURU_ADMIN_IP} \
		--engine-opt dns=8.8.8.8 \
		--engine-opt dns-search=service.consul \
		--engine-opt host=tcp://0.0.0.0:2375 \
		--engine-env DOCKER_TLS=no \
		--engine-insecure-registry registry.service.consul:5000 \
		-d virtualbox docker-no-tls \
			|| echo Already created
	@docker-machine ssh docker-no-tls \
		"sudo sh -c 'echo -e \"nameserver ${TSURU_ADMIN_IP}\nsearch service.consul\nnameserver 192.168.0.1\nnameserver 0.0.0.0\" > /etc/resolv.conf'"

rm-docker-no-tls:
	@docker-machine rm docker-no-tls

docker-tsuru-admin:
	@docker-machine create \
	    --engine-opt dns=172.17.42.1 \
	    --engine-opt dns=8.8.8.8 \
	    --engine-opt dns-search=service.consul \
	    --engine-opt tlsverify=false \
	    -d virtualbox docker-tsuru-admin \
			|| echo Already created

rm-docker-tsuru-admin:
	@docker-machine rm docker-tsuru-admin

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
	@sed -e "s/TSURU_ADMIN_IP/$$(docker-machine ip docker-tsuru-admin)/g" \
		-e "s@image: tsuru/@image: @g" docker-compose.yml.tpl \
		> docker-compose.yml

deploy-tsuru-admin: start-tsuru-admin render-compose-yaml compose-up

compose-up:
	@eval "$$(docker-machine env docker-tsuru-admin)" \
		&& docker-compose up -d

render-compose-yaml:
	@sed "s/TSURU_ADMIN_IP/$$(docker-machine ip docker-tsuru-admin)/g" docker-compose.yml.tpl > docker-compose.yml

start-docker-no-tls:
	@[[ "$$(docker-machine status docker-no-tls)" != "Running" ]] \
		&& docker-machine start docker-no-tls \
		|| echo docker-no-tls is running

consul-keys:
	@terraform apply -var consul_ip=$$(docker-machine ip docker-tsuru-admin)
