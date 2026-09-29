package LRUCache;

use strict;
use warnings;
use Scalar::Util qw(refaddr);

sub new {
    my ($class, $capacity) = @_;

    _validate_capacity($capacity);

    my $head = {
        key   => undef,
        value => undef,
        prev  => undef,
        next  => undef,
    };

    my $tail = {
        key   => undef,
        value => undef,
        prev  => undef,
        next  => undef,
    };

    $head->{next} = $tail;
    $tail->{prev} = $head;

    my $self = {
        capacity  => $capacity,
        size      => 0,
        peak_size => 0,
        cache     => {},
        head      => $head,
        tail      => $tail,
        hits      => 0,
        misses    => 0,
        evictions => 0,
        puts      => 0,
        updates   => 0,
        removals  => 0,
        clears    => 0,
    };

    bless $self, $class;

    return $self;
}

sub _validate_capacity {
    my ($capacity) = @_;

    die "Capacity is required"
        unless defined $capacity;

    die "Capacity must be a positive integer"
        unless $capacity =~ /^\d+$/ && $capacity > 0;

    return;
}

sub _validate_key {
    my ($key) = @_;

    die "Key is required"
        unless defined $key;

    die "Key must be a non-reference scalar"
        if ref $key;

    return;
}

sub _validate_value {
    my ($value) = @_;

    die "Value is required"
        unless defined $value;

    return;
}

sub _remove_node {
    my ($self, $node) = @_;

    die "Node is required"
        unless defined $node;

    die "Cannot remove head sentinel"
        if refaddr($node) == refaddr($self->{head});

    die "Cannot remove tail sentinel"
        if refaddr($node) == refaddr($self->{tail});

    die "Node is not linked"
        unless defined $node->{prev} && defined $node->{next};

    my $prev = $node->{prev};
    my $next = $node->{next};

    $prev->{next} = $next;
    $next->{prev} = $prev;

    $node->{prev} = undef;
    $node->{next} = undef;

    return $node;
}

sub _add_to_head {
    my ($self, $node) = @_;

    die "Node is required"
        unless defined $node;

    die "Cannot add head sentinel"
        if refaddr($node) == refaddr($self->{head});

    die "Cannot add tail sentinel"
        if refaddr($node) == refaddr($self->{tail});

    die "Node is already linked"
        if defined $node->{prev} || defined $node->{next};

    my $first = $self->{head}->{next};

    die "Cache list is corrupted"
        unless defined $first;

    $node->{prev} = $self->{head};
    $node->{next} = $first;

    $first->{prev} = $node;
    $self->{head}->{next} = $node;

    return $node;
}

sub _move_to_head {
    my ($self, $node) = @_;

    return $node
        if refaddr($self->{head}->{next}) == refaddr($node);

    $self->_remove_node($node);
    $self->_add_to_head($node);

    return $node;
}

sub _remove_lru {
    my ($self) = @_;

    return undef
        if $self->{size} == 0;

    my $lru = $self->{tail}->{prev};

    die "Cache list is corrupted"
        unless defined $lru;

    die "Cache size/list mismatch"
        if refaddr($lru) == refaddr($self->{head});

    $self->_remove_node($lru);

    my $key = $lru->{key};

    die "LRU node has no key"
        unless defined $key;

    die "LRU key is missing from cache"
        unless exists $self->{cache}->{$key};

    delete $self->{cache}->{$key};

    $self->{size}--;
    $self->{evictions}++;

    return $lru;
}

sub get {
    my ($self, $key) = @_;

    _validate_key($key);

    unless (exists $self->{cache}->{$key}) {
        $self->{misses}++;
        return undef;
    }

    my $node = $self->{cache}->{$key};

    die "Cache entry is corrupted"
        unless defined $node;

    $self->{hits}++;
    $self->_move_to_head($node);

    return $node->{value};
}

sub peek {
    my ($self, $key) = @_;

    _validate_key($key);

    return undef
        unless exists $self->{cache}->{$key};

    my $node = $self->{cache}->{$key};

    die "Cache entry is corrupted"
        unless defined $node;

    return $node->{value};
}

sub put {
    my ($self, $key, $value) = @_;

    _validate_key($key);
    _validate_value($value);

    $self->{puts}++;

    if (exists $self->{cache}->{$key}) {
        my $node = $self->{cache}->{$key};

        die "Cache entry is corrupted"
            unless defined $node;

        $node->{value} = $value;

        $self->{updates}++;

        $self->_move_to_head($node);

        return $value;
    }

    if ($self->{size} >= $self->{capacity}) {
        $self->_remove_lru();
    }

    my $new_node = {
        key   => $key,
        value => $value,
        prev  => undef,
        next  => undef,
    };

    $self->{cache}->{$key} = $new_node;

    $self->_add_to_head($new_node);

    $self->{size}++;

    if ($self->{size} > $self->{peak_size}) {
        $self->{peak_size} = $self->{size};
    }

    return $value;
}

sub remove {
    my ($self, $key) = @_;

    _validate_key($key);

    return undef
        unless exists $self->{cache}->{$key};

    my $node = $self->{cache}->{$key};

    die "Cache entry is corrupted"
        unless defined $node;

    $self->_remove_node($node);

    delete $self->{cache}->{$key};

    $self->{size}--;
    $self->{removals}++;

    return $node->{value};
}

sub contains {
    my ($self, $key) = @_;

    _validate_key($key);

    return exists $self->{cache}->{$key} ? 1 : 0;
}

sub clear {
    my ($self) = @_;

    my $current = $self->{head}->{next};

    while (defined $current &&
           refaddr($current) != refaddr($self->{tail})) {

        my $next = $current->{next};

        $current->{prev} = undef;
        $current->{next} = undef;

        $current = $next;
    }

    $self->{cache} = {};
    $self->{size} = 0;

    $self->{head}->{next} = $self->{tail};
    $self->{tail}->{prev} = $self->{head};

    $self->{clears}++;

    return;
}

sub reset_stats {
    my ($self) = @_;

    $self->{hits}      = 0;
    $self->{misses}    = 0;
    $self->{evictions} = 0;
    $self->{puts}      = 0;
    $self->{updates}   = 0;
    $self->{removals}  = 0;
    $self->{clears}    = 0;
    $self->{peak_size} = $self->{size};

    return;
}

sub set_capacity {
    my ($self, $new_capacity) = @_;

    _validate_capacity($new_capacity);

    while ($self->{size} > $new_capacity) {
        $self->_remove_lru();
    }

    $self->{capacity} = $new_capacity;

    return $self->{capacity};
}

sub size {
    my ($self) = @_;

    return $self->{size};
}

sub capacity {
    my ($self) = @_;

    return $self->{capacity};
}

sub is_empty {
    my ($self) = @_;

    return $self->{size} == 0 ? 1 : 0;
}

sub is_full {
    my ($self) = @_;

    return $self->{size} >= $self->{capacity} ? 1 : 0;
}

sub keys {
    my ($self) = @_;

    my @keys;
    my $current = $self->{head}->{next};

    while (defined $current &&
           refaddr($current) != refaddr($self->{tail})) {

        push @keys, $current->{key};
        $current = $current->{next};
    }

    return @keys;
}

sub values {
    my ($self) = @_;

    my @values;
    my $current = $self->{head}->{next};

    while (defined $current &&
           refaddr($current) != refaddr($self->{tail})) {

        push @values, $current->{value};
        $current = $current->{next};
    }

    return @values;
}

sub entries {
    my ($self) = @_;

    my @entries;
    my $current = $self->{head}->{next};

    while (defined $current &&
           refaddr($current) != refaddr($self->{tail})) {

        push @entries, [
            $current->{key},
            $current->{value},
        ];

        $current = $current->{next};
    }

    return @entries;
}

sub stats {
    my ($self) = @_;

    my $requests = $self->{hits} + $self->{misses};

    my $hit_rate = $requests
        ? $self->{hits} / $requests
        : 0;

    my $miss_rate = $requests
        ? $self->{misses} / $requests
        : 0;

    return {
        capacity  => $self->{capacity},
        size      => $self->{size},
        peak_size => $self->{peak_size},
        hits      => $self->{hits},
        misses    => $self->{misses},
        requests  => $requests,
        evictions => $self->{evictions},
        puts      => $self->{puts},
        updates   => $self->{updates},
        removals  => $self->{removals},
        clears    => $self->{clears},
        hit_rate  => $hit_rate,
        miss_rate => $miss_rate,
    };
}

sub validate {
    my ($self) = @_;

    die "Capacity is invalid"
        unless defined $self->{capacity}
        && $self->{capacity} =~ /^\d+$/
        && $self->{capacity} > 0;

    die "Size is invalid"
        unless defined $self->{size}
        && $self->{size} =~ /^\d+$/
        && $self->{size} >= 0;

    die "Size exceeds capacity"
        if $self->{size} > $self->{capacity};

    die "Head sentinel has previous node"
        if defined $self->{head}->{prev};

    die "Tail sentinel has next node"
        if defined $self->{tail}->{next};

    die "Head sentinel has no next node"
        unless defined $self->{head}->{next};

    die "Tail sentinel has no previous node"
        unless defined $self->{tail}->{prev};

    my %seen_nodes;
    my %seen_keys;

    my $count = 0;
    my $previous = $self->{head};
    my $current = $self->{head}->{next};

    while (defined $current &&
           refaddr($current) != refaddr($self->{tail})) {

        my $address = refaddr($current);

        die "Cycle detected in forward list"
            if $seen_nodes{$address}++;

        die "Node has invalid previous link"
            unless defined $current->{prev}
            && refaddr($current->{prev}) == refaddr($previous);

        die "Node has no next link"
            unless defined $current->{next};

        die "Node has no key"
            unless defined $current->{key};

        my $key = $current->{key};

        die "Duplicate key in linked list"
            if $seen_keys{$key}++;

        die "Linked-list key is missing from cache"
            unless exists $self->{cache}->{$key};

        die "Cache points to wrong node"
            unless defined $self->{cache}->{$key}
            && refaddr($self->{cache}->{$key}) == $address;

        $count++;

        die "Linked list contains more nodes than expected"
            if $count > $self->{size};

        $previous = $current;
        $current = $current->{next};
    }

    die "Forward list does not terminate at tail"
        unless defined $current
        && refaddr($current) == refaddr($self->{tail});

    die "Tail previous link is invalid"
        unless refaddr($self->{tail}->{prev}) == refaddr($previous);

    die "Linked-list size does not match cache size"
        unless $count == $self->{size};

    my $hash_size = scalar keys %{ $self->{cache} };

    die "Hash size does not match cache size"
        unless $hash_size == $self->{size};

    for my $key (keys %{ $self->{cache} }) {
        my $node = $self->{cache}->{$key};

        die "Undefined cache node"
            unless defined $node;

        die "Cache node has invalid key"
            unless defined $node->{key}
            && "$node->{key}" eq "$key";

        die "Cache node is absent from linked list"
            unless $seen_nodes{refaddr($node)};
    }

    my %reverse_seen;
    my $reverse_count = 0;

    my $next = $self->{tail};
    $current = $self->{tail}->{prev};

    while (defined $current &&
           refaddr($current) != refaddr($self->{head})) {

        my $address = refaddr($current);

        die "Cycle detected in reverse list"
            if $reverse_seen{$address}++;

        die "Node has invalid next link"
            unless defined $current->{next}
            && refaddr($current->{next}) == refaddr($next);

        die "Node has no previous link"
            unless defined $current->{prev};

        $reverse_count++;

        die "Reverse list contains more nodes than expected"
            if $reverse_count > $self->{size};

        $next = $current;
        $current = $current->{prev};
    }

    die "Reverse list does not terminate at head"
        unless defined $current
        && refaddr($current) == refaddr($self->{head});

    die "Head next link is invalid"
        unless refaddr($self->{head}->{next}) == refaddr($next);

    die "Forward and reverse sizes differ"
        unless $reverse_count == $count;

    return 1;
}

sub debug_print {
    my ($self) = @_;

    print "Cache (capacity=$self->{capacity}, size=$self->{size}): ";

    my $current = $self->{head}->{next};

    while (defined $current &&
           refaddr($current) != refaddr($self->{tail})) {

        my $key = defined $current->{key}
            ? $current->{key}
            : "undef";

        my $value = defined $current->{value}
            ? $current->{value}
            : "undef";

        if (ref $value) {
            $value = ref $value;
        }

        print "[$key:$value] ";

        $current = $current->{next};
    }

    print "\n";

    return;
}

sub DESTROY {
    my ($self) = @_;

    return unless ref $self;
    return unless defined $self->{head};
    return unless defined $self->{tail};

    my $current = $self->{head}->{next};

    while (defined $current &&
           refaddr($current) != refaddr($self->{tail})) {

        my $next = $current->{next};

        $current->{prev} = undef;
        $current->{next} = undef;

        $current = $next;
    }

    $self->{head}->{next} = undef;
    $self->{tail}->{prev} = undef;

    $self->{cache} = {};

    return;
}

1;

package main;

use strict;
use warnings;

unless (caller) {
    my $cache = LRUCache->new(2);

    $cache->put(1, 1);
    print "Put(1,1) ";
    $cache->debug_print();
    $cache->validate();

    $cache->put(2, 2);
    print "Put(2,2) ";
    $cache->debug_print();
    $cache->validate();

    my $value = $cache->get(1);

    if (defined $value) {
        print "Get(1): $value ";
        $cache->debug_print();
    }
    else {
        print "Get(1): miss\n";
    }

    $cache->validate();

    $cache->put(3, 3);
    print "Put(3,3) ";
    $cache->debug_print();
    $cache->validate();

    $value = $cache->get(2);

    if (defined $value) {
        print "Get(2): $value\n";
    }
    else {
        print "Get(2): miss\n";
    }

    $cache->put(4, 4);
    print "Put(4,4) ";
    $cache->debug_print();
    $cache->validate();

    $value = $cache->get(1);

    if (defined $value) {
        print "Get(1): $value\n";
    }
    else {
        print "Get(1): miss\n";
    }

    $value = $cache->get(3);

    if (defined $value) {
        print "Get(3): $value ";
        $cache->debug_print();
    }
    else {
        print "Get(3): miss\n";
    }

    $value = $cache->get(4);

    if (defined $value) {
        print "Get(4): $value ";
        $cache->debug_print();
    }
    else {
        print "Get(4): miss\n";
    }

    $cache->validate();

    print "\n";

    print "Size: ", $cache->size(), "\n";
    print "Capacity: ", $cache->capacity(), "\n";
    print "Full: ", $cache->is_full() ? "yes" : "no", "\n";

    print "Keys from most recent to least recent: ";
    print join(", ", $cache->keys());
    print "\n";

    my $stats = $cache->stats();

    print "Requests: $stats->{requests}\n";
    print "Hits: $stats->{hits}\n";
    print "Misses: $stats->{misses}\n";
    print "Evictions: $stats->{evictions}\n";
    print "Puts: $stats->{puts}\n";
    print "Updates: $stats->{updates}\n";
    print "Removals: $stats->{removals}\n";
    print "Peak size: $stats->{peak_size}\n";
    printf "Hit rate: %.2f%%\n", $stats->{hit_rate} * 100;
    printf "Miss rate: %.2f%%\n", $stats->{miss_rate} * 100;

    print "\n";

    $cache->set_capacity(1);
    print "Capacity changed to 1 ";
    $cache->debug_print();
    $cache->validate();

    $cache->put(5, 5);
    print "Put(5,5) ";
    $cache->debug_print();
    $cache->validate();

    my $removed = $cache->remove(5);

    if (defined $removed) {
        print "Removed key 5 with value $removed\n";
    }

    $cache->validate();

    print "Empty: ", $cache->is_empty() ? "yes" : "no", "\n";

    $cache->clear();
    $cache->validate();

    print "After clear ";
    $cache->debug_print();

    $stats = $cache->stats();

    print "Clears: $stats->{clears}\n";
    print "Final validation: ",
        $cache->validate() ? "valid" : "invalid",
        "\n";
}
