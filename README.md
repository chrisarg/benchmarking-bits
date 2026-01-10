# benchmarking-bits
Benchmarking of the Bit library (single thread, without device acceleration) against alternatives. 

## Description
Runs comparisons against implementations of Bit and the Bit Perl API:

## C
- [Bit](https://github.com/chrisarg/Bit/)
- [CRoaring](https://github.com/RoaringBitmap/CRoaring) 
- [CBitset](https://github.com/lemire/cbitset) (note that we use the version packaged inside CRoaring) 

### Perl
- [Bit::Set](https://metacpan.org/pod/Bit::Set)
- [Bit::Set::OO](https://metacpan.org/pod/Bit::Set::OO)
- [Bit::Vector](https://metacpan.org/pod/Bit::Vector)
- [Lucy::Object::BitVector](https://metacpan.org/dist/Lucy/view/lib/Lucy/Object/BitVector.pm)

The pure Perl implementation  Algorithm::BitVector was not considered because in preliminary experiments was >3 orders of magnitude slower than the others

## Pre-requisites

You will need a:
*  C compiler (gcc and icx have been tested, but clang should work too), 
* a working Perl installation (comes with all xNix systems!) with the `cpanm` package manager (which can installed via e.g. `sudo apt install cpanminus` in Debian/Ubuntu or via the `cpan` tool as : `sudo cpan App::cpanminus`). 
* You will need [perlbrew](https://perlbrew.pl/) which you can install via your OS package manager or by following the instructions on the website.
* A working R (but don't worry about the packages, they will be installed automatically). This is *optional* and if an R is not found, then you will forego the possibility of visualizing your results in a nice way.

Do not worry about messing with your system `perl` ; `perlbrew` will be used to install a version that will only be used for the benchmarking. *After you are done*, you can delete it (see instructions below).  

### "Juicing" up your processor (optional)

Many Linux installations require manual tweaking of the CPU frequency scaling governor for benchmarks. The governor is a kernel component that adjust's the CPU's frequency to load and power management options. If you really want to see how performance is affected by various choices, it may be best to reduce variability due to load dependent frequency scaling. The following script can be executed from the command line to put your processor in `performance` mode:

```bash
sudo ./juice_processor_up.sh performance
```
The argument performance can be replaced by any of the acceptable CPU governor policies, i.e. `performance` ,`powersave` , `ondemand` , `conservative` , `schedutil` if you want to run the benchmarks under a different policy. 

## Installation

I suggest you install to a local directory of choice by cloning the github repository. Run the `install_suite.pl` that will install the Perl via perlbrew dependencies for the Perl comparators and will make the C benchmarking functions. 
* If you are in a system that does not have a discrete GPU, then you may want to do `GPU = NONE install_suite.sh` or `sudo GPU = NONE install_suite.sh`. 
* If you are in an AMD system, then `GPU = AMD install_suite.sh` *should* work (note I have not tested offloading in those devices). 
* If you would like to offload to an Intel GPU (which could be an integrated one!) then you should have the Intel C compiler (e.g. through [oneAPI](https://www.intel.com/content/www/us/en/developer/tools/oneapi/overview.html)) installed and invoke the installation as `GPU = Intel install_suite.sh`. 
* If you omit the environmental variable, the default will be to build everything without GPU support. 
* If the environmental variable BENCHMARKING_BITS_CLEANUP is set, then the git repositories will be removed after installation. 

The install script will also build the C executables that are used to benchmark the C libraries. 
One interesting feature of the install script is that it can use numerous cores to install the custom perl, by providing a single numerical argument, e.g. `GPU = NONE BENCHMARKING_BITS_CLEANUP=1 install_suite.sh 8` will use 8 cores to build the `Bit` library without GPU acceleration and will clean the directories at the end. 

## Benchmarking

**Run the script `batch_run.sh` to execute the benchmarks**:
* `benchmark` = executable that generates C level benchmarks
* `bench_bit_vector_cpan.pl` = contrasts the Bit::Set and Bit::Set::OO libraries against CPAN (Comprehensive Perl Archive Network) alternatives.
* `bench_bit_vector_sealed.pl` = benchmark of sealed and unsealed versions of the package
* `bench_XS_FFI.pl` = benchmark of the XS and the FFI glue for Bit::Set and Bit::Set::OO between versions of 0.10 and the latest (XS based) version of the package at CPAN

**Run the script `bench_XS.sh` to benchmark the XS interface and `sealed` objects** 
This script will downgrade your version of `Bit::Set` to 0.10, run `bench_XS_FFI.pl`, upgrade to the latest versipn, re-run `bench_XS_FFI.pl` and then restore your version of `Bit::Set`. By doing so it will profile the XS interface of `Bit::Set` and `Bit::Set::OO` at the latest version v.s. the FFI interface that was used in version 0.10. It will also profile the `sealed` objects that resolves method calls at compile time against the traditional Object Oriented method invokation in Perl, which resolves methods at runtime. 

## Visualization

The R script `visualize.R` can be used to visualize the benchmarks from `batch_run.sh`; it does require `base-r`, and the R packages  `ggplot2`,  `data-table`, `viridisLite` to make the results look nice! These packages will be installed via the installer script, but wi

The R script `visualize_XS_sealed.R` visualizes the results of the XS and `sealed` benchmarks.

Both scripts look into the folders `results` and `results_XS_sealed` for their input; if you happen to have run the benchmarks in more than one processors, and have stored the results there,  these R scripts will happily break down the results by processor type when visualizing. 

## Benchmark and plot everything

If you simply want to run everything and are happy with the default parameters for benchmarks, run the following:

```bash
sudo ./bench_summarize_all.sh
```
The script will elevate your processor to maximum performance, run all the benchmark scripts and visualizes and then reset it back to a less powerhungry mode (see section *After you are done* for restoring CPU governor policies).

## After you are done

You can keep the custom perl interpreter (installed under the alias bitperl) and the R packages installed by doing nothing!
However, if you want to restore your environment's state, execute `cleanup.sh`.
If you ended up putting your processor in `performance` and want to tune things down a bit, 
run the script:
```bash
sudo ./squeeze_processor.sh 
```
that will attempt to set the processor to `schedutil` or on `ondemand`. If those are not available, it will cycle through the available governors that are not `performance` and will assign the first one that is available (likely one of `powersave` or `conservative`) .

## TO-DO

* Add benchmarks for the XS versions of the`Bit::Set::DB` and `Bit::Set::DB::OO` interfaces 
* Added multi-threaded (OpenMP benchmarks)
* Add GPU benchmarks

## License

MIT License. See the LICENSE file for details.

## Author

Christos Argyropoulos December 2025
Sealed benchmarks were contributed by Joe Schaefer and later expanded by yours truly. 