<a href="https://travis-ci.org/hirose31/p5-InfluxDB"><img src="https://travis-ci.org/hirose31/p5-InfluxDB.png?branch=master" alt="Build Status" /></a>
<a href="https://coveralls.io/r/hirose31/p5-InfluxDB?branch=master"><img src="https://coveralls.io/repos/hirose31/p5-InfluxDB/badge.png?branch=master" alt="Coverage Status" /></a>

# NAME

InfluxDB - Client library for InfluxDB

# INSTALLATION

To install this module, run the following commands:

    perl Build.PL
    ./Build
    ./Build test
    ./Build install

# SYNOPSIS

    use InfluxDB;
    
    my $ix = InfluxDB->new(
        host     => '127.0.0.1',
        port     => 8086,
        username => 'scott',
        password => 'tiger',
        database => 'test',
    );
    
    $ix->write_points(
        data => {
            name    => "cpu",
            columns => [qw(sys user idle)],
            points  => [
                [20, 50, 30],
                [30, 60, 10],
            ],
        },
    ) or die "write_points: " . $ix->errstr;
    
    my $rs = $ix->query(
        q => 'select * from cpu',
        time_precision => 's',
    ) or die "query: " . $ix->errstr;
    
    # $rs is ArrayRef[HashRef]:
    # [
    #   {
    #     columns => ["time","sequence_number","idle","sys","user"],
    #     name => "cpu",
    #     points => [
    #       ["1391743908",6500001,10,30,60],
    #       ["1391743908",6490001,30,20,50],
    #     ],
    #   },
    # ]
    
    my $hrs = $ix->as_hash($rs); # or InfluxDB->as_hash($rs);
    # convert into HashRef for convenience
    # {
    #   cpu => [
    #     {
    #       idle   => 10,
    #       seqnum => 6500001,
    #       sys    => 30,
    #       time   => "1391743908",
    #       user   => 60
    #     },
    #     {
    #       idle   => 30,
    #       seqnum => 6490001,
    #       sys    => 20,
    #       time   => "1391743908",
    #       user   => 50
    #     }
    #   ]
    # }

# DESCRIPTION

InfluxDB is a client library for InfluxDB <[http://influxdb.org](http://influxdb.org)>.

    **************************** CAUTION ****************************
    
    InfluxDB that is a time series database is still in development
    status, so this module is also alpha state. Any API will change
    without notice.
    
    *****************************************************************

# METHODS

## Class Methods

### __new__(%args:Hash) :InfluxDB

Creates and returns a new InfluxDB client instance. Dies on errors.

%args is following:

- host => Str
- port => Int (default: 8086)
- username => Str
- password => Str
- database => Str
- timeout => Int (default: 120)
- debug => Bool (optional)

## Instance Methods

### __write\_points__(%args:Hash) :Bool

Write to multiple time series names.

- data => ArrayRef\[HashRef\] | HashRef

    HashRef like following:

        {
            name    => "name_of_series",
            columns => ["col1", "col2", ...],
            points  => [
                [10.0, 20.0, ...],
                [10.9, 21.3, ...],
                ...
            ],
        }

- time\_precision => "s" | "m" | "u" (optional)

    The precision timestamps should come back in. Valid options are s for seconds, m for milliseconds, and u for microseconds.

- __delete\_points__() :Bool

### __query__(%args:Hash) :Bool
- q => Str

    The InfluxDB query language, see: [http://influxdb.org/docs/query_language/](http://influxdb.org/docs/query_language/)

- time\_precision => "s" | "m" | "u" (optional)

    The precision timestamps should come back in. Valid options are s for seconds, m for milliseconds, and u for microseconds.

- chunked => Bool (default: 0)

    Chunked response.

### __as\_hash__($result:ArrayRef\[HashRef\]) :HashRef

Utility instance/class method for handling result of query.

Takes result of `query()`(ArrayRef) and convert into following HashRef.

    {
      cpu => [
        {
          idle => 10,
          seqnum => 6500001,
          sys => 30,
          time => "1391743908",
          user => 60
        },
        {
          idle => 30,
          seqnum => 6490001,
          sys => 20,
          time => "1391743908",
          user => 50
        }
      ]
    }

### __switch\_database__(database => Str) :Bool

Switch to another database.

### __switch\_user__(username => Str, password => Str) :Bool

Change your user-context.

### __create\_database__(database => Str) :Bool

Create database. Requires cluster-admin privileges.

### __list\_database__() :ArrayRef\[HashRef\]

List database. Requires cluster-admin privileges.

    [
      {
        name => "databasename",
        replicationFactor => 1
      },
      ...
    ]

### __delete\_database__(database => Str) :Bool

Delete database. Requires cluster-admin privileges.

### __status__() :HashRef

Returns status of previous request, as following hash:

- code => Int

    HTTP status code.

- message => Str

    HTTP status message.

- status\_line => Str

    HTTP status line (code . " " . message).

- content => Str

    Response body.

### __errstr__() :Str

Returns error message if previous query was failed.

### __host__() :Str

Returns hostname of InfluxDB server.

### __port__() :Str

Returns port number of InfluxDB server.

### __username__() :Str

Returns current user name.

### __database__() :Str

Returns current database name.

# ENVIRONMENT VARIABLES

- IX\_DEBUG

    Print debug messages to STDERR.

# AUTHOR

HIROSE Masaaki <hirose31@gmail.com>

# REPOSITORY

[https://github.com/hirose31/p5-InfluxDB](https://github.com/hirose31/p5-InfluxDB)

    git clone https://github.com/hirose31/p5-InfluxDB.git

patches and collaborators are welcome.

# SEE ALSO

[http://influxdb.org](http://influxdb.org)

# COPYRIGHT

Copyright HIROSE Masaaki

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
