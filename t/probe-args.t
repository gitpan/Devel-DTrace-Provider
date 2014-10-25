use Test::More tests => 2;

BEGIN { use_ok Devel::DTrace::Provider; }

my $provider = Devel::DTrace::Provider->new('test0', 'test1module');
$provider->probe('test', 'string', 'integer');
my $stubs = $provider->enable;
ok($stubs, 'Generate provider DOF');

for my $i (1..5) {
	$stubs->{test}->fire('foo', $i);
}

