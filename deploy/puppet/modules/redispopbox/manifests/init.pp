class redispopbox {
  # Prerequisite packages
  #################################
  package { 'redis-server':
    ensure => installed,
  }
  
  file { "/etc/redis/redis.conf":
    owner => "root",
    group => "root",
    mode => 644,
    source => "puppet:///modules/${module_name}/redis.conf",
  }
}
