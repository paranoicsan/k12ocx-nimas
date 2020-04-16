# frozen_string_literal: true

require 'date'
require 'json/ld'
require 'nokogiri'
require 'open-uri'
require 'zip'

require_relative 'sanitizer'

module OcxNimas
  class Converter
    IMAGES_PATH = 'images'
    private_constant :IMAGES_PATH

    TEMPLATE_PATH = File.join File.expand_path('.', __dir__), 'templates'
    private_constant :TEMPLATE_PATH

    TEMPLATE_OPF = File.join TEMPLATE_PATH, 'ocx2nimas.opf'
    private_constant :TEMPLATE_OPF

    TEMPLATE_XML = File.join TEMPLATE_PATH, 'ocx2nimas.xslt'
    private_constant :TEMPLATE_XML

    def initialize(input_html)
      @images = []
      @json_ld = JSON::LD::API.load_html input_html, url: ''
      html = OcxNimas::Sanitizer.sanitize input_html
      @source = Nokogiri::HTML html
    end

    #
    # Generate the NIMAS file set. As a result there will be the following picture:
    #
    # -images/
    # -|-image-1.jpg
    # -|-image-2.jpg
    # -result.xml
    # -result.opf
    # -cover.pdf
    #
    # @param path File path where the final bundle should be generated
    # @param opts A set of options
    #
    # Possible options are:
    # - cover_pdf: +String+ File path to a cover to be added to a bundle
    # - force_download: +Boolean+ Force download the image if file with the same name already exists
    # - xml_filename: +String+ File name for the NIMAS conformant XML file, default to 'timestamp.xml'
    # - opf_filename: +String+ File name for the OPF file, default to 'timestamp.opf'
    # - zip: +Boolean+ Create the zip file if true
    #
    def generate(path, opts = {})
      raise ArgumentError, 'Specify the path where bundle should be generated' if path.to_s.empty?

      @opts = opts
      @path = path

      handle_images
      handle_sections
      handle_lists
      build_xml
      build_opf
      build_zip if opts[:zip]

      true
    end

    private

    attr_reader :images, :json_ld, :opts, :path, :source

    def build_opf
      opf = Nokogiri::XML File.read(TEMPLATE_OPF)
      opf.root['unique-identifier'] = unique_identifier

      build_opf_metadata opf
      build_opf_manifest opf

      filepath = File.join path, filename_opf
      File.open(filepath, 'wb') { |f| f.write opf.to_xml }
    end

    def build_xml
      template = Nokogiri::XSLT File.read(TEMPLATE_XML)
      xml = template.transform(build_xml_auxiliary)

      filepath = File.join path, filename_xml
      File.open(filepath, 'wb') { |f| f.write xml.to_xml }
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

    def build_zip
      zip_filename = "#{File.basename(filename_xml, File.extname(filename_xml))}.zip"
      Zip::OutputStream.open(zip_filename) do |zos|
        zos.put_next_entry filename_xml
        zos.puts File.read(File.join path, filename_xml)

        zos.put_next_entry filename_opf
        zos.puts File.read(File.join path, filename_opf)

        unless opts[:cover_pdf].to_s.empty?
          pdf_name = File.basename opts[:cover_pdf]
          pdf_path = File.join path, pdf_name
          zos.put_next_entry File.basename pdf_name
          zos.puts File.read(pdf_path)
        end

        images.each do |image_path|
          zos.put_next_entry image_path
          zos.puts File.read(image_path)
        end
      end
    end

    def filename_opf
      @filename_opf ||= opts[:opf_filepath].to_s.empty? ? "#{Time.now.to_i}.opf" : opts[:opf_filepath]
    end

    def filename_xml
      @filename_xml ||= opts[:xml_filepath].to_s.empty? ? "#{Time.now.to_i}.xml" : opts[:xml_filepath]
    end

    # Iterate over each image, fetch it and save,
    # update original HTML to point to a new location
    def handle_images
      re = /-/
      source.xpath('//img').each do |img_node|
        url = img_node['src']
        file_name = URI.parse(url).path.tr('/', '-').sub(re, '')
        file_path_relative = File.join IMAGES_PATH, file_name
        file_path_absolute = File.join path, file_path_relative
        img_node['src'] = file_path_relative

        images << file_path_relative

        next if File.exist?(file_path_absolute) && !opts[:force_download]

        save_image url, file_path_absolute
      end
      images.uniq!
    end

    def build_opf_manifest(opf)
      manifest = opf.at_xpath('/package/manifest')

      # main entry
      node = manifest.at_xpath('item[@id="nimasxml"]')
      node['href'] = filename_xml

      # pdf record
      unless opts[:cover_pdf].to_s.empty?
        pdf_name = File.basename opts[:cover_pdf]
        pdf_path = File.join path, pdf_name
        FileUtils.copy opts[:cover_pdf], pdf_path
        node = manifest.at_xpath('item[@id="nimaspdf"]')
        node['href'] = pdf_name
      end

      re = /[^\w\d]/
      images.each do |image_path|
        filename = File.basename(image_path)
        node = opf.create_element 'item'
        node['id'] = filename.gsub(re, '')
        node['href'] = image_path
        node['media-type'] = image_type File.extname(filename).tr('.', '')
        manifest.add_child node
      end
    end

    def build_opf_metadata(opf)
      node = opf.at_xpath('//dc-metadata')
      raise 'No dc-metadata!' if node.nil?

      metadata = Nokogiri::XML node.to_xml
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

      node.replace metadata.root
    end

    # Replace all <ul>/<ol> elements with NIMAS <list> elements
    def handle_lists
      source.xpath('//ul | //ol').each do |node|
        node['type'] = node.name
        node.name = 'list'
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

    def image_type(extname)
      case extname
      when 'png' then 'image/png'
      when 'jpg' then 'image/jpeg'
      when 'jpeg' then 'image/jpeg'
      when 'svg' then 'image/svg+xml'
      else
        raise "Image #{extname.upcase} is not supported."
      end
    end

    def save_image(url, path)
      case io = URI.open(url)
      when StringIO
        File.open(path, 'wb') { |f| f.write io.read }
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
