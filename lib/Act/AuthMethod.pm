package Act::AuthMethod;

use strict;
use warnings;

sub new {
    my ( $class ) = @_;

    return bless {}, $class;
}

1;

__END__

=head1 NAME

Act::AuthMethod - Abstract integration with external authentication services.

=head1 DESCRIPTION

Base class for auth methods.

=head1 METHODS

=cut
