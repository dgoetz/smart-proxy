require 'monitoring_common/dependency_injection/container'

module Proxy::Monitoring
  module DependencyInjection
    class Dependencies
      extend Proxy::Monitoring::DependencyInjection::Wiring
    end
  end
end
