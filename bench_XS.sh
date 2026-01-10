#!/bin/bash

# Configuration
bitlen=(128 256 512 1024 2048 4096 8192 16384)
iter=10
batch=1000

# find the version of Bit::Set currently installed and store it in a variable
BIT_SET_VERSION=$(perlbrew exec --with bitperl perl -MBit::Set -e 'print $Bit::Set::VERSION' )
echo "Current Bit::Set version is $BIT_SET_VERSION"
SEALED_VERSION=$(perlbrew exec --with bitperl perl -Msealed -e 'print $sealed::VERSION' )
echo "Current sealed version is $SEALED_VERSION"

# install version 0.10 of Bit::Set from CPANN
perlbrew exec --with bitperl cpanm --uninstall --force Bit::Set >/dev/null 2>&1
perlbrew exec --with bitperl cpanm --force Bit::Set@0.10 >/dev/null 2>&1
echo "Installed Bit::Set version 0.10"
# run the benchmark script against version 0.10
for len in "${bitlen[@]}"; do
    echo "Running Perl benchmark with bitlen=$len"
./bench_XS_FFI.pl --bitlen="$len" -iters="$iter" -batch="$batch" -mode=FFI
done

# install latest version of Bit::Set from CPANN
perlbrew exec --with bitperl cpanm --uninstall --force Bit::Set >/dev/null 2>&1
perlbrew exec --with bitperl cpanm --force Bit::Set >/dev/null 2>&1
latest_version=$(perlbrew exec --with bitperl perl -MBit::Set -e 'print $Bit::Set::VERSION' )
echo "Installed Bit::Set version $latest_version"
# run the benchmark script against latest version
for len in "${bitlen[@]}"; do
    echo "Running Perl benchmark with bitlen=$len"
./bench_XS_FFI.pl --bitlen="$len" -iters="$iter" -batch="$batch" -mode=XS
done


# reinstall the original version of Bit::Set
perlbrew exec --with bitperl cpanm --force Bit::Set@"$BIT_SET_VERSION" >/dev/null 2>&1

echo "Restored Bit::Set version $BIT_SET_VERSION"
