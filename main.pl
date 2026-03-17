package LRUCache;
use strict;
use warnings;

sub new {
    my ($class, $capacity) = @_;
    die "Capacity must be positive" if $capacity <= 0;
    
    my $self = {
        capacity => $capacity,
        cache => {},
        head => { key => 0, value => 0, prev => undef, next => undef },
        tail => { key => 0, value => 0, prev => undef, next => undef },
    };
    
    $self->{head}->{next} = $self->{tail};
    $self->{tail}->{prev} = $self->{head};
    
    bless $self, $class;
    return $self;
}

sub _remove_node {
    my ($self, $node) = @_;
    
    return unless $node->{prev} && $node->{next};
    
    $node->{prev}->{next} = $node->{next};
    $node->{next}->{prev} = $node->{prev};
    
    $node->{prev} = undef;
    $node->{next} = undef;
}

sub _add_to_head {
    my ($self, $node) = @_;
    
    $node->{prev} = $self->{head};
    $node->{next} = $self->{head}->{next};
    
    if ($self->{head}->{next}) {
        $self->{head}->{next}->{prev} = $node;
    }
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
    return unless $lru && $lru != $self->{head};
    
    $self->_remove_node($lru);
    delete $self->{cache}->{$lru->{key}};
}

sub get {
    my ($self, $key) = @_;
    
    my $node = $self->{cache}->{$key};
    return undef unless $node;
    
    $self->_move_to_head($node);
    return $node->{value};
}

sub put {
    my ($self, $key, $value) = @_;
    die "Key and value are required" if not defined $key or not defined $value;
    
    my $node = $self->{cache}->{$key};
    if ($node) {
        $node->{value} = $value;
        $self->_move_to_head($node);
        return;
    }
    
    if (keys %{$self->{cache}} >= $self->{capacity}) {
        $self->_remove_lru();
    }
    
    my $new_node = {
        key => $key,
        value => $value,
        prev => undef,
        next => undef,
    };
    
    $self->{cache}->{$key} = $new_node;
    $self->_add_to_head($new_node);
}

sub set_capacity {
    my ($self, $new_capacity) = @_;
    die "Capacity must be positive" if $new_capacity <= 0;
    
    while (keys %{$self->{cache}} > $new_capacity) {
        $self->_remove_lru();
    }
    $self->{capacity} = $new_capacity;
}

sub debug_print {
    my ($self) = @_;
    
    my $size = scalar keys %{$self->{cache}};
    print "Cache (capacity=$self->{capacity}, size=$size): ";
    
    my $current = $self->{head}->{next};
    while ($current && $current != $self->{tail}) {
        print "[$current->{key}:$current->{value}] ";
        $current = $current->{next};
    }
    print "\n";
}

sub DESTROY {
    my ($self) = @_;
    %{$self->{cache}} = ();
}

package main;

my $cache = LRUCache->new(2);

$cache->put(1, 1);
print "Put(1,1) ";
$cache->debug_print();

$cache->put(2, 2);
print "Put(2,2) ";
$cache->debug_print();

my $val = $cache->get(1);
if (defined $val) {
    print "Get(1): $val ";
    $cache->debug_print();
} else {
    print "Get(1): miss\n";
}

$cache->put(3, 3);
print "Put(3,3) ";
$cache->debug_print();

$val = $cache->get(2);
if (defined $val) {
    print "Get(2): $val\n";
} else {
    print "Get(2): miss\n";
}

$cache->put(4, 4);
print "Put(4,4) ";
$cache->debug_print();

$val = $cache->get(1);
if (defined $val) {
    print "Get(1): $val\n";
} else {
    print "Get(1): miss\n";
}

$val = $cache->get(3);
if (defined $val) {
    print "Get(3): $val ";
    $cache->debug_print();
} else {
    print "Get(3): miss\n";
}

$val = $cache->get(4);
if (defined $val) {
    print "Get(4): $val ";
    $cache->debug_print();
} else {
    print "Get(4): miss\n";
}

1;
