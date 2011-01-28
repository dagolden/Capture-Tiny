package TieLC;

sub TIEHANDLE 
{
 my $class = shift;
 my $fh    = \do { local *HANDLE};
 bless $fh,$class;
 $fh->OPEN(@_) if (@_);
 $fh->BINMODE(':utf8');
 return $fh;
}

sub EOF     { eof($_[0]) }
sub TELL    { tell($_[0]) }
sub FILENO  { fileno($_[0]) }
sub SEEK    { seek($_[0],$_[1],$_[2]) }
sub CLOSE   { close($_[0]) }
sub BINMODE { binmode($_[0],$_[1]) }

sub OPEN
{
 $_[0]->CLOSE if defined($_[0]->FILENO);
 @_ == 2 ? open($_[0], $_[1]) : open($_[0], $_[1], $_[2]);
}

sub READ     { read($_[0],$_[1],$_[2]) }
sub READLINE { "hello world\n" }
sub GETC     { getc($_[0]) }

sub WRITE
{
 my $fh = $_[0];
 print $fh substr($_[1],0,$_[2])
}

sub PRINT {
  my ($self, @what) = @_;
  my $buf = lc join('', @what);
  $self->WRITE($buf, length($buf), 0);
}

sub UNTIE { 1 }; # suppress warnings about references

1;
