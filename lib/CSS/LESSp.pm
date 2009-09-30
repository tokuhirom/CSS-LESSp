package CSS::LESSp;

use warnings;
use strict;

our $VERSION = '0.01';

sub parse {
	my $self = shift;
	my $string = shift;
	# real parsing
	my $specialSelectorFlag = my $lastChar = my $buffer = my $mode = my $stop = "";
	my @return = my @selectors = ();
	my %styles = ();
	my $level = my $specialSelectorLevel = 0;
	my %css = my %variables = ();
	$string =~ s/^\xEF\xBB\xBF\x0A//;
	for ( split //, $string ) {
		$buffer .= $_;		
		if ( $mode ) {
			$buffer =~ s/.$// if $mode eq "delete";
			if ( length($stop) == 2 and $lastChar.$_ eq $stop ) { $mode = "" };
			if ( length($stop) == 1 and $_ eq $stop ) {	$mode = "" };
			$lastChar = $_;
			next;
		}
		next if /\n/;
		#
		# The program
		#
		if ( /\}/ or /\;/ ) {
			# clearing some buffer data
			$buffer =~ s/.$//;					
			$buffer =~ s/^\s*//;
			$buffer =~ s/\s*$//;
			# defining the selector								
			my $selector = "";			
			for ( 0..$level ) {
				$selector .= " ".$selectors[$_] if $selectors[$_];
			}			
			$selector =~ s/\s*\:/\:/g; # :hover, :focus ...			
			$selector =~ s/^\s*//;
			if ( $buffer ) {				
				# if it's a property and rule						
				if ( $buffer =~ s/^\s*(.*)\s*\:\s*(.*)\s*$// ) {					
					my $property = $1;
					my $value = $2;
					# different rule-set property
					if ( $value =~ /^(#|.)(.*)\[(.*)\]$/ ) {
						my $targetSelector = $1.$2;
						my $targetProperty = $3;
						$targetProperty =~ s/\'//g;
						$targetProperty =~ s/\"//g;
						$targetProperty =~ s/\s*//g;
						for ( @{$css{$targetSelector}} ) {
							$value = $1 if /^$targetProperty\s*\:\s*(.*)\s*$/;
						}
					}
					# variable access
					while ( $value =~ /\@(\w+\-*\w*)/ ) {						
						my $word = $1;
						my $var;
						for ( my $l=$level; $l>=0; $l-- ) {					
							$var = $variables{$l}{$word} if !$var;						
						}		
						$var = "0" if !$var;
						$value =~ s/\@$word/$var/;
					}
					# expression (+,-,*,/)
					if ( $value =~ /(\d+)\s*(px|pt|em|%)*\s*(\+|\-|\*|\/)\s*((\d+)\s*(px|pt|em|%)*|\d+)/ ) {						
						my $eval = $value;
						my $removed = $1 if $eval =~ s/(px|pt|em|%)//g;
						if ( $eval !~ /[a-z]/i and $eval = eval($eval) ) {
							$eval .= "$removed" if $eval;							
							$value = $eval;
						};
					}
					# expression with color
					if ( $value =~ /\#[abcdef0123456789]{3,6}/i and $value =~ /(\+|\-|\*|\/)/ ) {
						# replacing #fff to #ffffff
						$value .= " " if $value =~ /\#[abcdef0123456789]{3}$/i;
						while ( $value =~ /\#([abcdef0123456789]{3})[^abcdef0123456789]/i ) {							
							my $color = $1;
							my $replace;
							for ( split (//, $color) ) {
								$replace .= $_ x 2;
							}
							$value =~ s/\#$color/\#$replace/;
						}
						# replacing #ffffff to 255 255 255
						my @rgb = ( $value, $value, $value );						
						$rgb[0] =~ s/\#([abcdef0123456789]{2})[abcdef0123456789]{4}/\#$1/ig;
						$rgb[1] =~ s/\#[abcdef0123456789]{2}([abcdef0123456789]{2})[abcdef0123456789]{2}/\#$1/ig;
						$rgb[2] =~ s/\#[abcdef0123456789]{4}([abcdef0123456789]{2})/\#$1/ig;
						my $return = "";
						for ( @rgb ) {
							while ( /\#([abcdef0123456789]{2})[^abcdef0123456789]/i ) {
								my $dec = hex($1);
								s/\#$1/$dec/;
							}													
							if ( !/[a-z]/i and my $eval = eval ) {
								while ( $eval > 255 ) {
									$eval -= 255;
								}
								$return .= sprintf("%X", $eval);
							}							
						}
						$value = "#".lc $return if $return;
					}
					# variable definition
					if ( $property =~ /^\@(\w+\-*\w*)/ ) {
						$variables{$level}{$1} = $value;						
						$property = $value = "";						
					}
					$buffer = "$property: $value" if $property and $value;					
				}
				# nested rules
				if ( $buffer =~ /^(\..*)$/ or $buffer =~ /^(\#.*)$/ ) {
					my $target = $1;
					$target =~ s/\s*\>\s*/ /g;
					$target =~ s/\s*\:\s*/\:/g;								
					$buffer = join(";\n\t", @{$css{$target}}) if $css{$target};
				}
				push @{$styles{$selector}}, $buffer if $buffer;				
			}
			if ( /\}/ ) {
				# clean variables by this level
				%{$variables{$level}} = ();
				# dump if special selector
				if ( $specialSelectorFlag ) {			
					# if special selector make leveled
					for my $rule ( @{$styles{$selector}} ) {
						push @return, ("\t" x $level) . "$rule;\n";
					}
					delete $styles{$selector};
					$specialSelectorFlag = 0 if $specialSelectorLevel == $level;
					push @return, ("\t" x ($level-1)) . "}\n\n";					
				} else {
					# dump all rules for this selector
					push @return, "$selector { \n";
					for my $rule ( @{$styles{$selector}} ) {					
						push @{$css{$selector}}, $rule;
						push @return, "\t" if $selector;
						push @return, $rule.";\n";
					}
					push @return, "}\n\n" if $selector;
					# delete those rules
					delete $styles{$selector};
				}
				$level--;				
			}
			$buffer = "";			
		}
		#
		# selectors
		if ( /\{/ ) {			
			# clearing some buffer data
			$buffer =~ s/.$//g;	
			$buffer =~ s/^\s*//; 
			$buffer =~ s/\s*$//;	
			# leveling up
			$level++;	
			# setting this level selector name
			$selectors[$level] = $buffer;						
			# dump every root rule gathered by now
			if ( $styles{""} ) {
				push @return, join(";\n", @{$styles{""}}).";\n\n";
				delete $styles{""};
			}
			# Special selector "@"							
			if ( $buffer =~ /^\@/ ) {
				$specialSelectorLevel = $level if !$specialSelectorFlag;
				$specialSelectorFlag = 1;				
			}			
			push @return, ( "\t" x ($level-1) )."$buffer { \n" if $specialSelectorFlag;			
			$buffer = "";
		}
		#
		#
		#
		if ( /\"/ or /\'/ ) { $mode = "skip"; $stop = $_ };
		if ( /\(/ ) { $mode = "skip"; $stop = ")" };
		if ( $lastChar =~ /\// and /\// ) { $mode = "delete"; $stop = "\n";	$buffer =~ s/..$// }
		if ( $lastChar =~ /\// and /\*/ ) { $mode = "delete"; $stop = "*/";	$buffer =~ s/..$// };		
		$lastChar = $_;
	}	
	return @return;
}

1;

=head1 NAME

CSS::LESSp - LESS for perl. Parse .less files and returns valid css (lesscss.org for more info about less files)

=head1 SYNOPSIS

  use CSS::LESSp;
  
  my $css = CSS::LESSp->parse($file);

=head1 DESCRIPTION

This module is designed to parse and compile .less files in to .css files.

About the documentation and syntax of less files please visit lesscss.org 

=head1 BUGS

You can not use variables access from specific rules. 

You can't do this

  #defaults {
	@width: 960px;
  }

  .comment {
    width: #defaults[@width];
  }

All other bugs should be reported via
L<http://rt.cpan.org/Public/Dist/Display.html?Name=CSS-LESSp>
or L<bug-CSS-LESSp@rt.cpan.org>.

=head1 AUTHOR

Ivan Drinchev <drinchev@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2009.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
