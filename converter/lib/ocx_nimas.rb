# frozen_string_literal: true

require 'json/ld'
require 'nokogiri'
require 'open-uri'
require 'sanitize'

class OcxNimas
  SANITIZE_ATTRIBUTES = Sanitize::Config.merge(
    Sanitize::Config::BASIC[:attributes],
    all: %w(id class type),
    'img' => %w(alt src),
    'ol' => %w(start)
  ).freeze
  private_constant :SANITIZE_ATTRIBUTES

  SANITIZE_CONFIG = Sanitize::Config.merge(
    Sanitize::Config::BASIC,
    elements: Sanitize::Config::RELAXED[:elements] - Sanitize::Config::RESTRICTED[:elements] - %w(span),
    attributes: SANITIZE_ATTRIBUTES
  ).freeze
  private_constant :SANITIZE_CONFIG

  TEMPLATE_OPF = File.expand_path 'ocx2nimas.opf', __dir__
  private_constant :TEMPLATE_OPF

  TEMPLATE_XML = File.expand_path 'ocx2nimas.xslt', __dir__
  private_constant :TEMPLATE_XML

  attr_reader :opf, :xml

  def initialize(input_html)
    @json_ld = JSON::LD::API.load_html input_html, url: ''
    html = Sanitize.document input_html, SANITIZE_CONFIG
    @source = Nokogiri::HTML html
  end

  # Image path should be relative path
  def generate(image_path, opts = {})
    handle_images(image_path, opts) unless image_path.to_s.empty?
    handle_sections
    handle_lists
    build_xml
    build_opf
  end

  private

  attr_reader :json_ld, :source

  def build_opf
    @opf = 'TBD'
  end

  def build_xml
    template = Nokogiri::XSLT File.read(TEMPLATE_XML)
    @xml = template
             .transform(build_xml_auxiliary)
             .to_xml(save_with: Nokogiri::XML::Node::SaveOptions::FORMAT | Nokogiri::XML::Node::SaveOptions::AS_XML)
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

      id = item['@id'].tr('#', '')
      sections.add_child source.at_xpath("//section[@id='#{id}']").dup
    end

    xml_doc
  end

  # Iterate over each image, fetch it and save for the path specified,
  # update original HTML to point to a new location
  def handle_images(path, opts)
    re = /-/
    source.xpath('//img').each do |img_node|
      url = img_node['src']
      file_name = URI.parse(url).path.tr('/', '-').sub(re, '')
      file_path = File.join path, file_name
      img_node['src'] = file_path

      next if File.exist?(file_path) && !opts[:force_download]

      save_image url, file_path
    end
  end

  # Make sure that inside section should correct hierarchy
  # h1 -> h2 -> h3 -> [...]
  def handle_sections
    source.xpath('//section').each do |section|
      (2..6).each do |level|
        section.xpath(".//h#{level}").each { |node| node.name = "h#{level - 1}" }
      end
    end
  end

  # Replace all <ul>/<ol> elements with NIMAS <list> elements
  def handle_lists
    source.xpath('//ul | //ol').each do |node|
      node['type'] = node.name
      node.name = 'list'
    end
  end

  def save_image(url, path)
    case io = URI.open(url)
    when StringIO
      File.open(path, 'w') { |f| f.write(io) }
    when Tempfile
      io.close
      FileUtils.mv io.path, path
    end
  end
end
