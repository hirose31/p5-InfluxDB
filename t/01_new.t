use strict;
use Test::More;

require InfluxDB;
InfluxDB->import;
note("new");
my $obj = new_ok("InfluxDB");

# diag explain $obj

done_testing;
