#!/usr/bin/perl

# i-MSCP - internet Multi Server Control Panel
# Copyright (C) 2010 by internet Multi Server Control Panel
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
#
# @category		i-MSCP
# @copyright	2010 - 2011 by i-MSCP | http://i-mscp.net
# @author		Daniel Andreca <sci2tech@gmail.com>
# @version		SVN: $Id: Dialog.pm 4803 2011-07-05 22:45:42Z sci2tech $
# @link			http://i-mscp.net i-MSCP Home Site
# @license		http://www.gnu.org/licenses/gpl-2.0.html GPL v2

package iMSCP::Dialog::Whiptail;

use strict;
use warnings;

use FileHandle;
use iMSCP::Debug;
use iMSCP::Execute qw/execute/;
use Exporter;
use Common::SingletonClass;
use Term::ReadKey;

use vars qw/@ISA @EXPORT/;
@ISA = ("Common::SingletonClass", 'Exporter');
@EXPORT = qw/msgbox yesno passwordbox/;



sub _init{
	my $self	= shift;
	debug((caller(0))[3].': Starting...');

	$self->{autosize} = '';

	$self->{'_opts'}->{'clear'}					= '';
	$self->{'_opts'}->{'defaultno'}				= undef;
	$self->{'_opts'}->{'default-item'}			= undef;
	$self->{'_opts'}->{'fb'}					= undef;
	$self->{'_opts'}->{'nocancel'}				= '';
	$self->{'_opts'}->{'yes-button'}			= undef;
	$self->{'_opts'}->{'no-button'}				= undef;
	$self->{'_opts'}->{'ok-button'}				= undef;
	$self->{'_opts'}->{'cancel-button'}			= undef;
	$self->{'_opts'}->{'noitem'}				= undef;
	$self->{'_opts'}->{'separate-output'}		= undef;
	$self->{'_opts'}->{'output-fd'}				= undef;
	$self->{'_opts'}->{'title'}					= undef;
	$self->{'_opts'}->{'backtitle'}				= undef;
	$self->{'_opts'}->{'scrolltext'}			= '';
	$self->{'_opts'}->{'topleft'}				= undef;

	$self->_find_bin('whiptail');
	$self->_getConsoleSize();

	debug((caller(0))[3].': Ending...');
	0;
}

sub _getConsoleSize{
	my $self = shift;
	debug((caller(0))[3].': Starting...');
	my ($columns, $lines, undef, undef) = GetTerminalSize();
	$self->{'lines'} = $lines - 3;
	$self->{'columns'} = $columns - 2;
	debug((caller(0))[3].": Lines->$self->{'lines'}");
	debug((caller(0))[3].": Columns->$self->{'columns'}");
	debug((caller(0))[3].': Ending...');
}

sub _find_bin {
	debug((caller(0))[3].': Starting...');

	my ($self, $variant)	= (shift, shift);
	my ($rs, $stdout, $stderr);
	$rs = execute("which $variant", \$stdout, \$stderr);
	debug((caller(0))[3].": Found $stdout") if $stdout;
	fatal((caller(0))[3].": Can't find whiptail binary $stderr") if $stderr;

	$self->{'bin'} = $stdout if $stdout;
	fatal((caller(0))[3].': Can`t find whiptail binary '.$variant) unless (-x $self->{'bin'});

	debug((caller(0))[3].': Ending...');
}

sub _strip_formats {
	my ($self, $text)	= (shift, shift);
	debug((caller(0))[3].': Starting...');
	$text =~ s!\\Z[0-9bBuUrRn]!!gmi;
	debug((caller(0))[3].': Ending...');
	return($text);
}

sub _buildCommand {
	my $self = shift;
	debug((caller(0))[3].': Starting...');
	my $command = '';
	foreach my $prop (keys %{$self->{'_opts'}}){
		if(
			defined($self->{'_opts'}->{$prop})
		){
			$command .= " --$prop ";
			if (ref $self->{'_opts'}->{$prop} eq 'ARRAY') {
				$command .= $self->_clean("@{$self->{'_opts'}->{$prop}}")
			}elsif($self->{'_opts'}->{$prop} !~ /^\d+$/ && $self->{'_opts'}->{$prop}){
					$command .= '\''.$self->_clean($self->{'_opts'}->{$prop}).'\'';
			} elsif($self->{'_opts'}->{$prop} =~ /^\d+$/){
				$command .= $self->{'_opts'}->{$prop};
			}
		}
	}
	debug((caller(0))[3].": command parametters -> ".$command);
	debug((caller(0))[3].': Ending...');
	return $command;
}

sub _clean{
	my ($self, $text) = (shift, shift);
	debug((caller(0))[3].': Starting...');
	#$text =~ s!\\!\\\\!g;
	$text =~ s!'!"!g;
	debug((caller(0))[3].': Ending...');
	return $text;
}

sub _restoreDefaults{
	my $self = shift;
	debug((caller(0))[3].': Starting...');
	foreach my $prop (keys %{$self->{'_opts'}}){
		if(!(grep $_ eq $prop, qw/title backtitle colors begin/)){
			$self->{'_opts'}->{$prop} = undef;
		}
	}
	$self->{'_opts'}->{'begin'} = [1,0];
	debug((caller(0))[3].': Ending...');
}

sub _execute{
	my ($self, $text, $init, $mode, $background) = (shift, shift, shift, shift, shift || 0);
	debug((caller(0))[3].': Starting...');

	$self->endGauge();

	$text = $self->_strip_formats($text) unless( exists $self->{'_opts'}->{'colors'} );

	my $command = $self->_buildCommand();
	$text = $self->_clean($text);
	$init = $init ? $init : '';

	my $height = defined $self->{'autosize'} ? 0 : ($self->{'lines'});
	my $width = defined $self->{'autosize'} ? 0 : ($self->{'columns'});

	debug((caller(0))[3].": $self->{'bin'} $command --$mode '$text' $height $width $init");

	my ($return, $rv);
	$rv = execute("$self->{'bin'} $command --$mode '$text' $height $width $init", undef, \$return);

	debug((caller(0))[3].': Returned text: '.$return) if($return);

	$self->_init() if($self->{'autoreset'});

	debug((caller(0))[3].': Ending...');
	wantarray ? return ($rv, $return) : $return;
}

sub _textbox{
	debug((caller(0))[3].': Starting...');

	my $self = shift;
	my $text = shift;
	my $mode = shift;
	my $init = shift || 0;

	my $autosize = $self->{'autosize'};
	$self->{'autosize'} = "";
	my $begin = $self->{'_opts'}->{'begin'};
	$self->{'_opts'}->{'begin'} = undef;
	my ($rv, $rs) = $self->_execute($text, $init, $mode);
	$self->{'_opts'}->{'begin'} = $begin;
	$self->{'autosize'} = $autosize;

	debug((caller(0))[3].': Ending...');
	wantarray ? return ($rv, $rs) : $rs;
}

sub set{
	debug((caller(0))[3].': Starting...');

	my $self	= shift;
	my $param	= shift;
	my $value	= shift;
	my $return	= undef;

	if($param  && exists $self->{'_opts'}->{$param}){
		$return						= $self->{'_opts'}->{$param};
		$self->{'_opts'}->{$param}	= $value;
	}

	debug((caller(0))[3].': Ending...');
	$return;
}
########################################################################################

sub checkbox{
	debug((caller(0))[3].': Starting...');

	my $self = shift;
	my $text = shift;
	my @init = (@_);
	my $opts = '';

	$opts .= "$_ '' on " foreach(@init);

	debug((caller(0))[3].': Ending...');
	return $self->_textbox($text, 'checklist', (@init +1)." $opts");
}

sub radiolist{
	debug((caller(0))[3].': Starting...');

	my $self = shift;
	my $text = shift;

	my @init = (@_);

	my $opts = '';
	$opts .= "'$_' '' ".($opts ? " off " : "on ") foreach (@init);

	debug((caller(0))[3].': Ending...');
	return $self->_textbox($text, 'radiolist', (@init +1)." $opts");
}

sub msgbox{
	debug((caller(0))[3].': Starting...');

	my $self = shift;
	my $text = shift;

	debug((caller(0))[3].': Ending...');
	return $self->_textbox($text, 'msgbox');
}

sub yesno{
	debug((caller(0))[3].': Starting...');

	my $self = shift;
	my $text = shift;

	my ($rv, undef) = ($self->_textbox($text, 'yesno'));

	debug((caller(0))[3].': Ending...');
	return $rv;
}

sub inputbox{
	debug((caller(0))[3].': Starting...');

	my $self = shift;
	my $text = shift;
	my $init = shift || '';

	debug((caller(0))[3].': Ending...');
	return $self->_textbox($text, 'inputbox', $init);
}

sub passwordbox{
	debug((caller(0))[3].': Starting...');

	my $self = shift;
	my $text = shift;
	my $init = shift || '';

	$self->{'_opts'}->{'insecure'} = '';

	debug((caller(0))[3].': Ending...');
	return $self->_textbox($text, 'passwordbox', "'$init'");
}

sub startGauge{
	my $self = shift;
	my $text = shift;
	my $init = shift || 0; #initial value

	debug((caller(0))[3].': Starting...');

	$self->{'gauge'} ||= {};
	if (defined $self->{'gauge'}->{'FH'}) {
		return(0);
	}

	$text = $self->_clean($text);
	$init = $init ? " $init" : 0;

	my $height = $self->{'autosize'} ? 0 : ($self->{'lines'});
	my $width = $self->{'autosize'} ? 0 : ($self->{'columns'});

	my $begin = $self->{'_opts'}->{'begin'};
	$self->{'_opts'}->{'begin'} = undef;

	my $command = $self->_buildCommand();

	$command = "$self->{'bin'} $command --gauge '$text' $height $width $init";

	$self->{'_opts'}->{'begin'} = $begin;

	debug((caller(0))[3].": $command");

	$self->{'gauge'}->{'FH'} = new FileHandle;
	$self->{'gauge'}->{'FH'}->open("| $command") || error((caller(0))[3].": Can`t start gauge!");
	$SIG{PIPE} = \&endGauge;
	my $rv = $? >> 8;
	$self->{'gauge'}->{'FH'}->autoflush(1);
	debug((caller(0))[3].": Returned value $rv");
	debug((caller(0))[3].': Ending...');
	$rv;
}

sub needGauge{
	debug((caller(0))[3].': Starting...');

	my $self	= shift;

	debug((caller(0))[3].': Ending...');

	return 0 if $self->{'gauge'}->{'FH'};
	1;
}

sub setGauge{
	my $self	= shift;
	my $value	= shift;
	my $text	= shift || undef;

	debug((caller(0))[3].': Starting...');

	return 0 unless $self->{'gauge'}->{'FH'};

	if($text){
		$text = "XXX\n$value\n".$self->_clean($text)."\nXXX\n" ;
	} else {
		$text = "$value\n";
	}

	debug((caller(0))[3].": $text");

	my $fh = $self->{'gauge'}->{'FH'};

	print $fh $text;
	$SIG{PIPE} = \&endGauge;

	debug((caller(0))[3].': Ending...');

	return(((defined $self->{'gauge'}->{'FH'}) ? 1 : 0));

}

sub endGauge{
	my $self = iMSCP::Dialog->new();

	debug((caller(0))[3].': Starting...');

	return 0 unless ref $self->{'gauge'}->{'FH'};
	$self->{'gauge'}->{'FH'}->close();
	delete($self->{'gauge'});

	debug((caller(0))[3].': Ending...');
	0;
}

#sub infobox <text> <height> <width> # todo
#sub textbox <file> <height> <width> # todo
#sub menu <text> <height> <width> <listheight> [tag item] ... # todo

sub fselect{fatal((caller(0))[3].': Not supported');}
sub tailbox{fatal((caller(0))[3].': Not supported');}
sub editbox{fatal((caller(0))[3].': Not supported');}
sub dselect{fatal((caller(0))[3].': Not supported');}

1;

__END__
