require 'monitoring_common/monitoring_common'
require 'ipaddr'

module Proxy::Monitoring
  class Api < ::Sinatra::Base
    extend Proxy::Monitoring::DependencyInjection::Injectors
    inject_attr :monitoring_provider, :server

    helpers ::Proxy::Helpers
    authorize_with_trusted_hosts
    authorize_with_ssl_client

    post "/?" do
      name = params[:name]
      address = params[:address]
      attributes = params[:attributes]

      log_halt(400, "'create' requires name, address, and attributes parameters") if name.nil? || address.nil? || attributes.nil?

      begin
        validate_dns_name!(name)

        server.create_monitoring_host(name, address, attributes)
      rescue Proxy::Monitoring::Collision => e
        log_halt 409, e
      rescue Exception => e
        log_halt 400, e
      end
    end

    delete "/:value" do
      name = params[:value]

      begin
        validate_dns_name!(name)

        server.remove_monitoring_host(name)

      rescue Proxy::Monitoring::NotFound => e
        log_halt 404, e
      rescue => e
        log_halt 400, e
      end
    end

    get "/:value" do
      name = params[:value]

      begin
        validate_dns_name!(name)

        server.status_monitoring_host(name)

      rescue Proxy::Monitoring::NotFound => e
        log_halt 404, e
      rescue => e
        log_halt 400, e
      end
    end

    def validate_dns_name!(name)
      raise Proxy::Monitoring::Error.new("Invalid DNS name #{name}") unless name =~ /^([a-zA-Z0-9]([-a-zA-Z0-9]+)?\.?)+$/
    end
  end
end
