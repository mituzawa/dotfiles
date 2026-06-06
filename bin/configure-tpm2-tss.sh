cd $HOME/github/tpm2-tss; ./bootstrap
cd $HOME/github/tpm2-tss; ./configure \
  --prefix=$HOME/opt/qemu-riscv \
  --enable-unit \
  --enable-integration
