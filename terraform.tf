variable "consul_ip" {
  description = "Tsuru admin consul IP address"
}

provider "consul" {
    address = "${var.consul_ip}:8500"
    datacenter = "DC1"
    scheme = "http"
}

resource "consul_keys" "tsuru" {
    key {
        name = "git_rw_host"
        path = "tsuru/git/rw-host"
        value = "${var.consul_ip}:2222"
    }
    key {
        name = "hipache_domain"
        path = "hipache/domain"
        value = "${var.consul_ip}.nip.io"
    }
}