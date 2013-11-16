# encoding: utf-8

require 'bundler/setup'

require 'rspec'
require 'simplecov'

class SimpleCov::Formatter::QualityFormatter
  def format(result)
    SimpleCov::Formatter::HTMLFormatter.new.format(result)
    File.open("coverage/covered_percent", "w") do |f|
      f.puts result.source_files.covered_percent.to_f
    end
  end
end

SimpleCov.formatter = SimpleCov::Formatter::QualityFormatter

SimpleCov.start do
  add_filter '/spec/'
end

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
end
