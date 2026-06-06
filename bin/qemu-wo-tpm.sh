$HOME/github/build-qemu-riscv/qemu-system-riscv64 \
  -machine virt -cpu rv64 -m 4G -smp 2 \
  -nographic \
  -kernel /usr/lib/u-boot/qemu-riscv64_smode/uboot.elf \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net-device,netdev=net0 \
  -device virtio-rng-pci \
  -drive file=~/images/ubuntu-24.04.4-preinstalled-server-riscv64.img,format=raw,if=virtio
