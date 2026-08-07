tpm2_create -C primary.ctx -u ak.pub -r ak.priv -G ecc:ecdsa:null -g sha256 -a "fixedtpm|fixedparent|sensitivedataorigin|userwithauth|restricted|sign"
