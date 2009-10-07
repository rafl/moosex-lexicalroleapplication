use strict;
use warnings;

package MooseX::LexicalRoleApplication;

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
