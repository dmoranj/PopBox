class redis {
  # Prerequisite packages
  #################################
  package { 'redis-server':
    ensure => installed,
  }
}
