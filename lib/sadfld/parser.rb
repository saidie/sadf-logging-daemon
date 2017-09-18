require 'singleton'

module Sadfld
  class ParserFactory
    class << self
      def create(version)
        case version.to_s
        when '3.1'
          Parser31.instance
        end
      end
    end
  end

  class Parser31
    include Singleton

    KEY_MAP = {
      cpu_load: [:cpu],
      interrupts: [:intr],
      disk: [:disk_device],
      net_dev: [:iface],
      net_edev: [:iface],
      cpu_frequency: [:device, :number],
      fan_speed: [:device, :number],
      temperature: [:device, :number],
      voltage_input: [:device, :number],
      filesystems: [:filesystem],
    }

    def parse!(stat)
      stat[:sysstat][:hosts].flat_map { |host| parse_host!(host) }
    end

    private

    def parse_timestamp(ts)
      if ts[:date] !~ /\A([0-9]{4})-([0-9]{2})-([0-9]{2})\z/
        fail "unknown date format: #{ts[:date]}"
      end
      year, month, day = [$1.to_i, $2.to_i, $3.to_i]

      if ts[:time] !~ /\A([0-9]{2}):([0-9]{2}):([0-9]{2})\z/
        fail "unknown time format: #{ts[:time]}"
      end
      hour, min, sec = [$1.to_i, $2.to_i, $3.to_i]

      if ts[:utc] == 1
        Time.utc(year, month, day, hour, min, sec)
      else
        Time.local(year, month, day, hour, min, sec)
      end
    end

    def parse_host!(host)
      nodename = host[:nodename]
      host[:statistics].flat_map do |statistics|
        timestamp = parse_timestamp(statistics.delete(:timestamp)).to_i

        statistics.merge_child!(:network)
        statistics.merge_child!(:power_management)

        # filter/convert some values
        res = statistics.inject({}) do |hash, (type, values)|
          values = [values].flatten
          case type
          when :interrupts
            values.select! { |val| val[:intr] == 'sum' }
          when :io
            values.each do |value|
              value.merge_child!(:io_reads)
              value.merge_child!(:io_writes)
            end
          when :usb_devices
            values = nil
          end
          hash.merge(type => values)
        end.compact

        # extract tags
        KEY_MAP.each do |type, keys|
          next unless res[type]
          res[type].each do |value|
            value[:tags] = value.extract!(*keys)
          end
        end

        res.flat_map do |type, values|
          values.map do |value|
            value.deep_merge(type: type, timestamp: timestamp, tags: { host: nodename })
          end
        end
      end
    end
  end
end
