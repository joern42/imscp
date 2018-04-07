=head1 NAME

 iMSCP::Template::Processor - i-MSCP Template processor

=cut

# i-MSCP - internet Multi Server Control Panel
# Copyright (C) 2010-2018 Laurent Declercq <l.declercq@nuxwin.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA

package iMSCP::Template::Processor;

use strict;
use warnings;
use Carp qw/ croak /;
use iMSCP::Boolean;
use parent 'Exporter';

our @EXPORT_OK = qw/ getBloc getBlocByRef processBloc processBlocByRef processVars processVarsByRef /;

=head1 DESCRIPTION

 The template parser allow to parse pseudo-variables within i-MSCP template files.
 It can parse simple variables or variable tag pairs.

=head1 PUBLIC METHODS

=over 4

=item processVarsByRef( \$tpl, $vars [, $emptyUnknownVars = FALSE ] )

 Param scalarref $tpl Reference to template variable
 Param hashref $vars Reference to hash containing templates variable and their values
 Param boolean $emptyUnknownVars Flag indicating whether unknow variables must be emptied
 Return void, croak on invalid parameters

=cut

sub processVarsByRef( $$;$ )
{
    my ( $tpl, $vars, $emptyUnknownVars ) = @_;

    ref $tpl eq 'SCALAR' or croak( 'Invalid $tpl parameter. Scalar reference expected.' );
    ref $vars eq 'HASH' or croak( 'Invalid $vars parameter. Hash reference expected.' );

    # Process twice to cover cases where there are variables defining other variables
    ${ $tpl } =~ s#(?<!%)\{([a-zA-Z0-9_]+)\}#$vars->{$1} // ( $emptyUnknownVars ? '' : "{$1}" )#ge for 0 .. 1;
}

=item processVars( $tpl, $vars [, $emptyUnknownVars = FALSE ] )

 Param scalarref $tpl Reference to template variable
 Param hashref $vars Reference to hash containing templates variable and their values
 Param boolean $emptyUnknownVars Flag indicating whether unknow variables must be emptied
 Return string Template content, croak on invalid parameters

=cut

sub processVars( $$;$ )
{
    my ( $tpl, $vars, $emptyUnknownVars ) = @_;

    processVarsByRef( \$tpl, $vars, $emptyUnknownVars );
    $tpl;
}

=item getBlocByRef( $tpl, $blcTb, $blcTe [, $iBlcT = false ] )

 Get the first bloc matching the given bloc tags within the given template

 param scalarref $tpl Reference to template variable
 Param string $blcTb Bloc begin tag
 Param string $blcTe Bloc ending tag
 Param bool $iBlcT Flag indicating whether or not bloc tags must be included
 Return string Template bloc, including or not bloc tags, croak on invalid parameters

=cut

sub getBlocByRef( $$$;$ )
{
    my ( $tpl, $blcTb, $blcTe, $iBlcT ) = @_;

    ref $tpl eq 'SCALAR' or croak( 'Invalid $template parameter. Scalar reference expected.' );

    $blcTb = "\Q$blcTb\E" unless ref $blcTb eq 'Regexp';
    $blcTe = "\Q$blcTe\E" unless ref $blcTe eq 'Regexp';
    ( $iBlcT ? ${ $tpl } =~ /([\t ]*$blcTb.*?[\t ]*$blcTe)/s : ${ $tpl } =~ /[\t ]*$blcTb(.*?)[\t ]*$blcTe/s ) ? $1 : '';
}

=item getBloc( $tpl, $blcTb, $blcTe [, $iBlcT = false ] )

 Get the first template bloc matching the given begin and ending tags within the given template

 param string $tpl Template content
 Param string $blcTb Bloc begin tag
 Param string $blcTe Bloc ending tag
 Param bool $iBlcT Flag indicating whether or not bloc tags must be included
 Return string Template bloc, including or not bloc tags, croak on invalid parameters

=cut

sub getBloc( $$$;$ )
{
    my ( $tpl, $blcTb, $blcTe, $iBlcT ) = @_;

    getBlocByRef( \$tpl, $blcTb, $blcTe, $iBlcT );
}

=item processBlocByRef( $tpl, $blcTb, $blcTe, [, $blcC = '' [, $pBlcT = FALSE [, $pBlcC = FALSE [, $blcA = FALSE ] ] ] ] ] )

 Process the given bloc within the given template

 Param scalarref $tpl Reference to template variable
 Param string|Regexp $blcTb Bloc begin tag (should be specified without trailing newline)
 Param string|Regexp $blcTe Bloc ending tag (should be specified without trailing newline)
 Param string|hashref $blcC Bloc content or hash of variables to generate bloc content using current bloc content
 Param bool $pBlcT Flag indicating whether or not bloc tags must be preserved
 Param bool $pBlcC Flag indicating whether or not current bloc content must be preserved
 Param bool $blcA Flag indicating whether or not a new bloc must be added if it doesn't already exist
 Return void, croak on invalid parameters
=cut

sub processBlocByRef( $$$;$$$$ )
{
    my ( $tpl, $blcTb, $blcTe, $blcC, $pBlcT, $pBlcC, $blcA ) = @_;
    $blcC //= '';

    ref $tpl eq 'SCALAR' or croak( 'Invalid $tpl parameter. Scalar reference expected.' );

    my $blcTbReg = ref $blcTb eq 'Regexp' ? $blcTb : "\Q$blcTb\E";
    my $blcTeReg = ref $blcTe eq 'Regexp' ? $blcTe : "\Q$blcTe\E";

    # FIXME Should we act globally (multi-blocs)
    if ( !( ${ $tpl } =~ s%
        (^\n*)                         # Match leading empty lines. Only one is kept and only if bloc tag are kept
            (^[\t ]+|)?($blcTbReg\n?)  # Match leading whitespace, bloc tag and trailing newline
            (.*?)                      # Match current bloc content
            ((?:^[\t ]+)?$blcTeReg\n?) # Match leading whitespaces, bloc ending tag and trailing newline
        %@{ [ ref $blcC eq 'HASH' ? processVars( $4, $blcC ) : $blcC ] }@{ [ $1 && $pBlcT ? "\n" : '' ] }@{ [ $pBlcT ? $2 . $3 : '' ] }@{ [ $pBlcC ? $4 : '' ] }@{ [ $pBlcT ? $5 : '' ] }%msx )
        && $blcA
    ) {
        ${ $tpl } .= "$blcC\n";
        ${ $tpl } .= "$blcTb\n$blcTe\n" if $pBlcT;
    }
}

=item processBloc( $tpl, $blcTb, $blcTe, [, $blcC = '' [, $pBlcT = TRUE [, $pBlcC = TRUE [, $blcA = TRUE ] ] ] ] ] )

 Process the given bloc within the given template

 Param string $tpl Template
 Param string|Regexp $blcTb Bloc begin tag (should be specified without trailing newline)
 Param string|Regexp $blcTe Bloc ending tag (should be specified without trailing newline)
 Param string $blcC Bloc content 
 Param bool $pBlcT Flag indicating whether or not bloc tags must be preserved (default)
 Param bool $pBlcC Flag indicating whether or not current bloc content must be preserved (default)
 Param bool $blcA Flag indicating whether or not a new bloc must be created if it doesn't already exist
 Return string Template content, croak on invalid parameters

=cut

sub processBloc( $$$;$$$$ )
{
    my ( $tpl, $blcTb, $blcTe, $blcC, $pBlcT, $pBlcC, $blcA ) = @_;

    processBlocByRef( \$tpl, $blcTb, $blcTe, $blcC, $pBlcT, $pBlcC, $blcA );
    $tpl;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
