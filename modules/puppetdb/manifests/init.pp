# ==  Class puppetdb:
#
# Sets up the puppetdb clojure app.
# This assumes you're using
#
class puppetdb(
    $db_rw_host = hiera('puppetdb::db_rw_host', 'localhost'),
    $db_ro_host = hiera('puppetdb::db_ro_host', undef),
    $db_user = hiera('puppetdb::db_user', 'puppetdb'),
    $db_password = hiera('puppetdb::db_password'),
    $perform_gc = hiera('puppetdb::perform_gc', true),
    $jvm_opts = hiera('puppetdb::jvm_opts', '-Xmx162m'),
    $bind_ip = hiera('puppetdb::bind_ip', '0.0.0.0'),
    $command_processing_threads = hiera('puppetdb::command_processing_threads', 4),
    $db_ssl = hiera('puppetdb::db_ssl', false),
) {

    package { 'default-jdk':
        ensure => present,
    }

    ## PuppetDB installation

    exec { "install_puppetdb":
        command => '/usr/bin/curl -o /opt/puppetdb_4.4.0-1~wmf1_all.deb https://apt.wikimedia.org/wikimedia/pool/component/puppetdb4/p/puppetdb/puppetdb_4.4.0-1~wmf1_all.deb',
        unless  => '/bin/ls /opt/puppetdb_4.4.0-1~wmf1_all.deb',
    }

    exec { "puppetdb-termini":
        command => '/usr/bin/curl -o /opt/puppetdb-termini_4.4.0-1~wmf1_all.deb https://apt.wikimedia.org/wikimedia/pool/component/puppetdb4/p/puppetdb/puppetdb-termini_4.4.0-1~wmf1_all.deb',
        unless  => '/bin/ls /opt/puppetdb-termini_4.4.0-1~wmf1_all.deb',
    }

    package { "puppetdb":
        provider => dpkg,
        ensure   => present,
        source   => '/opt/puppetdb_4.4.0-1~wmf1_all.deb',
        require  => Package['default-jdk'],
    }

    package { "puppetdb-termini":
        provider => dpkg,
        ensure   => present,
        source   => '/opt/puppetdb-termini_4.4.0-1~wmf1_all.deb',
    }

    # Symlink /etc/puppetdb to /etc/puppetlabs/puppetdb
    file { '/etc/puppetdb':
        ensure => link,
        target => '/etc/puppetlabs/puppetdb',
    }
 
     file { '/var/lib/puppetdb':
         ensure => directory,
         owner  => 'puppetdb',
         group  => 'puppetdb',
     }

     file { '/etc/default/puppetdb':
         ensure  => present,
         owner   => 'root',
         group   => 'root',
         content => template('puppetdb/puppetdb.erb'),
     }

    ## Configuration

    file { '/etc/puppetdb/conf.d':
        ensure  => directory,
        owner   => 'puppetdb',
        group   => 'puppetdb',
        mode    => '0750',
        recurse => true,
    }

    # Ensure the default debian config file is not there

    file { '/etc/puppetdb/conf.d/config.ini':
        ensure => absent,
    }

    if $db_ssl {
      $ssl = '?ssl=true'
    } else {
      $ssl = ''
    }

    $default_db_settings = {
        'classname'   => 'org.postgresql.Driver',
        'subprotocol' => 'postgresql',
        'username'    => 'puppetdb',
        'password'    => $db_password,
        'subname'     => "//${db_rw_host}:5432/puppetdb${ssl}",
        'node-purge-ttl' => '1d',
    }

    if $perform_gc {
        $db_settings = merge(
            $default_db_settings,
            { 'report-ttl' => '1d', 'gc-interval' => '20' }
        )
    } else {
        $db_settings = $default_db_settings
    }

    puppetdb::config { 'database':
        settings => $db_settings,
    }

    #read db settings
    if $db_ro_host {
        $read_db_settings = merge(
            $default_db_settings,
            {'subname' => "//${db_ro_host}:5432/puppetdb${ssl}"}
        )
        puppetdb::config { 'read-database':
            settings => $read_db_settings,
        }
    }

    puppetdb::config { 'global':
        settings => {
            'vardir'         => '/var/lib/puppetdb',
            'logging-config' => '/etc/puppetdb/logback.xml',
        },
    }

    puppetdb::config { 'repl':
        settings => {'enabled' => false},
    }

    $jetty_settings = {
        'port'        => 8080,
        'ssl-port'    => 8081,
        'ssl-key'     => '/etc/puppetdb/ssl/private.pem',
        'ssl-cert'    => '/etc/puppetdb/ssl/public.pem',
        'ssl-ca-cert' => '/etc/puppetdb/ssl/ca.pem',
    }

    if $bind_ip {
        $actual_jetty_settings = merge($jetty_settings, {'ssl-host' => $bind_ip})
    } else {
        $actual_jetty_settings = $jetty_settings
    }

    puppetdb::config { 'jetty':
        settings => $actual_jetty_settings,
    }

    puppetdb::config { 'command-processing':
        settings => {
            'threads' => $command_processing_threads,
        },
    }

    package { 'policykit-1':
        ensure => present,
    }

    service { 'puppetdb':
        ensure  => running,
    }

    ufw::allow { 'puppetdb':
        proto => 'tcp',
        port  => 8081,
    }
}
