# frozen_string_literal: true

require 'date'
require 'json/ld'
require 'nokogiri'
require 'open-uri'

require_relative 'sanitizer'

module OcxNimas
  class Converter
    TEMPLATE_PATH = File.join File.expand_path('.', __dir__), 'templates'
    private_constant :TEMPLATE_PATH

    TEMPLATE_OPF = File.join TEMPLATE_PATH, 'ocx2nimas.opf'
    private_constant :TEMPLATE_OPF

    TEMPLATE_XML = File.join TEMPLATE_PATH, 'ocx2nimas.xslt'
    private_constant :TEMPLATE_XML

    def initialize(input_html)
      @json_ld = JSON::LD::API.load_html input_html, url: ''
      html = OcxNimas::Sanitizer.sanitize input_html
      @source = Nokogiri::HTML html
    end

    #
    # @param image_path File path where to download images
    # @param opts A set of options
    #
    # Possible options are:
    # - force_download: Force download the image if file with the same name already exists
    # - xml_filepath: File path for the NIMAS conformant XML file, default to 'timestamp.xml'
    # - opf_filepath: File path for the OPF file, default to 'timestamp.opf'
    #
    def generate(image_path, opts = {})
      @opts = opts

      handle_images image_path
      handle_sections
      handle_lists
      build_xml
      build_opf

      # TODO: Return the zipped file
      ''
    end

    private

    attr_reader :json_ld, :opts, :source

    def build_opf
      opf = Nokogiri::XML File.read(TEMPLATE_OPF)
      opf.root['unique-identifier'] = unique_identifier

      metadata_node = opf.at_xpath('//dc-metadata')
      raise 'No dc-metadata!' if metadata_node.nil?

      metadata_node.replace handle_metadata(metadata_node)

      File.open(filepath_opf, 'wb') { |f| f.write opf.to_xml }
    end

    def build_xml
      template = Nokogiri::XSLT File.read(TEMPLATE_XML)
      xml = template
              .transform(build_xml_auxiliary)
              .to_xml(save_with: Nokogiri::XML::Node::SaveOptions::FORMAT | Nokogiri::XML::Node::SaveOptions::AS_XML)

      File.open(filepath_xml, 'wb') { |f| f.write xml }
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

    def filepath_opf
      @filepath_opf ||= opts[:opf_filepath].to_s.empty? ? "#{Time.now.to_i}.opf" : opts[:opf_filepath]
    end

    def filepath_xml
      @filepath_xml ||= opts[:xml_filepath].to_s.empty? ? "#{Time.now.to_i}.xml" : opts[:xml_filepath]
    end

    # Iterate over each image, fetch it and save for the path specified,
    # update original HTML to point to a new location
    def handle_images(path)
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

    def handle_metadata(xml)
      metadata = Nokogiri::XML xml.to_xml
      metadata.at_xpath('//dc:Title').content = json_ld['name']
      # TODO: Use correct value Creator
      metadata.at_xpath('//dc:Creator').content = 'N/A'
      # TODO: Use correct value Publisher
      metadata.at_xpath('//dc:Publisher').content = 'N/A'
      metadata.at_xpath('//dc:Date').content = Date.today.strftime('%Y-%m-%d')

      identifier_node = metadata.at_xpath('//dc:Identifier')
      identifier_node['id'] = unique_identifier
      identifier_node.content = json_ld['identifier']

      metadata.at_xpath('//dc:Language').content = 'en'
      # TODO: Use correct value Rights
      metadata.at_xpath('//dc:Rights').content = 'N/A'
      # TODO: Use correct value Source
      metadata.at_xpath('//dc:Source').content = 'N/A'
      # TODO: Use correct value Subject
      metadata.at_xpath('//dc:Subject').content = 'Science'
      metadata.root
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

    def unique_identifier
      @unique_identifier ||= "#{json_ld['identifier']}-NIMAS"
    end
  end
end
