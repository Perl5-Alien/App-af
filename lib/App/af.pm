use strict;
use warnings;
use 5.014;

package App::af {

  use Moose::Role;
  use namespace::autoclean;
  use Getopt::Long qw( GetOptionsFromArray );
  use Pod::Usage   qw( pod2usage           );

  # ABSTRACT: Command line tool for alienfile

=head1 SYNOPSIS

 af --help

=head1 DESCRIPTION

This class provides the machinery for the af command.

=head1 SEE ALSO

L<af>

=cut

  has args => (
    is      => 'ro',
    isa     => 'ArrayRef[Str]',
    default => sub { [] }
  );

  sub BUILDARGS
  {
    my($class, @args) = @_;
    
    my($subcommand) = $class =~ /App::af::(.*)/;
    my %args = ( args => \@args );
    
    my @options = (
      'help'    => sub {
        pod2usage({
          -verbose  => 99,
          -sections => $subcommand eq 'default' ? "SYNOPSIS|DESCRIPTION" : "SUBCOMMANDS/$subcommand",
          -exitval => 0,
        }) },
      'version' => sub {
        say "App::af version ", ($App::af::VERSION // 'dev');
        exit;
      },
    );
    
    foreach my $attr ($class->meta->get_all_attributes)
    {
      next unless $attr->does("App::af::opt");
      my $name = $attr->name;
      $name .= '|' . $attr->short    if $attr->short;
      $name .= "=" . $attr->opt_type if $attr->opt_type;
      push @options, $name => \$args{$attr->name};
    }
    
    GetOptionsFromArray(\@args, @options)
      || pod2usage({
           -exitval => 1, 
           -verbose => 99, 
           -sections => $subcommand eq 'default' ? 'SYNOPSIS' : "SUBCOMMANDS/$subcommand/Usage",
         });
    
    delete $args{$_} for grep { ! defined $args{$_} } keys %args;

    \%args,
  }

  sub compute_class
  {
    defined $ARGV[0] && $ARGV[0] !~ /^-/
      ? 'App::af::' . shift @ARGV
      : 'App::af::default';
  }
  
  requires 'main';  
}

package App::af::default {

  use Moose;
  with 'App::af';

  sub main
  {
    say "App::af version @{[ $App::af::VERSION || 'dev' ]}";
    say "  af --help for usage information";
    0;
  }

  __PACKAGE__->meta->make_immutable;
}

package App::af::role::alienfile {

  use Moose::Role;
  use namespace::autoclean;
  use MooseX::Types::Path::Tiny qw( AbsPath );
  use Module::Load qw( load );
  use Path::Tiny qw( path );
  use File::Temp qw( tempdir );
  
  has file => (
    is       => 'ro',
    isa      => AbsPath,
    traits   => ['App::af::opt'],
    short    => 'f',
    opt_type => 's',
    default  => 'alienfile',
    coerce   => 1,
  );
  
  has class => (
    is       => 'ro',
    isa      => 'Str',
    traits   => ['App::af::opt'],
    short    => 'c',
    opt_type => 's',
  );
  
  sub build
  {
    my($self) = @_;
    
    my $alienfile;
    
    if($self->class)
    {
      my $class = $self->class =~ /::/ ? $self->class : "Alien::" . $self->class;
      load $class;
      if($class->can('runtime_prop') && $class->runtime_prop)
      {
        $alienfile = path($class->dist_dir)->child('_alien/alienfile');
      }
      else
      {
        say STDERR "class @{[ $self->class ]} does not appear to have been installed using Alien::Build";
        exit 2;
      }
    }
    else
    {
      $alienfile = $self->file;
    }

    unless(-r $alienfile)
    {
      say STDERR "unable to read $alienfile";
      exit 2;
    }
  
    require Alien::Build;
    Alien::Build->load("$alienfile", root => tempdir( CLEANUP => 1));

  }  
}

package App::af::opt {

  use Moose::Role;
  use namespace::autoclean;
  
  has short => (
    is      => 'rw',
    isa     => 'Str',
    default => '',
  );
  
  has opt_type => (
    is      => 'rw',
    isa     => 'Str',
    default => '',
  );

}

1;
