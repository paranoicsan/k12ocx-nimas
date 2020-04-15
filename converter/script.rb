# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'
require_relative 'lib/ocx_nimas/converter'

INPUT_OCX = File.join File.expand_path(__dir__), 'html', 'g6.wc.sp.ocx.html'
OUTPUT_OPF = File.join File.expand_path(__dir__), 'g6.wc.sp.ocx.opf'
OUTPUT_XML = File.join File.expand_path(__dir__), 'g6.wc.sp.ocx.xml'

opts = {
  force_download: true,
  opf_filename: OUTPUT_OPF,
  xml_filename: OUTPUT_XML
}

converter = OcxNimas::Converter.new File.read(INPUT_OCX)
converter.generate File.expand_path('images', __dir__), opts
