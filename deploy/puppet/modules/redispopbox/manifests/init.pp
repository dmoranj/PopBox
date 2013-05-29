class redispopbox {
  # Prerequisite packages
  #################################
  package { 'redis-server':
    ensure => installed,
  }
  
  service { 'redis-server':
    ensure  => "running",
    enable  => "true",
    require => Package["redis-server"],
  }

  file { "/etc/redis/redis.conf":
    notify  => Service["redis-server"],
    owner => "root",
    group => "root",
    mode => 644,
    source => "puppet:///modules/${module_name}/redis.conf",
  }
}
