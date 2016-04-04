module Proxy::Monitoring
  class Error < RuntimeError; end
  class NotFound < RuntimeError; end
  class Collision < RuntimeError; end

  class Host
    attr_reader :server, :manage_host, :show_status

    def initialize(server = nil, manage_host = nil, show_status = nil)
      @server = server || "localhost"
      @manage_host = manage_host || "true"
      @show_status = show_status || "true"
    end
  end
end
