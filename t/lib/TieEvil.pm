package TieEvil;
# FCGI tied with a scalar ref object, which breaks when you
# call open on it.  Emulate that to test the workaround:
use Carp ();

sub TIEHANDLE 
{
 my $class = shift;
 my $fh    = \(my $scalar); # this is evil and broken
 return bless $fh,$class;
}

sub EOF     { 0 }
sub TELL    { length ${$_[0]} }
sub FILENO  { -1 }
sub SEEK    { 1 }
sub CLOSE   { 1 }
sub BINMODE { 1 }

sub OPEN { Carp::confess "unimplemented" }

sub READ     { $_[1] = substr(${$_[0]},$_[3],$_[2]) }
sub READLINE { "hello world\n" }
sub GETC     { substr(${$_[0]},0,1) }

sub PRINT {
  my ($self, @what) = @_;
  my $new = join($\, @what);
  $$self .= $new;
  return length $new;
}

sub UNTIE { 1 }; # suppress warnings about references

1;
