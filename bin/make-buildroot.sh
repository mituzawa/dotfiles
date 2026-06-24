cd ~/github/keystone/build-generic64/buildroot.build

rm -rf build/keystone-examples-*
rm -rf per-package/keystone-examples

cd ~/github/keystone
make buildroot
