use strict;
use warnings;
use IO::File;
use Test::More;
use CSS::LESSp;

###############################################################################
# figure out how many JS files we're going to run through for testing
my @files = <t/less/*.less>;
plan tests => scalar @files;

###############################################################################
# test each of the JS files in turn
foreach my $file (@files) {
    (my $min_file = $file) =~ s/\.less$/\.css/;
    my $str = slurp( $file );
    my $min = slurp( $min_file );
    my @res = CSS::LESSp->parse( $str );

    is( join("",@res), $min, $file );
}

###############################################################################
# HELPER METHOD: slurp in contents of file to scalar.
###############################################################################
sub slurp {
    my $filename = shift;
    my $fin = IO::File->new( $filename, '<' ) || die "can't open '$filename'; $!";
    my $str = join('', <$fin>);
    $fin->close();
    chomp( $str );
    return $str;
}
