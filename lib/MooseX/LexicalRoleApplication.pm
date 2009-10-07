use strict;
use warnings;

package MooseX::LexicalRoleApplication;
# ABSTRACT: Apply roles for a lexical scope only

use Scope::Guard;
use Scalar::Util 'blessed';

# can't use $meta->rebless_instance, because that demands the new class to be a
# subclass of the current one.
sub rebless_instance_back {
    my ($original_meta, $instance) = @_;

    my $old_meta = Class::MOP::class_of($instance);
    $old_meta->rebless_instance_away($instance, $original_meta);

    my $meta_instance = $original_meta->get_meta_instance;

    # $_[1] because of some bug in old perls
    $meta_instance->rebless_instance_structure($_[1], $original_meta);

    for my $attr ($old_meta->get_all_attributes) {
        next if $original_meta->has_attribute($attr->name);
        $meta_instance->deinitialize_slot($instance, $_)
            for $attr->slots;
    }

    return $instance;
}

use namespace::clean;

=head1 SYNOPSIS

  my $obj = SomeClass->new;
  $obj->method_from_role; # fails

  {
    my $guard = MooseX::LexicalRoleApplication->apply(SomeRole->meta, $obj);
    $obj->method_from_role; # works
  }

  $obj->method_from_role; # fails

=head1 DESCRIPTION

=head1 CAVEATS

Actual I<lexical> role application isn't quite supported yet. The following
example won't do what it's supposed to just yet:

  {
    my $guard = MooseX::LexicalRoleApplication->apply($role, $obj);
    $other_role->apply($obj);
  }

=method apply ($role, $instance, \%rebless_params, \%application_options)

Will apply C<$role> to C<$instance>. C<%rebless_params> will be passed to
L<Class::MOP::Class/rebless_instance>. C<%application_options> will be passed
to L<Moose::Meta::Role/apply>.

A L<Scope::Guard|Scope::Guard> will be returned. Keep it around as long as you
want C<$role> to be applied to C<$instance>. You can cancel role removal by
calling C<dismiss> on the returned scope guard. If you want to remove the role
immediately, you can simply undef the guard.

=cut

sub apply {
    my ($class, $role, $instance, $rebless_params, $application_options) = @_;
    my $previous_metaclass = Class::MOP::class_of($instance);

    $role->apply($instance => (
        %{ $application_options || {} },
        rebless_params => $rebless_params || {},
    ));

    return Scope::Guard->new(sub {
        rebless_instance_back($previous_metaclass, $instance);
    });
}

1;
