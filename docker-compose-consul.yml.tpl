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
    command: -server -advertise CONSUL_IP -bootstrap -data-dir=/data/consul

registrator:
    container_name: registrator
    image: gliderlabs/registrator
    volumes:
    - /var/run/docker.sock:/tmp/docker.sock
    environment:
        SERVICE_NAME: registrator
    restart: always
    command: -ip CONSUL_IP -resync 5 consul://CONSUL_IP:8500
