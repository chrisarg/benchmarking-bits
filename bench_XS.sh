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
./bench_XS_FFI.pl

# install version 0.11 of Bit::Set from CPANN
perlbrew exec --with bitperl cpanm --uninstall --force Bit::Set >/dev/null 2>&1
perlbrew exec --with bitperl cpanm --force Bit::Set@0.11 >/dev/null 2>&1
echo "Installed Bit::Set version 0.11"
# run the benchmark script against version 0.11
./bench_XS_FFI.pl

# reinstall the original version of Bit::Set
perlbrew exec --with bitperl cpanm --force Bit::Set@"$BIT_SET_VERSION" >/dev/null 2>&1

echo "Restored Bit::Set version $BIT_SET_VERSION"
