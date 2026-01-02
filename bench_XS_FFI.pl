#!/home/chrisarg/perl5/perlbrew/perls/bitperl/bin/perl

use v5.38;
use POSIX 'dup2';
dup2 fileno(STDERR), fileno(STDOUT);
use Benchmark ':all';
use base 'sealed';
use sealed 'debug';


use Bit::Set ':all';
use Bit::Set::OO;

use constant SIZE_OF_TEST_BIT => 65536;
use constant SIZEOF_BITDB     => 45;
my $MAX_PUT = 1000;

say "Running sealed performance benchmarks with Perl $^V";

cmpthese 2_000_000, {
    bsoo => sub {
        my $b = Bit::Set->new(SIZE_OF_TEST_BIT);
        $b->bset(2);
        $b->put(3,1);
        die unless $b->get(2) == 1;
        die unless $b->get(3) == 1;
        undef $b;
    },
    sealed => sub : Sealed {
        my Bit::Set $b;
        $b = $b->new(SIZE_OF_TEST_BIT);
        $b->bset(2);
        $b->put(3,1);
        die unless $b->get(2) == 1;
        die unless $b->get(3) == 1;
        undef $b;
    },
    bs => sub {
        my $b = Bit_new(SIZE_OF_TEST_BIT);
        Bit_bset( $b, 2 );
        Bit_put( $b, 3, 1 );
        die unless Bit_get( $b, 2 ) == 1;
        die unless Bit_get( $b, 3 ) == 1;
        Bit_free( \$b );
    }
};
