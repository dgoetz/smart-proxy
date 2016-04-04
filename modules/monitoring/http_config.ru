require 'monitoring/monitoring_api'

map "/monitoring" do
  run Proxy::Monitoring::Api
end
