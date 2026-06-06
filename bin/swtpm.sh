if [ ! -d /tmp/emulated_tpm ]; then
  mkdir /tmp/emulated_tpm
fi

swtpm socket \
  --tpmstate dir=/tmp/emulated_tpm \
  --ctrl type=unixio,path=/tmp/emulated_tpm/swtpm-sock \
  --log level=20 \
  --tpm2 \
  --daemon
