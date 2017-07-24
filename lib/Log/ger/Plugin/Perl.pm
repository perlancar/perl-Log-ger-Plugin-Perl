package Log::ger::Plugin::Perl;

# DATE
# VERSION

use strict;
use warnings;
use Log::ger::Util ();

sub get_hooks {
    my %conf = @_;

    my $action = delete($conf{action}) || {
        warn  => 'warn',
        error => 'warn',
        fatal => 'die',
    };
    keys %conf and die "Unknown configuration: ".join(", ", sort keys %conf);

    return {
        after_install_routines => [
            __PACKAGE__, 99,

            sub {
                require B::CallChecker;
                require B::Generate;

                my %args = @_;

                # we are only relevant when targetting package
                return [undef] unless ($args{target}||'') eq 'package';

                for my $r (@{ $args{routines} }) {
                    my ($code, $name, $lnum, $type) = @$r;
                    next unless $type =~ /\Alog_/;

                    my $act = $action->{ Log::ger::Util::string_level($lnum) };

                    my $logger;
                    if (!$act) {
                        $logger = sub { B::SVOP->new("const",0,!1) };
                    } elsif ($act eq 'warn') {
                        #$logger = sub { warn @_ > 1 ? sprintf(shift, @_) : @_ };
                        $logger = sub { sub { warn @_ > 1 ? sprintf(shift, @_) : @_ } };
                        $logger = sub { sub { warn @_ > 1 ? sprintf(shift, @_) : @_ } };
                    } elsif ($act eq 'carp') {
                        require Carp;
                        $logger = sub { Carp::carp(@_ > 1 ? sprintf(shift, @_) : @_) };
                    } elsif ($act eq 'cluck') {
                        require Carp;
                        $logger = sub { Carp::cluck(@_ > 1 ? sprintf(shift, @_) : @_) };
                    } elsif ($act eq 'croak') {
                        require Carp;
                        $logger = sub { Carp::croak(@_ > 1 ? sprintf(shift, @_) : @_) };
                    } elsif ($act eq 'confess') {
                        require Carp;
                        $logger = sub { Carp::confess(@_ > 1 ? sprintf(shift, @_) : @_) };
                    } else { # die is the default
                        $logger = sub { die @_ > 1 ? sprintf(shift, @_) : @_ };
                    }

                    my $fullname = "$args{target_arg}\::$name";
                    B::CallChecker::cv_set_call_checker(
                        \&{$fullname},
                        sub { B::SVOP->new("const",0,!1) },
                        #\!1,
                        $logger,
                    );
                }
                [1];
            }],
    };
}

1;
# ABSTRACT: Replace log statements with Perl's standard facility (warn, die, etc)

=for Pod::Coverage ^(.+)$

=head1 SYNOPSIS

 use Log::ger::Plugin Perl => (
     action => { # optional
         trace => '',
         debug => '',
         info  => '',
         warn  => 'warn',
         error => 'warn',
         fatal => 'die',
     },
 );


=head1 DESCRIPTION

This plugin uses L<B::CallChecker> to replace logging statements with C<warn()>,
C<die()>, etc.

Caveats:

=over

=item * must be done at compile-time

=item * only works when you are using procedural style

=item * logging statements at level with action='' or unmentioned, will become no-op

The effect is similar to what is achieved by

=item * once replaced/optimized away, subsequent logger reinitialization at run-time won't take effect

=item * currently formats message with sprintf(), no layouter support

=back


=head1 CONFIGURATION

=head2 action => hash

A mapping of Log::ger error level name and action. Unmentioned levels mean to
ignore log for that level. Action can be one of:

=over

=item * '' (empty string)

Ignore the log message.

=item * warn

Pass message to Perl's C<warn()>.

=item * die

Pass message to Perl's C<die()>.

=item * carp

Pass message to L<Carp>'s C<carp()>.

=item * cluck

Pass message to L<Carp>'s C<cluck()>.

=item * croak

Pass message to L<Carp>'s C<croak()>.

=item * confess

Pass message to L<Carp>'s C<confess()>.

=back


=head1 SEE ALSO

L<Log::ger::Output::Perl>

=cut
