# frozen_string_literal: true

require 'json/ld'
require 'nokogiri'

class OcxNimas
  TEMPLATE = File.expand_path 'ocx2nimas.xslt', __dir__
  private_constant :TEMPLATE

  attr_reader :opf, :xml

  def initialize(input_html)
    @json_ld = JSON::LD::API.load_html input_html, url: ''
    @html_doc = Nokogiri::HTML input_html
  end

  def generate
    build_xml
    build_opf
  end

  private

  attr_reader :html_doc, :json_ld

  def build_opf
    @opf = 'TBD'
  end

  def build_xml
    template = Nokogiri::XSLT File.read(TEMPLATE)
    @xml = template.transform(build_xml_auxiliary).to_s
  end

  def build_xml_auxiliary
    xml_doc = Nokogiri::XML::Document.new
    root = xml_doc.create_element 'root'
    xml_doc.root = root
    root.add_child xml_doc.create_element('title', json_ld['name'])
    sections = xml_doc.create_element('sections')
    root.add_child sections

    # Iterate over graph, take each Activity and extract its content
    json_ld['@graph'].each do |item|
      next unless item['@type'].include?('oer:Activity')

      sections.add_child html_doc.at_xpath("//*/section[@id='#{item['@id'].tr('#', '')}']")
    end

    xml_doc
  end
end
