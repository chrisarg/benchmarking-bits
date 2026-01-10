#!/usr/bin/perl
use v5.38;

use Cwd qw(getcwd);
use File::Spec;

# Data
# Perl dependencies needed for benchmarking
my @dependencies = qw(
  Benchmark::CSV
  File::Spec
  FFI::Platypus
  FFI::Platypus::Buffer
  Getopt::Long
  sealed@8.5.6
  Sys::Info
  Sys::Info::Constants
  Test::More
  Unix::Processors
  Util::H2O::More
);

# Install the specific modules to be benchmarked
my @comparators = qw(
  Bit::Vector
  Bit::Set
  Lucy::Object::BitVector
);

#install R packages needed to visualize the results
my @r_packages = qw(
  ggplot2
  data.table
  nlme
  viridisLite);

if ( !have_in_path('cpanm') ) {
    die "cpanm not found in PATH. Install App::cpanminus first "
      . "(e.g. via your package manager or 'cpan App::cpanminus').\n";
}

## process command line arguments and environment variables
# ony argument is the number of parallel processes to use for perlbrew install; take it from command line or default to 1
my $procs = 1;
if (@ARGV) {
    $procs = $ARGV[0];
}
my $GPU                   = $ENV{GPU} // 'NONE';
my $cleanup_after_install = $ENV{BENCHMARKING_BITS_CLEANUP} ? 1 : 0;

# install optimized Perl via perlbrew if not already installed
my @perl = (
    qw(install -Doptimize=-O3 --noman -n --switch -j),
    $procs, qw(--as bitperl 5.42.0)
);
# check if bitperl is already installed
my @perls = `perlbrew list`;
chomp @perls;


my $bitperl_installed = 0;
for my $perl (@perls) {
    if ( $perl =~ /bitperl/ ) {
        $bitperl_installed = 1;
    }
}
if ($bitperl_installed) {
    print "Perl 'bitperl' already installed (skipping perlbrew install)\n";
} else {
    print "Installing optimized Perl 'bitperl' via perlbrew...\n";
    run_cmd( 'perlbrew', @perl );
}


# install Perl dependencies and comparators  into the optimized Perl
run_cmd("GPU=$GPU perlbrew exec --with bitperl cpanm Alien::Bit");
for my $module (@dependencies) {
    run_cmd( 'perlbrew', 'exec', '--with', 'bitperl', 'cpanm', $module);
}
for my $module (@comparators) {
    run_cmd( 'perlbrew', 'exec', '--with', 'bitperl', 'cpanm', $module );
}

# Include dependencies for the C modules
# make directory c-libs if it does not exist
my $c_libs_dir = File::Spec->catdir( getcwd(), 'c-libs' );
mkdir $c_libs_dir unless -d $c_libs_dir;

my $cwd         = getcwd();
my %git_modules = (
    CRoaring => {
        url  => 'https://github.com/RoaringBitmap/CRoaring.git',
        post => [ './amalgamation.sh', 'mv -f roaring.c roaring.h ../c-libs' ],
    },
    Bit => {
        url  => 'https://github.com/chrisarg/Bit.git',
        post => [
            "GPU=$GPU make",
            'mv -f ./include/bit.h ./include/libpopcnt.h '
              . './build/libbit.a ./build/libbit.so ../c-libs'
        ],
    },
);

while ( my ( $mod, $spec ) = each %git_modules ) {
    my $mod_dir = File::Spec->catdir( $cwd, $mod );
    if ( -d $mod_dir ) {
        print "$mod already exists at $mod_dir (skipping clone)\n";
    }
    else {
        run_cmd( 'git', 'clone', $spec->{url}, $mod_dir );
    }

    if (   $spec->{post}
        && ref( $spec->{post} ) eq 'ARRAY'
        && @{ $spec->{post} } )
    {
        my $old = getcwd();
        chdir $mod_dir or die "failed to chdir to $mod_dir: $!\n";
        for my $post_cmd ( @{ $spec->{post} } ) {
            run_cmd($post_cmd);
        }
        chdir $old or die "failed to chdir back to $old: $!\n";
    }
}

# if environment variable BENCHMARKING_BITS_CLEANUP is set to a true value, remove the cloned git repos
if ($cleanup_after_install) {
    while ( my ( $mod, $spec ) = each %git_modules ) {
        my $mod_dir = File::Spec->catdir( $cwd, $mod );
        if ( -d $mod_dir ) {
            print "Removing cloned module directory $mod_dir\n";
            run_cmd( 'rm', '-rf', $mod_dir );
        }
    }
}

# run make to build the C benchmark executable
run_cmd('make');

# now install R packages needed for visualization
my @installed_r_packages = ();
unless ( have_in_path('Rscript') ) {
    warn "Rscript not found in PATH, skipping R package installation\n";
}
else {
    my $packages_str = join( "','", @r_packages );
    my $r_cmd        = qq{
        needed <- c('$packages_str');
        installed <- rownames(installed.packages());
        missing <- needed[!needed %in% installed];
        if(length(missing) > 0) {
            install.packages(missing, repos='https://cloud.r-project.org/', quiet=TRUE);
            cat(paste(missing, collapse=' '))
        }
    };

    # Replace all newlines and extra whitespace with single spaces
    $r_cmd =~ s/\s+/ /g;
    $r_cmd =~ s/^\s+|\s+$//g;    # trim leading/trailing whitespace
    my $output = `Rscript -e "$r_cmd" `;
    chomp $output;
    if ($output) {
        @installed_r_packages = split /\s+/, $output;
        say "x" x 80;
        print "Installed R packages: "
          . join( ', ', @installed_r_packages ) . "\n";
        say "x" x 80;
    }
    else {
        print "All R packages already installed\n";
    }
}

# now modify cleanup_sh to replace REGEX_LIST_HERE with the list of the R packages installed above or NULL
if (@installed_r_packages) {

    # read cleanup_sh
    my $cleanup_sh_path = File::Spec->catfile( $cwd, 'cleanup.sh' );
    open my $fh, '<', $cleanup_sh_path
      or die "failed to open $cleanup_sh_path for reading: $!\n";
    my $content = do { local $/; <$fh> };
    close $fh;

    # put the list of R packages installed above
    my $packages_str = join( ' ', @installed_r_packages );
    $content =~ s/NULL/$packages_str/g;

    # write back cleanup.sh
    open my $fh_out, '>', $cleanup_sh_path
      or die "failed to open $cleanup_sh_path for writing: $!\n";
    print $fh_out $content;
    close $fh_out;
}

# make directory for the results
my $results_dir = File::Spec->catdir( $cwd, 'results' );
mkdir $results_dir unless -d $results_dir;
$results_dir = File::Spec->catdir( $cwd, "results_XS_sealed" );
mkdir $results_dir unless -d $results_dir;

# change all perl scripts to use the optimized perl. Obtain the list of perl scripts by scanning the current directory for files matching bench_*.pl
opendir( my $dh, $cwd ) or die "failed to opendir $cwd: $!\n";
my @perl_scripts;
while ( my $entry = readdir($dh) ) {
    if ( $entry =~ /^bench_.*\.pl$/ && -f File::Spec->catfile( $cwd, $entry ) )
    {
        push @perl_scripts, $entry;
    }
}
closedir($dh);

# change the shebang line of each perl script to use the perl we just installed
for my $script (@perl_scripts) {
    my $script_path = File::Spec->catfile( $cwd, $script );
    open my $fh, '<', $script_path
      or die "failed to open $script_path for reading: $!\n";
    my @lines = <$fh>;
    close $fh;

    # Change the shebang line to use the optimized perl
    if ( @lines && $lines[0] =~ /^#!.*perl/ ) {
        $lines[0] = "#!"
          . File::Spec->catfile(
            $ENV{HOME}, 'perl5', 'perlbrew', 'perls',
            'bitperl',  'bin',   'perl'
          ) . "\n";
    }

    open my $fh_out, '>', $script_path
      or die "failed to open $script_path for writing: $!\n";
    print $fh_out @lines;
    close $fh_out;
}

## functions
sub shell_quote {
    my ($s) = @_;
    $s = '' if !defined $s;

    # POSIX-ish single-quote escaping: ' -> '"'"'
    $s =~ s/'/'"'"'/g;
    return "'$s'";
}

sub run_cmd {
    my (@cmd) = @_;
    my $cmd_str;
    if ( @cmd == 1 ) {

        # Treat a single argument as raw shell command text.
        $cmd_str = $cmd[0];
    }
    else {
        # Quote each token and join; still runs via shell (string form).
        $cmd_str = join ' ', map { shell_quote($_) } @cmd;
    }
    print "+ $cmd_str\n";
    system($cmd_str);    # string form => runs via shell
    if ( $? == -1 ) {
        die "failed to execute command: $!\n";
    }
    my $exit = $? >> 8;
    if ( $exit != 0 ) {
        die "command failed (exit $exit): $cmd_str\n";
    }
}

sub have_in_path {
    my ($exe) = @_;
    for my $dir ( File::Spec->path() ) {
        my $p = File::Spec->catfile( $dir, $exe );
        return 1 if -x $p;
    }
    return 0;
}

# install a function that checks if we received a SIGINT (Ctrl-C) and cleanup
local $SIG{INT} = local $SIG{TERM} = local $SIG{HUP} = local $SIG{QUIT} = sub {
    print "Received SIGINT, cleaning up...\n";

# if environment variable BENCHMARKING_BITS_CLEANUP is set to a true value, remove the cloned git repos
    while ( my ( $mod, $spec ) = each %git_modules ) {
        my $mod_dir = File::Spec->catdir( $cwd, $mod );
        if ( -d $mod_dir ) {
            print "Removing cloned module directory $mod_dir\n";
            run_cmd( 'rm', '-rf', $mod_dir );
        }
    }

    # remove perlbrew installed perl if it was installed
    print "Removing perlbrew installed perl 'bitperl'\n";
    my @perls = `perlbrew list`;
    chomp @perls;
    for my $perl (@perls) {
        if ( $perl =~ /^bitperl\b/ ) {
            print "Found installed perl 'bitperl', removing it...\n";
            run_cmd( 'perlbrew', 'uninstall', '-f', 'bitperl' );
        }
    }

    # remove R packages that were installed by this script
    if (@installed_r_packages) {
        print "Removing R packages: "
          . join( ', ', @installed_r_packages ) . "\n";
        my $packages_str = join( "','", @installed_r_packages );
        run_cmd( 'Rscript', '-e', "remove.packages(c('$packages_str'))" );
    }

    # replace the value R_PACKAGES_TO_REMOVE to NULL in cleanup.sh
    my $cleanup_sh_path = File::Spec->catfile( $cwd, 'cleanup.sh' );
    open my $fh, '<', $cleanup_sh_path
      or die "failed to open $cleanup_sh_path for reading: $!\n";
    my $content = do { local $/; <$fh> };
    close $fh;
    $content =~ s/R_PACKAGES_TO_REMOVE=.+\n$/R_PACKAGES_TO_REMOVE=NULL\n/g;
    open my $fh_out, '>', $cleanup_sh_path
      or die "failed to open $cleanup_sh_path for writing: $!\n";
    print $fh_out $content;
    close $fh_out;
    exit 1;
}
