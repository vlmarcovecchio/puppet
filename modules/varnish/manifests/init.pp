# class: varnish
class varnish {
    include varnish::nginx
    include varnish::prometheus_exporter

    package { [ 'varnish', 'stunnel4', 'varnish-modules' ]:
        ensure => present,
    }

    service { 'varnish':
        ensure  => 'running',
        require => Package['varnish'],
    }

    service { 'stunnel4':
        ensure  => 'running',
        require => Package['stunnel4'],
    }

    file { '/var/lib/varnish/mediawiki':
        ensure  => directory,
        notify  => Service['varnish'],
        require => Package['varnish'],
    }

    file { '/etc/varnish/default.vcl':
        ensure  => present,
        content => template('varnish/default.vcl'),
        notify  => Service['varnish'],
        require => Package['varnish'],
    }

    file { '/etc/default/varnish':
        ensure  => present,
        source  => 'puppet:///modules/varnish/varnish/varnish.default',
        notify  => Service['varnish'],
        require => Package['varnish'],
    }

    file { '/etc/systemd/system/varnish.service':
        ensure  => present,
        source  => 'puppet:///modules/varnish/varnish/varnish.service',
        require => Package['varnish'],
        notify  => Exec['systemctl daemon-reload'],
    }

    exec { 'systemctl daemon-reload':
        path        => '/bin',
        refreshonly => true,
    }

    include ssl::wildcard
    include ssl::hiera

    file { '/etc/nginx/sites-enabled/default':
        ensure => absent,
        notify => Service['nginx'],
    }

    file { '/etc/nginx/nginx.conf':
        content => template('varnish/nginx.conf.erb'),
        notify  => Service['nginx'],
    }

    file { '/etc/default/stunnel4':
        ensure  => present,
        source  => 'puppet:///modules/varnish/stunnel/stunnel.default',
        notify  => Service['stunnel4'],
        require => Package['stunnel4'],
    }

    file { '/etc/stunnel/mediawiki.conf':
        ensure  => present,
        source  => 'puppet:///modules/varnish/stunnel/stunnel.conf',
        notify  => Service['stunnel4'],
        require => Package['stunnel4'],
    }

    file { '/usr/lib/nagios/plugins/check_varnishbackends':
        ensure => present,
        source => 'puppet:///modules/varnish/icinga/check_varnishbackends.py',
        mode   => '0755',
    }

    file { '/usr/lib/nagios/plugins/check_nginx_errorrate':
        ensure => present,
        source => 'puppet:///modules/varnish/icinga/check_nginx_errorrate',
        mode   => '0755',
    }

    # This script needs root access to read /etc/varnish/secret
    sudo::user { 'nrpe_sudo_checkvarnishbackends':
        user       => 'nagios',
        privileges => [ 'ALL = NOPASSWD: /usr/lib/nagios/plugins/check_varnishbackends' ],
    }

    # FIXME: Can't read access files without root
    sudo::user { 'nrpe_sudo_checknginxerrorrate':
        user       => 'nagios',
        privileges => [ 'ALL = NOPASSWD: /usr/lib/nagios/plugins/check_nginx_errorrate' ],
    }

    logrotate::conf { 'stunnel4':
        ensure => present,
        source => 'puppet:///modules/varnish/stunnel/stunnel4.logrotate.conf',
    }

    if hiera('base::monitoring::use_icinga2', false) {
        icinga2::custom::services { 'Varnish Backends':
            check_command => 'nrpe',
            vars          => {
                nrpe_command => 'check_varnishbackends',
            },
        }

        icinga2::custom::services { 'HTTP 4xx/5xx ERROR Rate':
            check_command => 'nrpe',
            vars          => {
                nrpe_command => 'check_nginx_errorrate',
            },
        }
    } else {
        icinga::service { 'varnish':
            description   => 'Varnish Backends',
            check_command => 'check_nrpe_1arg!check_varnishbackends',
        }

        icinga::service { 'varnish_error_rate':
            description   => 'HTTP 4xx/5xx ERROR Rate',
            check_command => 'check_nrpe_1arg!check_nginx_errorrate',
        }
    }
}
