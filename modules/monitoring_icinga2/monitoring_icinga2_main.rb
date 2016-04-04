require 'rest-client'
require 'json'
require 'date'
require 'monitoring_common/monitoring_common'

module Proxy::Monitoring::Icinga2
  class Host < ::Proxy::Monitoring::Host

    include Proxy::Log
    include Proxy::Util

    def initialize(a_server = nil, a_manage_host = nil, a_show_status = nil)
      super(a_server || ::Proxy::Monitoring::Icinga2::Plugin.settings.monitoring_server,
            a_manage_host || ::Proxy::Monitoring::Plugin.settings.manage_host,
            a_show_status || ::Proxy::Monitoring::Plugin.settings.show_status)
      @baseurl = "https://#{Proxy::Monitoring::Icinga2::Plugin.settings.server}:#{Proxy::Monitoring::Icinga2::Plugin.settings.api_port}/v1/objects"
      @user = Proxy::Monitoring::Icinga2::Plugin.settings.api_user || "foreman"
      @password = Proxy::Monitoring::Icinga2::Plugin.settings.api_password
      @usercert = Proxy::Monitoring::Icinga2::Plugin.settings.api_usercert || "/etc/foreman-proxy/foreman.crt" 
      @userkey = Proxy::Monitoring::Icinga2::Plugin.settings.api_userkey || "/etc/foreman-proxy/foreman.key"
      @cacert = Proxy::Monitoring::Icinga2::Plugin.settings.api_cacert || "/etc/foreman-proxy/icinga-ca.crt"
    end

    def create_monitoring_host(name, address, attributes)
     validate_manage_host

     add_monitoring_host(name, address, attributes)
     add_monitoring_endpoint(name, address) if Proxy::Monitoring::Icinga2::Plugin.settings.manage_endpoint
     #add_monitoring_zone(name) if Proxy::Monitoring::Icinga2::Plugin.settings.manage_zone
    end

    def add_monitoring_host(name, address, attributes)
     attributes = JSON.parse(attributes)
     host = query_monitoring_object(name, "host")
     already_exists = 0
     if host != nil 
       if host["address"] != address
         already_exits = 1
       end 
       attributes.each do | attribute, value |
         attribute = attribute[5, attribute.length - 5]
         if host["vars"][attribute] != value
           already_exists = 1
           break
         end
       end
       host["vars"].each do | attribute, value |
         if attributes["vars.#{attribute}"] != value && attribute != "foreman"
           already_exists = 1
         end
         if attributes["vars.#{attribute}"] == nil && attribute != "foreman"
           attributes = deep_merge(attributes, "vars.#{attribute}" => nil)
         end
       end
       if already_exists == 0
         logger.warn "Monitoring - Host #{name} already exists and uptodate"
         return
       end
     end

     request_url = "#{@baseurl}/hosts/#{name}"
     host_template = Proxy::Monitoring::Icinga2::Plugin.settings.host_template || "generic-host"

     data = {
       "templates" => [ host_template ],
       "attrs" => { "address" => address, "vars.foreman" => true }
     }
     data = deep_merge(data, "attrs" => attributes)

     request = create_request(request_url)

     begin
       if already_exists == 0
         response = request.put(data.to_json)
       else
         response = request.post(data.to_json)
       end
     rescue => e
       response = e.response
     end

     if response.code == 200
       logger.debug "Monitoring - Host #{name} was created"
     else
       logger.warn "Monitoring - Host #{name} could not be created: #{e}"
     end
    end

    def add_monitoring_endpoint(name, address)
     request_url = "#{@baseurl}/endpoints/#{name}"
     data = {
       "attrs" => { "host" => address }
     }

     request = create_request(request_url)

     begin
       response = request.put(data.to_json)
     rescue => e
       response = e.response
     end

     if response.code == 200
       logger.debug "Monitoring - Endpoint #{name} was created"
     else
       logger.warn "Monitoring - Endpoint #{name} could not be created: #{e}"
     end
    end

    def remove_monitoring_host(name)
     validate_manage_host

     delete_monitoring_object(name, "host")
     delete_monitoring_object(name, "zone") if Proxy::Monitoring::Icinga2::Plugin.settings.manage_zone
     delete_monitoring_object(name, "endpoint") if Proxy::Monitoring::Icinga2::Plugin.settings.manage_endpoint
    end

    def status_monitoring_host(name)
     validate_show_status

     host = query_monitoring_object(name, "host")
     puts "#{host['name']} - #{host['last_check_result']['state']} - #{host['last_check_result']['output']} - #{Time.at(host['last_state_change']).to_datetime.strftime('%d.%m.%Y %H:%M:%S')}"
     services = query_monitoring_object(name, "service")
     if services != nil
       services.each do | service |
         service = service['attrs']
         puts "#{service['name']} - #{service['last_check_result']['state']} - #{service['last_check_result']['output']} - #{Time.at(service['last_state_change']).to_datetime.strftime('%d.%m.%Y %H:%M:%S')}"
       end
     end
    end

    def delete_monitoring_object(name, type)
     if type == "host"
       request_url = "#{@baseurl}/hosts/#{name}?cascade=1"
     else
       request_url = "#{@baseurl}/#{type}s/#{name}"
     end
     request = create_request(request_url)

     begin
       response = request.delete
     rescue => e
       response = e.response
     end

     if response.code == 200
       logger.debug "Monitoring - #{type} #{name} was deleted"
     else
       logger.warn "Monitoring - #{type} #{name} could not be deleted: #{e}"
     end
    end

    def query_monitoring_object(name, type)
     if type == "service"
       request_url = "#{@baseurl}/#{type}s?host.name=#{name}"
     else
       request_url = "#{@baseurl}/#{type}s/#{name}"
     end
     request = create_request(request_url)

     begin
       response = request.get
     rescue => e
       response = e.response
     end

     if response.code == 200
       if type == "service"
         return JSON.parse(response)["results"]
       else
         return JSON.parse(response)["results"][0]["attrs"]
       end
     else
       return nil
     end
    end

    def validate_show_status
      if ::Proxy::Monitoring::Plugin.settings.show_status == false
        logger.warn "Monitoring - Proxy is configured to not show the host status, enable it by setting show_status"
        raise "Monitoring - Proxy is configured to not show the host status"
      end
    end

    def validate_manage_host
      if ::Proxy::Monitoring::Plugin.settings.manage_host == false
        logger.warn "Monitoring - Proxy is configured to not manage the host, enable it by setting manage_host"
        raise "Monitoring - Proxy is configured to not manage the host"
      end
    end

    def create_request(request_url)
      headers = {
        "Accept" => "application/json",
      }
      
      if @user != nil && File.file?(@usercert) && File.file?(@userkey)
        request = RestClient::Resource.new(
          URI.encode(request_url),
          :headers => headers,
          :user => @user,
          :ssl_client_cert => OpenSSL::X509::Certificate.new(File.read(@usercert)),
          :ssl_client_key => OpenSSL::PKey::RSA.new(File.read(@userkey)),
          :ssl_ca_file => @cacert)
      elsif @user != nil && @password != nil
        request = RestClient::Resource.new(
          URI.encode(request_url),
          :headers => headers,
          :user => @user,
          :password => @password,
          :ssl_ca_file => @cacert)
      else
        logger.warn "Monitoring - Certificate or Password authentication has to be configured"
        raise "Monitoring - Certificate or Password authentication has to be configured"
      end
      puts request
      return request
    end

    def deep_merge(h1, h2)
      h1.merge(h2) { |key, h1_elem, h2_elem| deep_merge(h1_elem, h2_elem) }
    end

  end
end
