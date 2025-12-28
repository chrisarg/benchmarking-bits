# benchmarking-bits
Benchmarking of the Bit library against alternatives 

## Description
Runs comparisons against implementations of Bit and the Bit Perl API:

### Perl
- [Bit::Set](https://metacpan.org/pod/Bit::Set)
- [Bit::Set::OO](https://metacpan.org/pod/Bit::Set::OO)
- [Bit::Vector](https://metacpan.org/pod/Bit::Vector)
- [Lucy::Object::BitVector](https://metacpan.org/dist/Lucy/view/lib/Lucy/Object/BitVector.pm)

## C
- [Bit](https://github.com/chrisarg/Bit/)
- [CRoaring](https://github.com/RoaringBitmap/CRoaring) 
- [CBitset](https://github.com/lemire/cbitset) (note that we use the version packaged inside CRoaring) 

The pure Perl implementation  Algorithm::BitVector was not considered because in preliminary experiments was >3 orders of magnitude slower than the others

## Pre-requisites

You will need a C compiler (gcc and icx have been tested, but clang should work too), a working Perl installation (comes with all xNix systems!) with the `cpanm` package manager (which can installed via e.g. `sudo apt install cpanminus` in Debian/Ubuntu or via the `cpan` tool as : `udo cpan App::cpanminus`). 
I strongly suggest you consider NOT using the perl installation that came with your operating system, but install a custom perl interpreter using [perlbrew](https://perlbrew.pl/).
If you would like to:
 * compare the performance of sealed Perl packages, you will need to install the sealed package from CPAN, e.g. via `cpanm sealed`. 
 * visualize the data, you will also need  a working R installation (see under **Visualization** for the R dependencies)

## Installation

I suggest you install to a local directory of choice by cloning the github repository. Once you do so, open the Perl scripts and change the first line (the shebang line!) to reflect the location of the perl interpreter you would like to use. Run the `install_suite.pl` that will install the Perl dependencies for the Perl comparators and will make the C benchmarking functions. If you are in a system that does not have a discrete GPU, then you may want to do `GPU = NONE install_suite.sh` or `sudo GPU = NONE install_suite.sh`. If you are in an AMD system, then `GPU = AMD install_suite.sh` *should* work (note I have not tested offloading in those devices). If you would like to offload to an Intel GPU (which could be an integrated one!) then you should have the Intel C compiler (e.g. through [oneAPI](https://www.intel.com/content/www/us/en/developer/tools/oneapi/overview.html)) installed and invoke the installation as `GPU = Intel install_suite.sh`.
If the environmental variable BENCHMARKING_BITS_CLEANUP is set, then the git repositories will be removed after installation. The install script will also build the C executables that are used to benchmark the C libraries. 

## Benchmarking

Run the script `batch_run.sh` to execute the benchmarks:
* `benchmark` = executable that generates C level benchmark
* `bench_bit_vector_cpan.pl` = contrasts the Bit::Set and Bit::Set::OO libraries against CPAN (Comprehensive Perl Archive Network) alternatives.

Run the script `batch_run_sealed.sh` (which calls `bench_bit_vector_sealed.pl`) to compare sealed (at compile time) v.s. dynamiclly resolved (at runtime) Object Oriented method invokations in the Bit::Set::OO interface. Idea and code was kindly contributed by Joe Schaefer. 

## Visualization

The R script `visualize.R` can be used to visualize the benchmarks from `batch_run.sh`; it does require `base-r`, and the R packages  `ggplot2` and `data-table` to make the results look nice!

The R script `see_the_seal.R` visualizes the results of the sealed benchmark.

## License

MIT License. See the LICENSE file for details.

## Author

Christos Argyropoulos December 2025