=head1 NAME

 iMSCP::TemplateParser - i-MSCP Template parser

=cut

# i-MSCP - internet Multi Server Control Panel
# Copyright (C) 2010-2018 by internet Multi Server Control Panel
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

package iMSCP::TemplateParser;

use strict;
use warnings;
use iMSCP::Debug;
use parent 'Exporter';

our @EXPORT = qw/ processByRef process getBloc getBlocByRef replaceBlocByRef replaceBloc /;

=head1 DESCRIPTION

 Library for processing of i-MSCP templates

=head1 PUBLIC METHODS

=over 4

=item processByRef( \%data, \$tpl [, $emptyUnknownVars = FALSE ] )

 Substitutes pseudo-variables within the given template using the given data

 Param hash \%data A hash of data where the keys are the pseudo-variable names and the values, the replacement values
 Param scalarref $tpl Reference to template content
 Param boolean $emptyUnknownVars Flag indicating whether unknown variables must be emptied
 Return void, die on invalid parameters

=cut

sub processByRef( $$;$ )
{
    my ( $data, $tpl, $emptyUnknownVars ) = @_;

    ref $tpl eq 'SCALAR' or die( 'Invalid $tpl parameter. Scalar reference expected.' );
    ref $data eq 'HASH' or die( 'Invalid $data parameter. Hash reference expected.' );

    ${ $tpl } =~ s#(?<!%)\{([a-zA-Z0-9_]+)\}#$data->{$1} // ( $emptyUnknownVars ? '' : "{$1}" )#ge for 0..1;
    return;
}

=item process( \%data, $tpl [, $emptyUnknownVars = FALSE ] )

 Substitutes pseudo-variables within the given template using the given data

 Param hash \%data A hash of data where the keys are the pseudo-variable names and the values, the replacement values
 Param string ref $tpl The template content to be processed
 Param boolean $emptyUnknownVars Flag indicating whether unknown variables must be emptied
 Return string Template content

=cut

sub process( $$;$ )
{
    my ( $data, $tpl, $emptyUnknownVars ) = @_;

    processByRef( $data, \$tpl, $emptyUnknownVars );
    $tpl;
}

=item getBlocByRef( $beginTag, $eTag, \$tpl [, $iTags = false ] )

 Get the first block matching the given begin and ending tags within the given template

 Param string $beginTag Bloc begin tag
 Param string $eTag Bloc ending tag
 param scalarref $tpl Reference to template content
 Param bool $iTags OPTIONAL Flag indicating whether or not begin and ending tag should be included in result
 Return string Bloc content (including or not the begin and ending tags), die on invalid $tpl parameter

=cut

sub getBlocByRef( $$$;$ )
{
    my ( $bTag, $eTag, $tpl, $iTags ) = @_;

    ref $tpl eq 'SCALAR' or die( 'Invalid $tpl parameter. Scalar reference expected.' );

    $bTag = "\Q$bTag\E" unless ref $bTag eq 'Regexp';
    $eTag = "\Q$eTag\E" unless ref $eTag eq 'Regexp';
    ( $iTags ? ${ $tpl } =~ /([\t ]*$bTag.*?[\t ]*$eTag)/s : ${ $tpl } =~ /[\t ]*$bTag(.*?)[\t ]*$eTag/s ) ? $1 : '';
}

=item getBloc( $bTag, $eTag, $tpl [, $iTags = false ] )

 Get the first block matching the given begin and ending tags within the given template

 Param string $bTag Bloc begin tag
 Param string $eTag Bloc ending tag
 param string $tpl Template content
 Param bool $iTags OPTIONAL Flag indicating whether or not begin and ending tag should be included in result
 Return string Bloc content (including or not the begin and ending tags), die on invalid $tpl parameter

=cut

sub getBloc( $$$;$ )
{
    my ( $bTag, $eTag, $tpl, $iTags ) = @_;

    getBlocByRef( $bTag, $eTag, \$tpl, $iTags );
}

=item replaceBlocByRef( $bTag, $eTag, $repl, \$tpl [, $pTags = false ] )

 Replace all blocs matching the given begin and ending tags within the given template
 
 Note that when passing Regexp for begin or ending tags and that you want preserve tags,
 you're responsible for adding capturing parentheses.

 Param string|Regexp $bTag Bloc begin tag
 Param string|Regexp eTag Bloc ending tag
 Param string $repl Bloc replacement string
 param scalarref $tpl Reference to template content
 Param bool $pTags OPTIONAL Flag indicating whether or not begin and ending tags must be preverved
 Return void, die on invalid parameter $tpl parameter

=cut

sub replaceBlocByRef( $$$$;$ )
{
    my ( $bTag, $eTag, $repl, $tpl, $pTags ) = @_;

    ref $tpl eq 'SCALAR' or die( 'Invalid $tpl parameter. Scalar reference expected.' );

    if ( $pTags ) {
        $bTag = "(\Q$bTag\E)" unless ref $bTag eq 'Regexp';
        $eTag = "(\Q$eTag\E)" unless ref $eTag eq 'Regexp';
        ${ $tpl } =~ s/[\t ]*$bTag.*?[\t ]*$eTag/$repl$1$2/gs;
        return
    }

    $bTag = "\Q$bTag\E" unless ref $bTag eq 'Regexp';
    $eTag = "\Q$eTag\E" unless ref $eTag eq 'Regexp';
    ${ $tpl } =~ s/[\t ]*$bTag.*?[\t ]*$eTag/$repl/gs;
    return;
}

=item replaceBloc( $bTag, $eTag, $repl, $tpl [, $pTags = false ] )

 Replace all blocs matching the given begin and ending tags within the given template
 
 Note that when passing Regexp for begin or ending tags and that you want preserve tags,
 you're responsible for adding capturing parentheses.

 Param string|Regexp $bTag Bloc begin tag
 Param string|Regexp $eTag Bloc ending tag
 Param string $repl Bloc replacement string
 param string $tpl Template content
 Param bool $pTags OPTIONAL FLag indicating whether or not begin and ending tags must be preverved
 Return string Template content

=cut

sub replaceBloc( $$$$;$ )
{
    my ( $bTag, $eTag, $repl, $tpl, $pTags ) = @_;

    replaceBlocByRef( $bTag, $eTag, $repl, \$tpl, $pTags );
    $tpl;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
