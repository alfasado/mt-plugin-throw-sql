package ThrowSQL::Plugin;
use strict;
use Time::HiRes;

use Data::Dumper;
{
    package Data::Dumper;
    sub qquote { return shift; }
}
$Data::Dumper::Useperl = 1;

sub _throw_sql {
    my $app = shift;
    if (! $app->instance->config( 'AllowThrowSQL' ) ) {
        return $app->trans_error( 'Permission denied.' );
    }
    my $plugin = MT->component( 'ThrowSQL' );
    if (! $app->user->is_superuser ) {
        return $app->trans_error( 'Permission denied.' );
    }
    if ( $app->request_method eq 'POST' ) {
        if (! $app->validate_magic ) {
            return $app->trans_error( 'Permission denied.' );
        }
    }
    my %param;
    if ( my $type = $app->param( '_type' ) ) {
        if ( $type eq 'sql' ) {
            my $query = $app->param( 'sql_request' );
            $param{ sql_request } = $query;
            require MT::Object;
            my $start = Time::HiRes::time();
            my $driver = MT::Object->driver;
            my $dbh = $driver->{ fallback }->{ dbh };
            my $sth = $dbh->prepare( $query );
            return $app->trans_error( "Error in query: " . $dbh->errstr ) if $dbh->errstr;
            my $do = $sth->execute();
            return $app->trans_error( "Error in query: " . $sth->errstr ) if $sth->errstr;
            my @row;
            my @next_row;
            my $columns = $sth->{ NAME_hash };
            @next_row = $sth->fetchrow_array();
            while ( @next_row ) {
                push ( @row, @next_row );
                @next_row = $sth->fetchrow_array();
            }
            $sth->finish();
            my $end = Time::HiRes::time();
            my $time = $end - $start;
            my $res;
            if ( @row ) {
                $res = Dumper @row;
            } else {
                $res = Dumper $do;
            }
            Encode::_utf8_on( $res );
            $param{ processing_time } = $time;
            $param{ page_msg } = $res;
        }
    }
    my $tmpl = File::Spec->catfile( $plugin->path, 'tmpl', 'throw_sql.tmpl' );
    return $app->build_page( $tmpl, \%param );
}

1;