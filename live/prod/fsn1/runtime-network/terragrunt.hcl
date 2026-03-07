terraform {
  source = "../../../../modules/private_network"
}

inputs = {
  name            = "runtime-network-prod-fsn1"
  ip_range        = "10.42.0.0/16"
  subnet_ip_range = "10.42.1.0/24"
  network_zone    = "eu-central"
}
