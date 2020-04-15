# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'
require_relative 'lib/ocx_nimas/converter'

INPUT_OCX = File.join File.expand_path(__dir__), 'html', 'g6.wc.sp.ocx.html'
OUTPUT_OPF = 'g6.wc.sp.ocx.opf'
OUTPUT_XML = 'g6.wc.sp.ocx.xml'

converter = OcxNimas::Converter.new File.read(INPUT_OCX)
converter.generate File.expand_path('images', __dir__)

# Save the data
File.open(OUTPUT_OPF, 'wb') { |f| f.write converter.opf }
File.open(OUTPUT_XML, 'wb') { |f| f.write converter.xml }
