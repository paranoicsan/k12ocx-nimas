# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'
require_relative 'lib/ocx_nimas'

INPUT_OCX = File.join File.expand_path(__dir__), 'html', 'g6.wc.sp.ocx.html'
OUTPUT_OPF = 'g6.wc.sp.ocx.opf'
OUTPUT_XML = 'g6.wc.sp.ocx.xml'

# Create a builder and generate the data
builder = OcxNimas.new File.read(INPUT_OCX)
builder.generate

# Save the data
File.open(OUTPUT_OPF, 'wb') { |f| f.write builder.opf }
File.open(OUTPUT_XML, 'wb') { |f| f.write builder.xml }
