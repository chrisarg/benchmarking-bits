#!/home/chrisarg/perl5/perlbrew/perls/current/bin/perl
use v5.38;

use Benchmark::CSV;
use Bit::Vector;
use Bit::Set qw(:all);
use Bit::Set::OO;
use File::Spec;
use Getopt::Long;
use Lucy::Object::BitVector;
use Util::H2O::More qw(opt2h2o h2o);
use Test::More;
use Sys::Info;
use Sys::Info::Constants qw( :device_cpu );

my $info = Sys::Info->new;
my $cpu  = $info->device( CPU => 1 )->identify;



my $curr_dir      = File::Spec->curdir();
my $benchmark_dir = File::Spec->catdir( $curr_dir, 'results' );
mkdir $benchmark_dir unless -d $benchmark_dir;

my @opts = qw/bitlen=i iters=i outfile=s batch=i g_seed=i/;
my $o    = h2o {
    bitlen  => 16384,
    iters   => 10,
    outfile => 'benchmark_bitvectors_',
    batch   => 10,
    g_seed  => 100,
  },
  opt2h2o(@opts);
Getopt::Long::GetOptionsFromArray( \@ARGV, $o, @opts );

my $bitveclen = $o->bitlen;
my $iters     = $o->iters;
my $batch     = $o->batch;
my $outfname  = File::Spec->catfile( $benchmark_dir,
    $o->outfile . "LangPerl_Length${bitveclen}_Batch${batch}_CPU${cpu}.csv" );
my $g_seed = $o->g_seed;

say
"Benchmarking creation and destruction of Bit::Vector, Bit::Set, and Bit::Set::OO with bit length $bitveclen for $iters iterations and outputting to $outfname";

my @bit_positions = @{ gen_bit_positions( $bitveclen, $g_seed ) };

# Create two operand bit vectors for bitwise operations

# Bit::Set
my $bs1 = Bit_new($bitveclen);
Bit_set( $bs1, 0, $bitveclen / 2 );
my $bs2 = Bit_new($bitveclen);
Bit_set( $bs2, $bitveclen / 2, $bitveclen - 1 );

# Bit::Set::OO
my $bso1 = Bit::Set->new($bitveclen);
$bso1->set( 0, $bitveclen / 2 );
my $bso2 = Bit::Set->new($bitveclen);
$bso2->set( $bitveclen / 2, $bitveclen - 1 );

# Bit::Vector
my $bv1 = Bit::Vector->new($bitveclen);
$bv1->Interval_Fill( 0, $bitveclen / 2 );
my $bv2 = Bit::Vector->new($bitveclen);
$bv2->Interval_Fill( $bitveclen / 2, $bitveclen - 1 );

# Lucy::Object::BitVector
my $lobv1 = Lucy::Object::BitVector->new( capacity => $bitveclen );
$lobv1->set($_) for 0 .. ( $bitveclen / 2 );
my $lobv2 = Lucy::Object::BitVector->new( capacity => $bitveclen );
$lobv2->set($_) for ( $bitveclen / 2 ) .. ( $bitveclen - 1 );

my %benchmarks = (
    'Bit::Vector_new' => sub {
        my $bv = Bit::Vector->new($bitveclen);
    },
    'Bit::Set_new' => sub {
        my $bs = Bit_new($bitveclen);
        Bit_free( \$bs );
    },
    'Bit::Set::OO_new' => sub {
        my $bso = Bit::Set->new($bitveclen);
    },
    'Lucy::Object::BitVector_new' => sub {
        my $lobv = Lucy::Object::BitVector->new( capacity => $bitveclen );
    },
    'Bit::Vector_PopCount' => sub {
        my $count = $bv1->Norm();
    },
    'Bit::Set_PopCount' => sub {
        my $count = Bit_count($bs1);
    },
    'Bit::Set::OO_PopCount' => sub {
        my $count = $bso1->count();
    },
    'Lucy::Object::BitVector_PopCount' => sub {
        my $count = $lobv1->count();
    },
    'Bit::Vector_Inter' => sub {
        my $bv_and = Bit::Vector->new($bitveclen);
        $bv_and->And( $bv1, $bv2 );
    },
    'Bit::Set_Inter' => sub {
        my $bs_and = Bit_inter( $bs1, $bs2 );
        Bit_free( \$bs_and );
    },
    'Bit::Set::OO_Inter' => sub {
        my $bso_and = $bso1->inter($bso2);
    },
    'Lucy::Object::BitVector_Inter' => sub {
        my $lobv_and = $lobv1->clone;
        $lobv_and->and($lobv2);
    },
    'Bit::Vector_InterCount' => sub {
        my $bv_and = Bit::Vector->new($bitveclen);
        $bv_and->And( $bv1, $bv2 );
        my $bv_count = $bv_and->Norm();
    },
    'Bit::Set_InterCount' => sub {
        my $bs_count = Bit_inter_count( $bs1, $bs2 );
    },
    'Bit::Set::OO_InterCount' => sub {
        my $bso_count = $bso1->inter_count($bso2);
    },
    'Lucy::Object::BitVector_InterCount' => sub {
        my $lobv_and = $lobv1->clone;
        $lobv_and->and($lobv2);
        my $lobv_count = $lobv_and->count();
    },
    'Bit::Vector_FillHalfSeq' => sub {
        my $bv = Bit::Vector->new($bitveclen);
        $bv->Bit_On( $_ ) for @bit_positions;
    },
    'Bit::Set_FillHalfSeq' => sub {
        my $bs = Bit_new($bitveclen);
        Bit_bset( $bs, $_ ) for @bit_positions;
        Bit_free( \$bs );
    },
    'Bit::Set::OO_FillHalfSeq' => sub {
        my $bso = Bit::Set->new($bitveclen);
        $bso->bset($_) for @bit_positions;
    },
    'Lucy::Object::BitVector_FillHalfSeq' => sub {
        my $lobv = Lucy::Object::BitVector->new( capacity => $bitveclen );
        $lobv->set($_) for @bit_positions;
    },
    'Bit::Vector_FillHalfMany' => sub {
        my $bv = Bit::Vector->new($bitveclen);
        $bv->Index_List_Store( @bit_positions );
    },
    'Bit::Set_FillHalfMany' => sub {
        my $bs = Bit_new($bitveclen);
        Bit_aset( $bs, \@bit_positions, scalar @bit_positions );
        Bit_free( \$bs );
    },
    'Bit::Set::OO_FillHalfMany' => sub {
        my $bso = Bit::Set->new($bitveclen);
        $bso->aset( \@bit_positions, scalar @bit_positions );
    },
);

# First ensure results match
my $bitvector_inter = Bit::Vector->new($bitveclen);
$bitvector_inter->And( $bv1, $bv2 );
my $bitvector_count      = $bitvector_inter->Norm();
my $bitset_inter_count   = Bit_count( Bit_inter( $bs1, $bs2 ) );
my $bitsetoo_inter_count = $bso1->inter($bso2)->count();
my $lobv_and             = $lobv1->clone;
$lobv_and->and($lobv2);
my $lucyobjectbitvector_inter_count = $lobv_and->count();
is( $bitvector_count, $bitset_inter_count,
    'Bit::Vector and Bit::Set intersection counts match' );
is( $bitvector_count, $bitsetoo_inter_count,
    'Bit::Vector and Bit::Set::OO intersection counts match' );
is(
    $bitvector_count,
    $lucyobjectbitvector_inter_count,
    'Bit::Vector and Lucy::Object::BitVector intersection counts match'
);
done_testing();

## Benchmarks
my $benchmark_results = Benchmark::CSV->new(
    sample_size => $batch,
    output      => $outfname,
);

while ( my ( $name, $code ) = each %benchmarks ) {
    say "Adding benchmark: $name";
    $benchmark_results->add_instance( $name => $code );
}
$benchmark_results->run_iterations( $iters * $batch );


sub gen_bit_positions ($bitveclen, $seed) {
    die "bitveclen must be > 0\n" unless defined($bitveclen) && $bitveclen > 0;

    my $n = int($bitveclen / 2);

    srand($seed);  # reproducible (global RNG)
    my @pos;
    $#pos = $n - 1;  # pre-size

    for my $i (0 .. $n - 1) {
        $pos[$i] = int(rand($bitveclen));  # values in [0, $bitveclen-1]
    }

    return \@pos;  # return arrayref
}

=pod
# execute as 
perl -e '@bitlen=(128,256,512,1024,2048,4096,8192,16384,32768,65536,131072,262144); system("./bench_bit_vector_cpan.pl","-bitlen=$_","-iters=100",-"batch=1000") for @bitlen;'
=cut
