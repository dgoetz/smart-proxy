module ::Proxy::Monitoring::Icinga2
  class Plugin < ::Proxy::Provider
    plugin :monitoring_icinga2, ::Proxy::VERSION

    default_settings :server => 'localhost'
    default_settings :api_port => '5665'

    requires :monitoring, ::Proxy::VERSION

    after_activation do
      require 'monitoring_icinga2/monitoring_icinga2_main'
      require 'monitoring_icinga2/icinga2_dependencies'
    end
  end
end
