# encoding: UTF-8
# frozen_string_literal: true

module Peatio
  module InfluxDB
    class << self
      def client(opts={})
        @client ||= ::InfluxDB::Client.new(config.merge(opts))
      end

      def config
        yaml = ::Pathname.new("config/influxdb.yml")
        return {} unless yaml.exist?

        erb = ::ERB.new(yaml.read)
        ::YAML.load(erb.result)[ENV.fetch('RAILS_ENV', 'development')].symbolize_keys || {}
      end

      def delete_measurments(measurment)
        client.query("delete from #{measurment}")
      end
    end
  end
end
