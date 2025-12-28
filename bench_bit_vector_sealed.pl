#!/home/chrisarg/perl5/perlbrew/perls/current/bin/perl
use v5.38;

use Benchmark::CSV;
use Bit::Set qw(:all);
use Bit::Set::OO;
use File::Spec;
use Getopt::Long;
use Util::H2O::More qw(opt2h2o h2o);
use Test::More;
use Sys::Info;
use Sys::Info::Constants qw( :device_cpu );
use base 'sealed';
use sealed 'deparse';

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
    $o->outfile . "Sealed_LangPerl_Length${bitveclen}_Batch${batch}_CPU${cpu}.csv" );
my $g_seed = $o->g_seed;

say
"Benchmarking creation and destruction of Bit::Set and Bit::Set::OO (sealed and unsealed) with bit length $bitveclen for $iters iterations and outputting to $outfname";

my @bit_positions = @{ gen_bit_positions( $bitveclen, $g_seed ) };

# Create two operand bit vectors for bitwise operations

# Bit::Set
my $bs1 = Bit_new($bitveclen);
Bit_set( $bs1, 0, $bitveclen / 2 );
my $bs2 = Bit_new($bitveclen);
Bit_set( $bs2, $bitveclen / 2, $bitveclen - 1 );

# Bit::Set::OO_sealed
my Bit::Set $bsos1 = Bit::Set->new($bitveclen);
$bsos1->set( 0, $bitveclen / 2 );
my Bit::Set $bsos2 = Bit::Set->new($bitveclen);
$bsos2->set( $bitveclen / 2, $bitveclen - 1 );

# Bit::Set::OO
my $bso1 = Bit::Set->new($bitveclen);
$bso1->set( 0, $bitveclen / 2 );
my $bso2 = Bit::Set->new($bitveclen);
$bso2->set( $bitveclen / 2, $bitveclen - 1 );

my %benchmarks = (
    'Bit::Set_new' => sub {
        my $bs = Bit_new($bitveclen);
        Bit_free( \$bs );
    },
    'Bit::Set::OO_new' => sub {
        my $bso = Bit::Set->new($bitveclen);
    },
    'Bit::Set::OO::Sealed_new' => sub :Sealed {
      my Bit::Set $bso;
      $bso = $bso->new($bitveclen);
    },
    'Bit::Set_PopCount' => sub {
        my $count = Bit_count($bs1);
    },
    'Bit::Set::OO_PopCount' => sub {
        my $count = $bso1->count();
    },
    'Bit::Set::OO::Sealed_PopCount' => sub :Sealed {
        my $count = $bsos1->count();
    },
    'Bit::Set_Inter' => sub {
        my $bs_and = Bit_inter( $bs1, $bs2 );
        Bit_free( \$bs_and );
    },
    'Bit::Set::OO_Inter' => sub {
        my $bso_and = $bso1->inter($bso2);
    },
    'Bit::Set::OO::Sealed_Inter' => sub :Sealed {
        my $bso_and = $bsos1->inter($bsos2);
    },
    'Bit::Set_InterCount' => sub {
        my $bs_count = Bit_inter_count( $bs1, $bs2 );
    },
    'Bit::Set::OO_InterCount' => sub {
        my $bso_count = $bso1->inter_count($bso2);
    },
    'Bit::Set::OO::Sealed_InterCount' => sub :Sealed {
        my $bso_count = $bsos1->inter_count($bsos2);
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
    'Bit::Set::OO::Sealed_FillHalfSeq' => sub :Sealed {
        my Bit::Set $bsos;
        $bsos = $bsos->new($bitveclen);
        $bsos->bset($_) for @bit_positions;
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
    'Bit::Set::OO::Sealed_FillHalfMany' => sub :Sealed {
        my Bit::Set $bso;
        $bso = $bso->new($bitveclen);
        $bso->aset( \@bit_positions, scalar @bit_positions );
    },
);

# First ensure results match
my $bitset_inter_count   = Bit_count( Bit_inter( $bs1, $bs2 ) );
my $bitsetoo_inter_count = $bso1->inter($bso2)->count();
my $bitsetoosealed_inter_count = $bsos1->inter($bsos2)->count();
is( $bitset_inter_count, $bitsetoo_inter_count,
    'Bit::Set and Bit::Set::OO intersection counts match' );
is( $bitset_inter_count, $bitsetoosealed_inter_count,
    'Bit::Set and Bit::Set::OO_sealed intersection counts match' );

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

sub gen_bit_positions ( $bitveclen, $seed ) {
    die "bitveclen must be > 0\n" unless defined($bitveclen) && $bitveclen > 0;

    my $n = int( $bitveclen * 0.10 );

    srand($seed);      # reproducible (global RNG)
    my @pos;
    $#pos = $n - 1;    # pre-size

    for my $i ( 0 .. $n - 1 ) {
        $pos[$i] = int( rand($bitveclen/2) );    # values in [0, $bitveclen/2]
    }

    return \@pos;                              # return arrayref
}

=pod
# execute as
perl -e '@bitlen=(128,256,512,1024,2048,4096,8192,16384,32768,65536,131072,262144); system("./bench_bit_vector_sealed.pl","-bitlen=$_","-iters=100",-"batch=1000") for @bitlen;'
=cut
