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
## Installation

Run the `install_suite.pl` that will install the Perl dependencies for the Perl comparators and will make the C benchmarking functions.
If the environmental variable BENCHMARKING_BITS_CLEANUP is set, then the git repositories will be removed after installation.

## Benchmarking

Run the script `batch_run.sh` to execute the benchmarks 

## Visualization

The R script `visualize.R` can be used to visualize the results; it does require `ggplot2` to make things look nice!

## License

MIT License. See the LICENSE file for details.

## Author

Christos Argyropoulos December 2025