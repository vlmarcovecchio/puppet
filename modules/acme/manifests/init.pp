# Small acme-tiny manifest
class acme {
    git::clone { 'acme-tiny':
        ensure    => present,
        directory => '/root/acme-tiny',
        origin    => 'https://github.com/diafygi/acme-tiny.git',
    }

    file { '/root/ssl':
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0770',
    }

    file { '/root/ssl-certificate':
        ensure => present,
        source => 'puppet:///modules/acme/ssl-certificate',
        mode   => '0555',
    }

    file { '/root/account.key':
        ensure => present,
        source => 'puppet:///private/acme/account.key',
        require => Git::Clone['acme-tiny'],
    }

    file { '/var/lib/nagios/ssl-acme':
        ensure => present,
        source => 'puppet:///modules/acme/ssl-acme',
        owner  => 'nagios',
        group  => 'nagios',
    }

    file { '/var/lib/nagios/LE.crt':
        ensure => present,
        source => 'puppet:///modules/acme/LE.crt',
        owner  => 'nagios',
        group  => 'nagios',
    }

    file { '/var/lib/nagios/id_rsa':
        ensure => present,
        source => 'puppet:///private/acme/id_rsa',
        owner  => 'nagios',
        group  => 'nagios',
        mode   => '0400',
    }

    sudo::user { 'nrpe_ssl-certificate':
        user       => 'nagios',
        privileges => [ 'ALL = NOPASSWD: /root/ssl-certificate' ],
    }
}
