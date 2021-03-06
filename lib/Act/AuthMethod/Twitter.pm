package Act::AuthMethod::Twitter;

use strict;
use warnings;
use parent 'Act::AuthMethod';

use Act::Config;
use Act::Util qw(localize make_abs_uri);

sub twitter {
    my $consumer_key    = $Config->twitter_consumer_key;
    my $consumer_secret = $Config->twitter_consumer_secret;

    return Net::Twitter->new(
        traits          => [qw/OAuth API::REST/],
        consumer_key    => $consumer_key,
        consumer_secret => $consumer_secret,
    );
}

sub new {
    my ( $class ) = @_;

    my $load_ok = eval {
        require Net::Twitter;
        1;
    };
    return unless $load_ok;

    my $consumer_key    = $Config->twitter_consumer_key;
    my $consumer_secret = $Config->twitter_consumer_secret;

    return unless defined($consumer_key) && defined($consumer_secret);

    my $twitter = $class->twitter;
    my $self    = Act::AuthMethod::new($class);

    my $callback_url = make_abs_uri('auth_methods/twitter');
    my $session      = $Request{r}->session;

    unless(exists $session->{'twitter'}) {
        $session->{'twitter'} = {
            url          => $twitter->get_authentication_url(callback => $callback_url),
            token        => $twitter->request_token,
            token_secret => $twitter->request_token_secret,
        };
    }

    return $self;
}

sub render {
    my ( $self ) = @_;

    my $uri = $Request{r}->session->{'twitter'}{'url'};

    my $login_text = localize('Login with Twitter');

    return <<HTML;
<a href='$uri'>$login_text</a>
HTML
}

sub name {
    return 'twitter';
}

sub handle_postback {
    my ( $self, $req ) = @_;

    my $session  = $req->session;
    my $verifier = $req->param('oauth_verifier');

    my $twitter = $self->twitter;

    $twitter->request_token($session->{'twitter'}{'token'});
    $twitter->request_token_secret($session->{'twitter'}{'token_secret'});

    delete $session->{'twitter'};

    my ( $access_token, $access_token_secret, $user_id, $screen_name ) =
        $twitter->request_access_token(verifier => $verifier);

    my $dbh = $Request{'dbh'};
    my $sth = $dbh->prepare(<<SQL);
SELECT u.user_id FROM twitter_auths AS ta
INNER JOIN users AS u
ON ta.user_id = u.user_id
WHERE ta.twitter_id = ?
SQL

    $session->{'auth_method_info'} = {
        access_token        => $access_token,
        access_token_secret => $access_token_secret,
        user_id             => $user_id,
        screen_name         => $screen_name,
    };
    $sth->execute($user_id);

    ( $user_id ) = $sth->fetchrow_array;
    return $user_id;
}

sub associate_with_user {
    my ( $self, $req, $user ) = @_;

    my ( $token, $token_secret, $twitter_id ) =
        @{$req->session->{'auth_method_info'}}{qw/access_token access_token_secret user_id/};

    my $dbh = $Request{dbh};
    $dbh->do(<<SQL, undef, $user->user_id, $twitter_id, $token, $token_secret);
INSERT INTO twitter_auths (user_id, twitter_id, access_token,
    access_token_secret) VALUES (?, ?, ?, ?)
SQL
}

1;

__END__

=head1 NAME

Act::AuthMethod::Twitter - Twitter authentication integration for Act

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 FUNCTIONS

=head1 SEE ALSO

L<Act::AuthMethod>

=cut
