#!/usr/bin/env perl
use strict;
use warnings;

use FindBin;
use File::Temp qw(tempdir);
use Test::More;

my $script = "$FindBin::Bin/../restickit.pl";
ok( -f $script, 'restickit.pl exists' ) or done_testing(), exit;

my $dir = tempdir( CLEANUP => 1 );

# Stub restic: append argv to $RESTIC_LOG, one arg per line, invocations
# delimited by INVOCATION/END markers, then exit 0.
my $stub = "$dir/restic";
open my $fh, '>', $stub or die "open stub: $!";
print {$fh} <<'STUB';
#!/usr/bin/env perl
use strict;
use warnings;
open my $log, '>>', $ENV{RESTIC_LOG} or die $!;
print {$log} join( "\n", 'INVOCATION', @ARGV, 'END' ), "\n";
close $log;
exit 0;
STUB
close $fh;
chmod 0755, $stub;

my $log_file = "$dir/restic.log";
my $conf     = "$dir/settings.conf";

sub run_restickit {
    my (%opts) = @_;

    open my $c, '>', $conf or die "open conf: $!";
    print {$c} "BACKUP_PATHS = /tmp/a /tmp/b\n";
    print {$c} "EXCLUDE_FILE = /tmp/excludes\n";
    print {$c} "MINIMUM_SNAPSHOTS_RETAINED = 5\n";
    if ( defined $opts{group_by} ) {
        print {$c} "GROUP_BY = $opts{group_by}\n";
    }
    if ( defined $opts{dry_run} ) {
        print {$c} "DRY_RUN = $opts{dry_run}\n";
    }
    close $c;

    unlink $log_file;
    local $ENV{PATH}       = "$dir:$ENV{PATH}";
    local $ENV{RESTIC_LOG} = $log_file;
    delete local $ENV{DRY_RUN};
    delete local $ENV{GROUP_BY};

    # quotemeta the paths so spaces or shell metacharacters in the checkout
    # directory or TMPDIR don't split them
    my $cmd = join ' ', map { quotemeta } ( $^X, $script, $conf );
    my $out = `$cmd 2>&1`;
    my $rc  = $?;
    my $tag =
        !defined $opts{dry_run} ? 'DRY_RUN unset'
      : length $opts{dry_run}   ? "DRY_RUN=$opts{dry_run}"
      : 'DRY_RUN set to empty string';
    is( $rc, 0, "$tag: restickit.pl exits 0" ) or diag "output: $out";

    open my $l, '<', $log_file or die "open log: $!";
    my @lines = <$l>;
    chomp @lines;
    close $l;

    my ( @invocations, @current );
    for my $line (@lines) {
        if    ( $line eq 'INVOCATION' ) { @current = () }
        elsif ( $line eq 'END' )        { push @invocations, [@current] }
        else                            { push @current, $line }
    }
    return @invocations;
}

for my $dry ( undef, '--dry-run', '' ) {
    my $tag =
        !defined $dry  ? 'DRY_RUN unset'
      : length $dry    ? "DRY_RUN=$dry"
      :                  'DRY_RUN set to empty string';
    my @inv = run_restickit( dry_run => $dry );
    is( scalar @inv, 2, "$tag: two restic invocations (backup, forget)" );
    next unless @inv == 2;

    for my $i ( 0, 1 ) {
        my $name = $i == 0 ? 'backup' : 'forget';
        my @bad  = grep { !defined || length == 0 } @{ $inv[$i] };
        ok( !@bad, "$tag/$name: no empty-string or undef args" )
          or diag 'bad args: ', explain \@bad;
    }

    if ( defined $dry && length $dry ) {
        ok( scalar( grep { $_ eq '--dry-run' } @{ $inv[0] } ),
            "$tag: backup args include --dry-run" );
        ok( scalar( grep { $_ eq '--dry-run' } @{ $inv[1] } ),
            "$tag: forget args include --dry-run" );
    }
    else {
        ok( !scalar( grep { $_ eq '--dry-run' } @{ $inv[1] } ),
            "$tag: forget args omit --dry-run" );
        ok( scalar( grep { /^--keep-/ } @{ $inv[1] } ),
            "$tag: forget args include --keep-* retention flags" );
    }
}

# GROUP_BY picks the forget grouping. Unset falls back to restic's own default;
# an empty value is passed through untouched, because that is how grouping is
# switched off.
for my $case (
    { label => 'GROUP_BY unset',      set => undef,        expect => 'host,paths' },
    { label => 'GROUP_BY=host,tags',  set => 'host,tags',  expect => 'host,tags' },
    { label => 'GROUP_BY=paths,tags', set => 'paths,tags', expect => 'paths,tags' },
    { label => 'GROUP_BY empty',      set => '',           expect => '' },
  )
{
    my @inv = run_restickit( group_by => $case->{set} );
    is( scalar @inv, 2, "$case->{label}: two restic invocations (backup, forget)" )
      or next;

    my @forget = @{ $inv[1] };
    my ($idx) = grep { $forget[$_] eq '--group-by' } 0 .. $#forget;
    ok( defined $idx, "$case->{label}: forget args include --group-by" ) or next;
    is( $forget[ $idx + 1 ], $case->{expect},
        "$case->{label}: groups by $case->{expect}" );
}

done_testing();
