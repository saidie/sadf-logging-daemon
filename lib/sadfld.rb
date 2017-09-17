require 'tempfile'

Bundler.require

class Hash
  def merge_child!(key)
    merge!(delete(key)) if Hash === self[key]
  end
end

module Sadfld
  class << self
    def read_stat
      MultiJson.load(STDIN.read).deep_transform_keys do |key|
        key.gsub('-', '_').to_sym
      end
    end
  end
end

require_relative 'sadfld/parser'
