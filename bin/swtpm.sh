mkdir -p /tmp/emulated_tpm

swtpm socket \
  --tpmstate dir=/tmp/emulated_tpm \
  --ctrl type=unixio,path=/tmp/emulated_tpm/swtpm-sock \
  --log level=20 \
  --tpm2 \
  --daemon
