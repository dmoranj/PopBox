# Configuration
################################
$installdir = "/home/ubuntu"
$popboxdir = "${installdir}/PopBox"

# Prerequisite packages
#################################
package { 'git':
ensure => installed,
}

package { 'nodejs':
ensure => installed,
}

package { 'nodejs-legacy':
ensure => installed,
require => Package['nodejs'],
}

package { 'npm':
ensure => installed,
require => Package['nodejs'],
}

package { 'redis-server':
ensure => installed,
}

notify {'Packages installed':
require => Package['npm'],
}

# Install the appropriate version of node with n
###################################################

Exec {
path => [
'/usr/local/bin',
'/opt/local/bin',
'/usr/bin',
'/usr/sbin',
'/bin',
'/sbin'],
logoutput => true,
}


exec {'n':
command => 'npm install -g n',
unless => 'which n',
require => Package['nodejs-legacy', 'npm'],
}

exec {'n 0.8.14':
unless => 'node --version |grep 0.8.14',
require => Exec['n'],
}

notify {'Proper Node.js version installed':
require => Exec['n 0.8.14'],
}

# Install Popbox
#################################################
exec {'popbox':
command => 'git clone https://github.com/dmoranj/PopBox.git',
cwd => $installdir,
unless => "ls ${popboxdir}",
}

exec {'dependencies':
command => 'npm install',
cwd     => $popboxdir,
require => Exec['popbox'],
}

notify {'Popbox cloned and installed':
require => Exec['dependencies'],
}

# Execute Popbox
######################################################
exec {'popbox':
command => 'nohup bin/popbox &> pop.log&',
cwd => $popboxdir,
require => Exec['dependencies'],
}

