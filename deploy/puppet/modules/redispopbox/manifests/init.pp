class redispopbox {
  # Prerequisite packages
  #################################
  package { 'redis-server':
    ensure => installed,
  }
}
