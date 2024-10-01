storage "file" {
  path = "./data"
  node_id = "node1"
}
listener "tcp" {
  address = "l4ws1901.messlabs.com:8200"
  tls_disable = 0
  tls_cert_file = "./cert/myvault.crt"
  tls_key_file = "./cert/myvault.key"
  tls_min_version = "tls12"
  tls_cipher_suites = "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256, TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
}

disable_mlock = true

api_addr = "https://L4WS1901:8200"
cluster_addr = "https://L4WS1901:8201"
ui = true
