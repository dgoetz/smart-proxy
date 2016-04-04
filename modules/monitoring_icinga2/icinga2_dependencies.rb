require 'monitoring_common/dependency_injection/dependencies'

class Proxy::Monitoring::DependencyInjection::Dependencies
  dependency :monitoring_provider, Proxy::Monitoring::Icinga2::Host
end
