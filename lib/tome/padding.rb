require 'yaml'
require 'securerandom'

module Tome
  class Padding
    def self.pad(value, min_pad, max_pad)
      padding = Random.rand(min_pad..max_pad)
      YAML.dump(:value => value, :padding => SecureRandom.random_bytes(padding))
    end

    def self.unpad(inflated_value)
      yaml = YAML.load(inflated_value)
      yaml[:value]
    end
  end
end