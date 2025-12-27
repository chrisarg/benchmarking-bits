#!/usr/bin/env perl
use strict;
use warnings;

use Cwd qw(getcwd);
use File::Spec;

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

# Install the Perl dependencies needed for benchmarking
my @dependencies = qw(
  Alien::Bit
  App::cpanminus
  File::Spec
  Getopt::Long
  Util::H2O::More
  Test::More
  Sys::Info
  Sys::Info::Constants
);

# Install the specific modules to be benchmarked
my @comparators = qw(
  Bit::Vector
  Bit::Set
  Lucy::Object::BitVector
);

if ( !have_in_path('cpanm') ) {
    die
"cpanm not found in PATH. Install App::cpanminus first (e.g. via your package manager or 'cpan App::cpanminus').\n";
}

for my $module (@dependencies) {
    run_cmd( 'cpanm', $module );
}

for my $module (@comparators) {
    run_cmd( 'cpanm', $module );
}

# Include dependencies for the C modules
my $cwd         = getcwd();
my %git_modules = (
    CRoaring => {
        url  => 'https://github.com/RoaringBitmap/CRoaring.git',
        post =>
          [ './amalgamation.sh', 'mv -f roaring.c roaring.h ../c-source' ],
    },
    Bit => {
        url  => 'https://github.com/chrisarg/Bit.git',
        post => [
            'GPU=NONE make',
            'mv -f ./include/bit.h ./include/libpopcnt.h '
              . './build/libbit.a ./build/libbit.so ../c-source'
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
if ( $ENV{BENCHMARKING_BITS_CLEANUP} ) {
    while ( my ( $mod, $spec ) = each %git_modules ) {
        my $mod_dir = File::Spec->catdir( $cwd, $mod );
        if ( -d $mod_dir ) {
            print "Removing cloned module directory $mod_dir\n";
            run_cmd( 'rm', '-rf', $mod_dir );
        }
    }
}
