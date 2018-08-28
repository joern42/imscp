package Package::Alias;
{
    $Package::Alias::VERSION = '0.13';
}
# ABSTRACT: Alias one namespace as another

use strict qw/vars subs/;
use Carp;
use 5.006; # for INIT

our $BRAVE;
our $DEBUG;

sub alias {
    my $class = shift;
    my %args  = @_;

    while (my ($alias, $orig) = each %args) {
        if (scalar keys %{$alias . "::" } && ! $BRAVE) {
            carp "Cowardly refusing to alias over '$alias' because it's already in use";
            next;
        }

        *{$alias . "::"} = \*{$orig . "::"};
        print STDERR __PACKAGE__ . ": '$alias' is now an alias for '$orig'\n"
            if $DEBUG;
    }
}

sub import {
    my $class = shift;
    my %args  = @_;

    while (my ($alias, $orig) = each %args) {
        my ($alias_pm, $orig_pm) = ($alias, $orig);
        foreach ($alias_pm, $orig_pm) {
            s/::/\//g;
            $_ .= '.pm';
        }

        next if exists $INC{$alias_pm};
        my $caller = caller;
        eval "{package $caller; use $orig;}";
        confess $@ if $@;
        $INC{$alias_pm} = $INC{$orig_pm};
    }

    alias($class, @_);
}

1;

__END__
