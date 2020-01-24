# encoding: UTF-8
# frozen_string_literal: true

require 'peatio/influxdb'
class KLineService
  POINT_PERIOD_IN_SECONDS = 60

  # Point period units are calculated in POINT_PERIOD_IN_SECONDS.
  # It means that period with value 5 is equal to 5 minutes (5 * POINT_PERIOD_IN_SECONDS = 300).
  AVAILABLE_POINT_PERIODS = [1, 5, 15, 30, 60, 120, 240, 360, 720, 1440, 4320, 10_080].freeze

  AVAILABLE_POINT_LIMITS  = (1..10_000).freeze

  HUMANIZED_POINT_PERIODS = {
    1 => '1m', 5 => '5m', 15 => '15m', 30 => '30m',                   # minuets
    60 => '1h', 120 => '2h', 240 => '4h', 360 => '6h', 720 => '12h',  # hours
    1440 => '1d', 4320 => '3d',                                       # days
    10_080 => '1w' # weeks
  }.freeze

  attr_accessor :market_id, :period

  class << self
    def humanize_period(period)
      HUMANIZED_POINT_PERIODS.fetch(period) do
        raise StandardError, "Not available period #{period}"
      end
    end
  end

  def initialize(marked_id, period)
    @market_id = marked_id
    @period    = KLineService.humanize_period(period)
  end

  # OHCL - open, high, closing, and low prices.
  def get_ohlc(options = {})
    options = options.symbolize_keys.tap do |o|
      o.delete(:limit) if o[:time_from].present? && o[:time_to].present?
    end

    if options[:time_from].present? && options[:time_to].present?
      # to ns
      time_from = options[:time_from].to_i * 1_000_000_000
      time_to = options[:time_to].to_i * 1_000_000_000

      Peatio::InfluxDB.client(epoch: 's').query("select * from candles_#{@period} where market='#{@market_id}' and time >= #{time_from} and time < #{time_to}") do |_name, _tags, points|
        result = points.map do |point|
          [point['time'], point['open'], point['high'], point['low'], point['close'], point['volume']]
        end

        return result
      end
    elsif options[:time_from].present? && options[:time_to].blank?
      time_from = options[:time_from].to_i * 1_000_000_000

      Peatio::InfluxDB.client(epoch: 's').query("select * from candles_#{@period} where market='#{@market_id}' and time >= #{time_from} limit #{options[:limit]}") do |_name, _tags, points|
        result = points.map do |point|
          [point['time'], point['open'], point['high'], point['low'], point['close'], point['volume']]
        end

        return result
      end
    elsif options[:time_from].blank? && options[:time_to].present?
      Peatio::InfluxDB.client(epoch: 's').query("select count(high) from candles_1m") do |_, _, values|
        options['total'] = values.first['count']
      end
      time_to = options[:time_to].to_i * 1_000_000_000

      binding.pry
      Peatio::InfluxDB.client(epoch: 's').query("select * from candles_#{@period} where market='#{@market_id}' and time <=  #{time_to} limit #{options[:limit]} offset #{options['total'] - options[:limit]}") do |_name, _tags, points|
        result = points.map do |point|
          [point['time'], point['open'], point['high'], point['low'], point['close'], point['volume']]
        end

        return result
      end
    else
      Peatio::InfluxDB.client(epoch: 's').query("select count(high) from candles_1m") do |_, _, values|
        options['total'] = values.first['count']
      end

      Peatio::InfluxDB.client(epoch: 's').query("select * from candles_#{@period} where market='#{@market_id}' limit #{options[:limit]} offset #{options['total'] - options[:limit]}") do |_name, _tags, points|
        result = points.map do |point|
          [point['time'], point['open'], point['high'], point['low'], point['close'], point['volume']]
        end

        return result
      end
    end
  end
end
