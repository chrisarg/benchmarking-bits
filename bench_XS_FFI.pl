#!/home/chrisarg/perl5/perlbrew/perls/bitperl/bin/perl

use v5.38;
use base 'sealed';
use sealed 'debug';

use Benchmark::CSV;
use Bit::Set ':all';
use Bit::Set::OO;
use File::Spec;
use Getopt::Long;
use POSIX 'dup2';
dup2 fileno(STDERR), fileno(STDOUT);
use Sys::Info;
use Sys::Info::Constants qw( :device_cpu );
use Util::H2O::More      qw(opt2h2o h2o);

my $info = Sys::Info->new;
my $cpu  = $info->device( CPU => 1 )->identify;

my $curr_dir      = File::Spec->curdir();
my $benchmark_dir = File::Spec->catdir( $curr_dir, "results_XS_sealed" );
mkdir $benchmark_dir unless -d $benchmark_dir;

my @opts = qw/bitlen=i iters=i outfile=s mode=s/;
my $o    = h2o {
    bitlen  => 16384,
    iters   => 10,
    outfile => 'benchmark_APIsealed',
    batch   => 10000,
    mode    => 'XS',
  },
  opt2h2o(@opts);
Getopt::Long::GetOptionsFromArray( \@ARGV, $o, @opts );

my $bitveclen = $o->bitlen;
my $iters     = $o->iters;
my $batch     = $o->batch;

my $mode = $o->mode;
if ( $mode ne 'XS' && $mode ne 'FFI' ) {
    die "Invalid mode specified. Use 'XS' or 'FFI'.\n";
}
my $outfname = File::Spec->catfile( $benchmark_dir,
    $o->outfile
      . "_Length${bitveclen}_Batch${batch}_Mode${mode}_CPU${cpu}.csv" );
say
  "Benchmarking XS and sealed object performance in Bit::Set, and Bit::Set::OO"
  . " with bit length $bitveclen for $iters iterations, batch size $batch, and "
  . "outputting to $outfname using mode $mode in perl $^V";

my @indices1 = ( 0 .. $bitveclen - 1 );
my @indices2 = ( 0 .. $bitveclen / 2 );
my @indices3 = ( 0 .. $bitveclen / 4 );
my @indices4 = ( 0 .. $bitveclen / 8 );

my %benchmarks = (
    "CreateSetPut_OO" => sub {
        my $b = Bit::Set->new($bitveclen);
        $b->bset(2);
        $b->put( 3, 1 );
        die unless $b->get(2) == 1;
        die unless $b->get(3) == 1;
        undef $b;
    },
    "CreateSetPut_Sealed" => sub : Sealed {
        my Bit::Set $b;
        $b = $b->new($bitveclen);
        $b->bset(2);
        $b->put( 3, 1 );
        die unless $b->get(2) == 1;
        die unless $b->get(3) == 1;
        undef $b;
    },
    "CreateSetPut_Procedural" => sub {
        my $b = Bit_new($bitveclen);
        Bit_bset( $b, 2 );
        Bit_put( $b, 3, 1 );
        die unless Bit_get( $b, 2 ) == 1;
        die unless Bit_get( $b, 3 ) == 1;
        Bit_free( \$b );
    },
    "CreateAset100pct_OO" => sub {
        my $b = Bit::Set->new($bitveclen);
        $b->aset( \@indices1 );
        undef $b;
    },
    "CreateAset100pct_Sealed" => sub : Sealed {
        my Bit::Set $b;
        $b = $b->new($bitveclen);
        $b->aset( \@indices1 );
        undef $b;
    },
    "CreateAset100pct_Procedural" => sub {
        my $b = Bit_new($bitveclen);
        Bit_aset( $b, \@indices1 );
        Bit_free( \$b );
    },
    "CreateAset50pct_OO" => sub {
        my $b = Bit::Set->new($bitveclen);
        $b->aset( \@indices2 );
        undef $b;
    },
    "CreateAset50pct_Sealed" => sub : Sealed {
        my Bit::Set $b;
        $b = $b->new($bitveclen);
        $b->aset( \@indices2 );
        undef $b;
    },
    "CreateAset50pct_Procedural" => sub {
        my $b = Bit_new($bitveclen);
        Bit_aset( $b, \@indices2 );
        Bit_free( \$b );
    },
    "CreateAset25pct_OO" => sub {
        my $b = Bit::Set->new($bitveclen);
        $b->aset( \@indices3 );
        undef $b;
    },
    "CreateAset25pct_Sealed" => sub : Sealed {
        my Bit::Set $b;
        $b = $b->new($bitveclen);
        $b->aset( \@indices3 );
        undef $b;
    },
    "CreateAset25pct_Procedural" => sub {
        my $b = Bit_new($bitveclen);
        Bit_aset( $b, \@indices3 );
        Bit_free( \$b );
    },
    "CreateAset12.5pct_OO" => sub {
        my $b = Bit::Set->new($bitveclen);
        $b->aset( \@indices4 );
        undef $b;
    },
    "CreateAset12.5pct_Sealed" => sub : Sealed {
        my Bit::Set $b;
        $b = $b->new($bitveclen);
        $b->aset( \@indices4 );
        undef $b;
    },
    "CreateAset12.5pct_Procedural" => sub {
        my $b = Bit_new($bitveclen);
        Bit_aset( $b, \@indices4 );
        Bit_free( \$b );
    },
);

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
