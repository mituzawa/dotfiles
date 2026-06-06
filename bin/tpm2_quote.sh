tpm2_quote \
    -c ak.ctx \
    -l sha256:0,1,16 \
    -q nonce.bin \
    -m quote.msg \
    -s quote.sig \
    -o quote.pcrs -F values
