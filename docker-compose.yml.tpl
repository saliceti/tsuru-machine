consul:
    container_name: consul
    image: progrium/consul
    ports:
    - "8300:8300"
    - "8301:8301"
    - "8301:8301/udp"
    - "8302:8302"
    - "8302:8302/udp"
    - "8400:8400"
    - "8500:8500"
    - "53:53/udp"
    volumes:
    - /data/consul:/data/consul
    environment:
        SERVICE_NAME: consul
    restart: always
    command: -server -advertise TSURU_ADMIN_IP -bootstrap

registrator:
    container_name: registrator
    image: gliderlabs/registrator
    volumes:
    - /var/run/docker.sock:/tmp/docker.sock
    environment:
        SERVICE_NAME: registrator
    restart: always
    command: -ip TSURU_ADMIN_IP -resync 5 consul://TSURU_ADMIN_IP:8500

consul-template:
    container_name: consul-template
    image: tsuru/consul-template
    volumes:
    - /var/run/docker.sock:/tmp/docker.sock
    - /data/tsuru:/data/tsuru
    - /data/router:/data/router
    - /data/gandalf:/data/gandalf
    - /data/archive-server:/data/archive-server
    environment:
        SERVICE_NAME: consul-template
    restart: always

mongo:
    container_name: mongo
    image: mongo
    environment:
        SERVICE_NAME: mongo
    restart: always
    ports:
    - "27017:27017"

redis:
    container_name: redis
    environment:
        SERVICE_NAME: redis
    restart: always
    ports:
    - "6379:6379"
    image: redis

registry:
    container_name: registry
    environment:
        SERVICE_NAME: registry
    restart: always
    ports:
    - "5000:5000"
    image: registry

router-hipache:
    container_name: router-hipache
    environment:
        SERVICE_NAME: router-hipache
    restart: always
    ports:
    - "80:8080"
    volumes:
    - /data/router:/data/router
    image: tsuru/router-hipache

tsuru-api:
    container_name: tsuru-api
    environment:
        SERVICE_NAME: tsuru-api
    restart: always
    ports:
    - "8000:8000"
    volumes:
    - /data/tsuru:/data/tsuru
    image: tsuru/tsuru-api
    command: api --config=/data/tsuru/tsuru.conf

archive-server:
    container_name: archive-server
    environment:
        SERVICE_NAME: archive-server
    restart: always
    ports:
    - "3031:3031"
    - "3032:3032"
    volumes:
    - /data/archive-server:/data/archive-server
    - /data/gandalf:/data/gandalf
    image: tsuru/archive-server

gandalf:
    container_name: gandalf
    environment:
        SERVICE_NAME: gandalf
    restart: always
    ports:
    - "8001:8001"
    volumes:
    - /data/gandalf:/data/gandalf
    - /data/tsuru:/data/tsuru
    - /var/run/docker.sock:/tmp/docker.sock
    image: tsuru/gandalf
