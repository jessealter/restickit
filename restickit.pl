#!/usr/bin/env perl

# Licensing details at end of file

use strict;
use warnings;

use Carp        qw(confess);
use IPC::Cmd qw(can_run);
use constant DEBUG => $ENV{DEBUG};
use feature 'say';

sub debug {
    say "@_" if DEBUG;
}

sub read_config_file {
    my ($filename) = @_;
    my %config;

    open( my $fh, '<', $filename )
      or confess "Could not open file '$filename': $!";

    while ( my $line = <$fh> ) {
        chomp $line;

        # Skip comments and blank lines
        next if $line =~ /^\s*$/ || $line =~ /^\s*#/;

        # Split the line into key and value
        my ( $key, $value ) = split /\s*=\s*/, $line, 2;

        # Remove any surrounding whitespace from the value
        $value =~ s/^\s+|\s+$//g;

        $config{$key} = $value;
    }

    close($fh);

    return \%config;
}

sub show_params {
    debug "BACKUP_PATHS:\t", $ENV{BACKUP_PATHS} // "undefined";
    debug "EXCLUDE_FILE:\t", $ENV{EXCLUDE_FILE} // "undefined";
    debug "DRY_RUN:\t",      $ENV{DRY_RUN}      // "undefined";
    debug " ";
    debug "Retention settings:";
    debug "Minimum snapshots:\t",
      $ENV{MINIMUM_SNAPSHOTS_RETAINED} // "undefined";
    debug "Hourly snapshots:\t",  $ENV{HOURS_RETAINED}  // "undefined";
    debug "Daily snapshots:\t",   $ENV{DAYS_RETAINED}   // "undefined";
    debug "Weekly snapshots:\t",  $ENV{WEEKS_RETAINED}  // "undefined";
    debug "Monthly snapshots:\t", $ENV{MONTHS_RETAINED} // "undefined";
    debug "Yearly snapshots:\t",  $ENV{YEARS_RETAINED}  // "undefined";
}

confess "Can't find restic in \$PATH!" unless can_run('restic');

# Our first argument is the settings file to source to get our backup
# parameters, so peel it off. We'll pass all the other arguments directly
# to restic.
my $prefs_f = shift @ARGV;

# Read the backup parameters into environmental variables
die "Usage: $0 preferences_file\n" unless $prefs_f;
my $config = read_config_file($prefs_f);
%ENV = ( %ENV, %$config );

my @backup_paths = split( ' ', $ENV{BACKUP_PATHS} || "" );
confess "BACKUP_PATHS not defined. What should we be backing up?"
  unless @backup_paths;

show_params();

# If you're backing up a filesystem that you're mounting by FUSE, the inode
# information is misleading at best, so add --ignore-inode.
my @cmd = (
    "restic", "backup",
    "--verbose=2",
    "--exclude=.duplicacy",
    "--exclude=.DS_Store",
    "--tag", "periodic",

    # "-o b2.connections=15",
    grep { defined }
      ( $ENV{EXCLUDE_FILE}, $ENV{DRY_RUN}, @backup_paths, @ARGV ),
);
system(@cmd);

# We don't want to remove any snapshots if this backup failed
if ( $? != 0 ) {
    confess "restic backup failed";
}

# Remove old backup snapshots
@cmd = (
    "restic",   "forget",     "--verbose", "--tag",
    "periodic", "--group-by", "paths,tags",
);

my %policy = (
    'keep-last'    => $ENV{MINIMUM_SNAPSHOTS_RETAINED},
    'keep-hourly'  => $ENV{HOURS_RETAINED},
    'keep-daily'   => $ENV{DAYS_RETAINED},
    'keep-weekly'  => $ENV{WEEKS_RETAINED},
    'keep-monthly' => $ENV{MONTHS_RETAINED},
    'keep-yearly'  => $ENV{YEARS_RETAINED}
);

# Need at least one of these defined
unless ( grep { defined } values %policy ) {
    confess
"Error: You must define at a retention policy, or we can't remove snapshots";
}

foreach my $param ( keys %policy ) {
    if ( defined $policy{$param} ) {
        push @cmd, ( "--$param", $policy{$param} );
    }
}

# Do a dry-run if specified in settings file
push @cmd, ( $ENV{DRY_RUN} // "" );

system(@cmd);

if ( $? != 0 ) {
    confess "restic snapshot pruning failed";
}

# Copyright 2023 Joe Block <jpb@unixorn.net>
# Copyright 2023 Jesse Alter <jesse@jessealter.com>

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Adapted from: restic-driver-script <https://unixorn.github.io/post/restic-backups-on-truenas/>
