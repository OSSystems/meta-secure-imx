## SWUPDATE sign configuration
#Sign with RSA
SWUPDATE_SIGNING  = "RSA"
SWUPDATE_PRIVATE_KEY = "${SECURE_BASE}/conf/keys/swu_rsa_key.pem"
SWUPDATE_PUBLIC_KEY = "${SECURE_BASE}/conf/keys/swu_rsa_pub_key.pem"
SWUPDATE_PASSWORD_FILE = "${SECURE_BASE}/conf/keys/passphrase"
SWU_KEY ?= "${SECURE_BASE}/conf/keys/swu_aes256_key.bin"
