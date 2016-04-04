module Proxy::Monitoring
  class Plugin < ::Proxy::Plugin
    http_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))
    https_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))

    uses_provider
    default_settings :use_provider => 'monitoring_icinga2', :manage_host => true, :show_status => true
    plugin :monitoring, ::Proxy::VERSION

    after_activation do
      require 'monitoring_common/dependency_injection/container'
      require 'monitoring_common/dependency_injection/dependencies'
    end
  end
end
