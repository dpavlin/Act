package Act::Handler::Payment::Confirm;
use strict;

use Act::Config;
use Act::Email;
use Act::Payment;
use Act::Template;
use Act::User;

sub handler
{
    # we aren't dispatched by Act::Dispatcher
    $Request{args} = { map { $_ => $Request{r}->param($_) || '' } $Request{r}->param };

    # verify payment
    my ($verified, $order) = Act::Payment->verify($Request{args});
    if ($verified && $order) {
        # update order
        $order->update(status => 'paid',
                       means  => 'ONLINE'
                      );
        # send email notification
        _notify($order);
    }
    Act::Payment->create_response($verified, $order);
}

sub _notify
{
    my $order = shift;

    # remember, we aren't dispatched by Act::Dispatcher,
    # so load appropriate conference configuration
    # and set up some context
    $Config = Act::Config::get_config($Request{conference} = $order->conf_id);
    $Request{user} = Act::User->new(user_id => $order->user_id);
    $Request{language} = $Request{user}->language || $Config->general_default_language;
    my $template = Act::Template->new; # context-dependent, can't be global

    # generate subject and body from templates
    my %output;
    for my $slot (qw(subject body)) {
        $template->variables(order => $order);
        $template->process("payment/notify_$slot", \$output{$slot});
    }
    # send the notification email
    my %args = (
        from    => $Config->email_sender_address,
        to      => $Request{user}->email,
        bcc     => [ $Config->payment_notify_bcc ],
        %output,
    );
    push @{$args{bcc}}, $Config->payment_notify_address
        if $Config->payment_notify_address;
    Act::Email::send(%args);
}

1;
__END__

=head1 NAME

Act::Handler::Payment::Confirm - confirm a payment.

=head1 DESCRIPTION

This handler is called by the bank with the status
of a payment.

See F<DEVDOC> for a complete discussion on handlers.

=cut
