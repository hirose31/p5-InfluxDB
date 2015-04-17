<div>
    <a href="https://travis-ci.org/hirose31/p5-InfluxDB"><img src="https://travis-ci.org/hirose31/p5-InfluxDB.png?branch=master" alt="Build Status" /></a>
    <a href="https://coveralls.io/r/hirose31/p5-InfluxDB?branch=master"><img src="https://coveralls.io/repos/hirose31/p5-InfluxDB/badge.png?branch=master" alt="Coverage Status" /></a>
</div>

# NAME

InfluxDB - Client library for InfluxDB

# SYNOPSIS

    use InfluxDB;
    
    my $ix = InfluxDB->new(
        host     => '127.0.0.1',
        port     => 8086,
        username => 'scott',
        password => 'tiger',
        database => 'test',
        # ssl => 1, # enable SSL/TLS access
        # timeout => 5, # set timeout to 5 seconds
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

### **new**(%args:Hash) :InfluxDB

Creates and returns a new InfluxDB client instance. Dies on errors.

%args is following:

- host => Str
- port => Int (default: 8086)
- username => Str
- password => Str
- database => Str
- ssl => Bool (optional)
- timeout => Int (default: 120)
- debug => Bool (optional)

## Instance Methods

### **write\_points**(%args:Hash) :Bool

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

    The `time` and any other data fields which should be graphable must
    be numbers, not text.  See ["simple scalars" in JSON](https://metacpan.org/pod/JSON#simple-scalars).

- time\_precision => "s" | "m" | "u" (optional)

    The precision timestamps should come back in. Valid options are s for seconds, m for milliseconds, and u for microseconds.

### **delete\_points**(name => Str) :Bool

Delete ALL DATA from series specified by _name_

### **query**(%args:Hash) :ArrayRef

- q => Str

    The InfluxDB query language, see: [http://influxdb.org/docs/query\_language/](http://influxdb.org/docs/query_language/)

- time\_precision => "s" | "m" | "u" (optional)

    The precision timestamps should come back in. Valid options are s for seconds, m for milliseconds, and u for microseconds.

- chunked => Bool (default: 0)

    Chunked response.

### **as\_hash**($result:ArrayRef\[HashRef\]) :HashRef

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

### **create\_continuous\_query**(q => Str, name => Str) :ArrayRef

Create continuous query.

    $ix->create_continuous_query(
        q    => "select mean(sys) as sys, mean(usr) as usr from cpu group by time(15m)",
        name => "cpu.15m",
    );

### **list\_continuous\_queries**() :ArrayRef

List continuous queries.

### **drop\_continuous\_query**(id => Str) :ArrayRef

Delete continuous query that has specified id.

You can get id of continuous query by list\_continuous\_queries().

### **switch\_database**(database => Str) :Bool

Switch to another database.

### **switch\_user**(username => Str, password => Str) :Bool

Change your user-context.

### **create\_database**(database => Str) :Bool

Create database. Requires cluster-admin privileges.

### **list\_database**() :ArrayRef\[HashRef\]

List database. Requires cluster-admin privileges.

    [
      {
        name => "databasename",
        replicationFactor => 1
      },
      ...
    ]

### **delete\_database**(database => Str) :Bool

Delete database. Requires cluster-admin privileges.

### **list\_series**() :ArrayRef\[HashRef\]

List series in current database

### **create\_database\_user**(name => Str, password => Str) :Bool

Create a database user on current database.

### **delete\_database\_user**(name => Str) :Bool

Delete a database user on current database.

### **update\_database\_user**(name => Str \[,password => Str\] \[,admin => Bool\]) :Bool

Update a database user on current database.

### **list\_database\_users**() :ArrayRef

List all database users on current database.

### **show\_database\_user**(name => Str) :HashRef

Show a database user on current database.

### **create\_cluster\_admin**(name => Str, password => Str) :Bool

Create a database user on current database.

### **delete\_cluster\_admin**(name => Str) :Bool

Delete a database user on current database.

### **update\_cluster\_admin**(name => Str, password => Str) :Bool

Update a database user on current database.

### **list\_cluster\_admins**() :ArrayRef

List all database users on current database.

### **status**() :HashRef

Returns status of previous request, as following hash:

- code => Int

    HTTP status code.

- message => Str

    HTTP status message.

- status\_line => Str

    HTTP status line (code . " " . message).

- content => Str

    Response body.

### **errstr**() :Str

Returns error message if previous query was failed.

### **host**() :Str

Returns hostname of InfluxDB server.

### **port**() :Str

Returns port number of InfluxDB server.

### **username**() :Str

Returns current user name.

### **database**() :Str

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
