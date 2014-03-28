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

This module \`InfluxDB\` is a client library for InfluxDB <[http://influxdb.org](http://influxdb.org)>.

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

### __delete\_points__(name => Str) :Bool

Delete ALL DATA from series specified by _name_

### __query__(%args:Hash) :ArrayRef

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

### __create\_continuous\_query__(q => Str, name => Str) :ArrayRef

Create continuous query.

    $ix->create_continuous_query(
        q    => "select mean(sys) as sys, mean(usr) as usr from cpu group by time(15m)",
        name => "cpu.15m",
    );

### __list\_continuous\_queries__() :ArrayRef

List continuous queries.

### __drop\_continuous\_query__(id => Str) :ArrayRef

Delete continuous query that has specified id.

You can get id of continuous query by list\_continuous\_queries().

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

### __list\_series__() :ArrayRef\[HashRef\]

List series in current database

### __create\_database\_user__(name => Str, password => Str) :Bool

Create a database user on current database.

### __delete\_database\_user__(name => Str) :Bool

Delete a database user on current database.

### __update\_database\_user__(name => Str \[,password => Str\] \[,admin => Bool\]) :Bool

Update a database user on current database.

### __list\_database\_users__() :ArrayRef

List all database users on current database.

### __show\_database\_user__(name => Str) :HashRef

Show a database user on current database.

### __create\_cluster\_admin__(name => Str, password => Str) :Bool

Create a database user on current database.

### __delete\_cluster\_admin__(name => Str) :Bool

Delete a database user on current database.

### __update\_cluster\_admin__(name => Str, password => Str) :Bool

Update a database user on current database.

### __list\_cluster\_admins__() :ArrayRef

List all database users on current database.

### __show\_cluster\_admin__(name => Str) :HashRef

Show a database user on current database.

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
