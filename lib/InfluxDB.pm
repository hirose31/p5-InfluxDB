package InfluxDB;

use strict;
use warnings;
use 5.010_000;

our $VERSION = '0.002';

use Class::Accessor::Lite (
    new => 0,
    ro  => [qw(host port username database json)],
);

use Carp;
use Data::Validator;
use Mouse::Util::TypeConstraints;
use Furl;
use URI::Escape;
use JSON 2;

enum 'TimePrecision' => qw(s m u);

sub new {
    my $rule = Data::Validator->new(
        host     => { isa => 'Str' },
        port     => { isa => 'Int', default => 8086 },
        username => { isa => 'Str' },
        password => { isa => 'Str' },
        database => { isa => 'Str' },

        timeout  => { isa => 'Int', default => 120 },
        debug    => { isa => 'Bool', optional => 1 },
    );
    # Mouse::Util::apply_all_role leaks memory when takes 2 or more extensions.
    # so apply for each extension.
    $rule->with('NoRestricted');
    $rule->with('Method');
    my($class, $args) = $rule->validate(@_);

    if (delete $args->{debug}) {
        $ENV{IX_DEBUG} = 1;
    }

    my $self = bless {
        ua     => Furl->new(
            agent   => join('/', __PACKAGE__, $VERSION),
            timeout => $args->{timeout},
        ),
        json   => JSON->new,
        status => {},
        %$args
    }, $class;

    return $self;
}

sub debugf {
    return unless $ENV{IX_DEBUG};
    print STDERR "[DEBUG] ",sprintf(shift @_, @_),"\n";
}

sub status {
    my($self, $res) = @_;

    if ($res) {
        $self->{status} = {
            code        => $res->code,
            message     => $res->message,
            status_line => $res->status_line,
            content     => $res->content,
        };
        debugf("content: %s", $res->content);
    }

    return $self->{status};
}

sub errstr {
    my($self) = @_;
    my $errstr = "";

    if (substr($self->{status}{code}, 0, 2) ne "20") {
        $errstr = join("\n",
                       $self->{status}{status_line},
                       $self->{status}{content},
                   );
    }

    return $errstr;
}

sub as_hash {
    my(undef, $result) = @_;
    my $h;

    for my $r (@{ $result }) {
        my $series  = $r->{name};
        my @columns = @{ $r->{columns} };

        for my $p (@{ $r->{points} }) {
            my %ph;
            @ph{ @columns } = @$p;
            push @{ $h->{$series} }, \%ph;
        }
    }

    return $h;
}

sub switch_database {
    my($self, $args) = Data::Validator->new(
        database => { isa => 'Str' },
    )->with('Method')->validate(@_);

    $self->{database} = $args->{database};

    return 1;
}

sub switch_user {
    my($self, $args) = Data::Validator->new(
        username => { isa => 'Str' },
        password => { isa => 'Str' },
    )->with('Method')->validate(@_);

    $self->{username} = $args->{username};
    $self->{password} = $args->{password};

    return 1;
}

### database #############################################################
sub create_database {
    my($self, $args) = Data::Validator->new(
        database => { isa => 'Str' },
    )->with('Method')->validate(@_);

    my $url = $self->_build_url(
        path => '/db',
    );

    my $res = $self->{ua}->post($url, [], $self->json->encode({
        name => $args->{database},
    }));
    $self->status($res);

    return $res->is_success ? 1 : ();
}

sub list_database {
    my $self = shift;

    my $url = $self->_build_url(
        path => '/db',
    );

    my $res = $self->{ua}->get($url);
    $self->status($res);

    return $res->is_success ? $self->json->decode($res->content) : ();
}

sub delete_database {
    my($self, $args) = Data::Validator->new(
        database => { isa => 'Str' },
    )->with('Method')->validate(@_);

    my $url = $self->_build_url(
        path => '/db/'. $args->{database},
    );

    my $res = $self->{ua}->delete($url);
    $self->status($res);

    return $res->is_success ? 1 : ();
}

### points ###############################################################
sub write_points {
    my($self, $args) = Data::Validator->new(
        data           => { isa => 'ArrayRef|HashRef' },
        time_precision => { isa => 'TimePrecision', optional => 1 },
    )->with('Method')->validate(@_);

    my $data = ref($args->{data}) eq 'ARRAY' ? $args->{data} : [$args->{data}];
    $data = $self->json->encode($data);
    debugf("data: %s", $data);

    my $url = $self->_build_url(
       path =>  '/db/' . $self->database . '/series',
       qs   => {
           time_precision => exists $args->{time_precision} ? $args->{time_precision} :  undef,
       },
    );

    my $res = $self->{ua}->post($url, [], $data);
    $self->status($res);

    return $res->is_success ? 1 : ();
}

sub delete_points {
    my($self, $args) = Data::Validator->new(
        name  => { isa => 'Str' },
    )->with('Method')->validate(@_);

    my $url = $self->_build_url(
       path =>  '/db/' . $self->database . '/series/' . $args->{name},
       qs   => {
           %$args,
       },
    );

    my $res = $self->{ua}->delete($url);
    $self->status($res);

    return $res->is_success ? 1 : ();
}

sub create_scheduled_deletes {
    croak "Not implemented in InfluxDB v0.4.3";
    # my($self, $args) = Data::Validator->new(
    # )->with('Method')->validate(@_);
}

sub list_scheduled_deletes {
    croak "Not implemented in InfluxDB v0.4.3";
    # my($self, $args) = Data::Validator->new(
    # )->with('Method')->validate(@_);
}

sub delete_scheduled_deletes {
    croak "Not implemented in InfluxDB v0.4.3";
    # my($self, $args) = Data::Validator->new(
    # )->with('Method')->validate(@_);
}

sub query {
    my($self, $args) = Data::Validator->new(
        q              => { isa => 'Str' },
        time_precision => { isa => 'TimePrecision', optional => 1 },
        chunked        => { isa => 'Bool', default => 0 },
        # order          => { isa => 'Str', optional => 1 }, # not implemented?
    )->with('Method')->validate(@_);

    my $url = $self->_build_url(
        path => '/db/' . $self->database . '/series',
        qs   => {
            q              => $args->{q},
            time_precision => (exists $args->{time_precision} ? $args->{time_precision} :  undef),
            chunked        => ($args->{chunked} ? 'true' : 'false'),
            order          => (exists $args->{order} ? $args->{order} :  undef),
        },
    );

    my $res = $self->{ua}->get($url);
    $self->status($res);

    if ($res->is_success) {
        my $result;
        if ($args->{chunked}) {
            $result = [$self->json->incr_parse($res->content)];
        } else {
            $result = $self->json->decode($res->content);
        }
        return $result;
    } else {
        return;
    }
}

### Continuous Queries ###################################################
sub create_continuous_query {
    my($self, $args) = Data::Validator->new(
        q    => { isa => 'Str' },
        name => { isa => 'Str' },
    )->with('Method')->validate(@_);

    return $self->query(q => "$args->{q} into $args->{name}");
}

sub list_continuous_queries {
    my $self = shift;
    return $self->query(q => "list continuous queries");
}

sub drop_continuous_query {
    my($self, $args) = Data::Validator->new(
        id => { isa => 'Str' },
    )->with('Method')->validate(@_);

    return $self->query(q => "drop continuous query $args->{id}");
}

### user #################################################################
# fixme TODO
# get_list_cluster_admins
# add_cluster_admin
# update_cluster_admin_password
# delete_cluster_admin
# set_database_admin
# unset_database_admin
# alter_database_admin
# get_list_database_admins
# add_database_admin
# update_database_admin_password
# delete_database_admin
# get_database_users
# add_database_user
# update_database_user_password
# delete_database_user
# update_permission

### utils ################################################################
sub _build_url {
    my($self, $args) = Data::Validator->new(
        path => { isa => 'Str' },
        qs   => { isa => 'HashRef', optional => 1 },
    )->with('Method')->validate(@_);

    my $url = sprintf("http://%s:%s@%s:%d%s",
                      $self->username,
                      $self->{password},
                      $self->host,
                      $self->port,
                      $args->{path},
                  );
    if (exists $args->{qs}) {
        my @qs;
        for my $k (keys %{ $args->{qs} }) {
            next unless defined $args->{qs}{$k};
            push @qs, join('=', uri_escape($k), uri_escape($args->{qs}{$k}));
        }
        $url .= '?' . join('&', @qs) if @qs;
    }

    debugf("url: %s", $url);
    return $url
}

1;

__END__

=encoding utf-8

=begin html

<a href="https://travis-ci.org/hirose31/p5-InfluxDB"><img src="https://travis-ci.org/hirose31/p5-InfluxDB.png?branch=master" alt="Build Status" /></a>
<a href="https://coveralls.io/r/hirose31/p5-InfluxDB?branch=master"><img src="https://coveralls.io/repos/hirose31/p5-InfluxDB/badge.png?branch=master" alt="Coverage Status" /></a>

=end html

=head1 NAME

InfluxDB - Client library for InfluxDB

=begin readme

=head1 INSTALLATION

To install this module, run the following commands:

    perl Build.PL
    ./Build
    ./Build test
    ./Build install

=end readme

=head1 SYNOPSIS

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

=head1 DESCRIPTION

InfluxDB is a client library for InfluxDB E<lt>L<http://influxdb.org>E<gt>.

    **************************** CAUTION ****************************
    
    InfluxDB that is a time series database is still in development
    status, so this module is also alpha state. Any API will change
    without notice.
    
    *****************************************************************

=head1 METHODS

=head2 Class Methods

=head3 B<new>(%args:Hash) :InfluxDB

Creates and returns a new InfluxDB client instance. Dies on errors.

%args is following:

=over 4

=item host => Str

=item port => Int (default: 8086)

=item username => Str

=item password => Str

=item database => Str

=item timeout => Int (default: 120)

=item debug => Bool (optional)

=back

=head2 Instance Methods

=head3 B<write_points>(%args:Hash) :Bool

Write to multiple time series names.

=over 4

=item data => ArrayRef[HashRef] | HashRef

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

=item time_precision => "s" | "m" | "u" (optional)

The precision timestamps should come back in. Valid options are s for seconds, m for milliseconds, and u for microseconds.

=back

=begin comment

=item B<delete_points>() :Bool

=end comment

=head3 B<query>(%args:Hash) :Bool

=over 4

=item q => Str

The InfluxDB query language, see: L<http://influxdb.org/docs/query_language/>

=item time_precision => "s" | "m" | "u" (optional)

The precision timestamps should come back in. Valid options are s for seconds, m for milliseconds, and u for microseconds.

=item chunked => Bool (default: 0)

Chunked response.

=back

=head3 B<as_hash>($result:ArrayRef[HashRef]) :HashRef

Utility instance/class method for handling result of query.

Takes result of C<query()>(ArrayRef) and convert into following HashRef.

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

=head3 B<switch_database>(database => Str) :Bool

Switch to another database.

=head3 B<switch_user>(username => Str, password => Str) :Bool

Change your user-context.

=head3 B<create_database>(database => Str) :Bool

Create database. Requires cluster-admin privileges.

=head3 B<list_database>() :ArrayRef[HashRef]

List database. Requires cluster-admin privileges.

    [
      {
        name => "databasename",
        replicationFactor => 1
      },
      ...
    ]

=head3 B<delete_database>(database => Str) :Bool

Delete database. Requires cluster-admin privileges.

=head3 B<status>() :HashRef

Returns status of previous request, as following hash:

=over 4

=item code => Int

HTTP status code.

=item message => Str

HTTP status message.

=item status_line => Str

HTTP status line (code . " " . message).

=item content => Str

Response body.

=back

=head3 B<errstr>() :Str

Returns error message if previous query was failed.

=head3 B<host>() :Str

Returns hostname of InfluxDB server.

=head3 B<port>() :Str

Returns port number of InfluxDB server.

=head3 B<username>() :Str

Returns current user name.

=head3 B<database>() :Str

Returns current database name.

=head1 ENVIRONMENT VARIABLES

=over 4

=item IX_DEBUG

Print debug messages to STDERR.

=back

=head1 AUTHOR

HIROSE Masaaki E<lt>hirose31@gmail.comE<gt>

=head1 REPOSITORY

L<https://github.com/hirose31/p5-InfluxDB>

    git clone https://github.com/hirose31/p5-InfluxDB.git

patches and collaborators are welcome.

=head1 SEE ALSO

L<http://influxdb.org>

=head1 COPYRIGHT

Copyright HIROSE Masaaki

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
