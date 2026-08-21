package LRUCache;

use strict;
use warnings;

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
        cache     => {},
        head      => $head,
        tail      => $tail,
        hits      => 0,
        misses    => 0,
        evictions => 0,
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
}

sub _validate_key {
    my ($key) = @_;

    die "Key is required"
        unless defined $key;
}

sub _validate_value {
    my ($value) = @_;

    die "Value is required"
        unless defined $value;
}

sub _remove_node {
    my ($self, $node) = @_;

    return unless defined $node;
    return unless defined $node->{prev};
    return unless defined $node->{next};

    $node->{prev}->{next} = $node->{next};
    $node->{next}->{prev} = $node->{prev};

    $node->{prev} = undef;
    $node->{next} = undef;
}

sub _add_to_head {
    my ($self, $node) = @_;

    my $first = $self->{head}->{next};

    $node->{prev} = $self->{head};
    $node->{next} = $first;

    $first->{prev} = $node;
    $self->{head}->{next} = $node;
}

sub _move_to_head {
    my ($self, $node) = @_;

    $self->_remove_node($node);
    $self->_add_to_head($node);
}

sub _remove_lru {
    my ($self) = @_;

    my $lru = $self->{tail}->{prev};

    return unless defined $lru;
    return if $lru == $self->{head};

    $self->_remove_node($lru);

    delete $self->{cache}->{ $lru->{key} };

    $self->{size}--;
    $self->{evictions}++;

    return $lru;
}

sub get {
    my ($self, $key) = @_;

    _validate_key($key);

    my $node = $self->{cache}->{$key};

    unless (defined $node) {
        $self->{misses}++;
        return undef;
    }

    $self->{hits}++;
    $self->_move_to_head($node);

    return $node->{value};
}

sub put {
    my ($self, $key, $value) = @_;

    _validate_key($key);
    _validate_value($value);

    my $node = $self->{cache}->{$key};

    if (defined $node) {
        $node->{value} = $value;
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

    return $value;
}

sub remove {
    my ($self, $key) = @_;

    _validate_key($key);

    my $node = $self->{cache}->{$key};

    return undef unless defined $node;

    $self->_remove_node($node);
    delete $self->{cache}->{$key};

    $self->{size}--;

    return $node->{value};
}

sub contains {
    my ($self, $key) = @_;

    _validate_key($key);

    return exists $self->{cache}->{$key};
}

sub clear {
    my ($self) = @_;

    my $current = $self->{head}->{next};

    while ($current != $self->{tail}) {
        my $next = $current->{next};

        $current->{prev} = undef;
        $current->{next} = undef;

        $current = $next;
    }

    $self->{cache} = {};
    $self->{size} = 0;

    $self->{head}->{next} = $self->{tail};
    $self->{tail}->{prev} = $self->{head};

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

    return $self->{size} == 0;
}

sub is_full {
    my ($self) = @_;

    return $self->{size} >= $self->{capacity};
}

sub keys {
    my ($self) = @_;

    my @keys;

    my $current = $self->{head}->{next};

    while ($current != $self->{tail}) {
        push @keys, $current->{key};
        $current = $current->{next};
    }

    return @keys;
}

sub stats {
    my ($self) = @_;

    my $requests = $self->{hits} + $self->{misses};

    my $hit_rate = $requests
        ? $self->{hits} / $requests
        : 0;

    return {
        capacity  => $self->{capacity},
        size      => $self->{size},
        hits      => $self->{hits},
        misses    => $self->{misses},
        evictions => $self->{evictions},
        hit_rate  => $hit_rate,
    };
}

sub debug_print {
    my ($self) = @_;

    print "Cache (capacity=$self->{capacity}, size=$self->{size}): ";

    my $current = $self->{head}->{next};

    while ($current != $self->{tail}) {
        print "[$current->{key}:$current->{value}] ";
        $current = $current->{next};
    }

    print "\n";
}

sub DESTROY {
    my ($self) = @_;

    return unless ref $self;

    my $current = $self->{head}->{next};

    while (defined $current && $current != $self->{tail}) {
        my $next = $current->{next};

        $current->{prev} = undef;
        $current->{next} = undef;

        $current = $next;
    }

    $self->{head}->{next} = undef;
    $self->{tail}->{prev} = undef;

    $self->{cache} = {};
}

1;

package main;

use strict;
use warnings;

my $cache = LRUCache->new(2);

$cache->put(1, 1);
print "Put(1,1) ";
$cache->debug_print();

$cache->put(2, 2);
print "Put(2,2) ";
$cache->debug_print();

my $value = $cache->get(1);

if (defined $value) {
    print "Get(1): $value ";
    $cache->debug_print();
}
else {
    print "Get(1): miss\n";
}

$cache->put(3, 3);
print "Put(3,3) ";
$cache->debug_print();

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

print "\n";

print "Size: ", $cache->size(), "\n";
print "Capacity: ", $cache->capacity(), "\n";
print "Full: ", $cache->is_full() ? "yes" : "no", "\n";

print "Keys from most recent to least recent: ";
print join(", ", $cache->keys());
print "\n";

my $stats = $cache->stats();

print "Hits: $stats->{hits}\n";
print "Misses: $stats->{misses}\n";
print "Evictions: $stats->{evictions}\n";
printf "Hit rate: %.2f%%\n", $stats->{hit_rate} * 100;

print "\n";

$cache->set_capacity(1);
print "Capacity changed to 1 ";
$cache->debug_print();

$cache->put(5, 5);
print "Put(5,5) ";
$cache->debug_print();

my $removed = $cache->remove(5);

if (defined $removed) {
    print "Removed key 5 with value $removed\n";
}

print "Empty: ", $cache->is_empty() ? "yes" : "no", "\n";

$cache->clear();

print "After clear ";
$cache->debug_print();
