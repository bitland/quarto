require "lino/version"
require 'rake'
require 'nokogiri'
require 'open3'

module Lino
  module_function

  EXTENSIONS_TO_SOURCE_FORMATS = {
    "md" => "markdown",
    "markdown" => "markdown",
    "org" => "orgmode"
  }

  SECTION_TEMPLATE = <<-EOF
  <!DOCTYPE html>
  <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
      <title></title>
    </head>
    <body>
    </body>
  </html>
  EOF
  def build_dir
    "build"
  end

  def source_exts
    EXTENSIONS_TO_SOURCE_FORMATS.keys
  end

  def format_of_source_file(source_file)
    ext = source_file.pathmap("%x")[1..-1]
    EXTENSIONS_TO_SOURCE_FORMATS.fetch(ext)
  end

  def source_files()
    FileList["**/*.{#{source_exts.join(',')}}"]
  end

  def export_dir
    "build/exports"
  end

  def export_files
    source_files.pathmap("#{export_dir}/%p").ext('.html')
  end

  def source_for_export_file(export_file)
    base = export_file.sub(/^#{export_dir}\//,'').ext('')
    pattern = "#{base}.{#{source_exts.join(',')}}"
    FileList[pattern].first
  end

  def export_command_for(source_file, export_file)
    %W[pandoc -w html5 -o #{export_file} #{source_file}]
  end

  def section_dir
    "build/sections"
  end

  def section_files
    export_files.pathmap("%{^#{export_dir},#{section_dir}}X%{html,xhtml}x")
  end

  def export_for_section_file(section_file)
    section_file.pathmap("%{^#{section_dir},#{export_dir}}X%{xhtml,html}x")
  end

  def normalize_export(export_file, section_file, format)
    format ||= "NO_FORMAT_GIVEN"
    send("normalize_#{format}_export", export_file, section_file)
  end

  def normalize_markdown_export(export_file, section_file)
    doc = open(export_file) do |f|
      Nokogiri::HTML(f)
    end
    normal_doc = Nokogiri::XML.parse(SECTION_TEMPLATE)
    normal_doc.at_css("body").replace(doc.at_css("body"))
    normal_doc.at_css("title").content = export_file.pathmap("%n")
    open(section_file, "w") do |f|
      Open3.popen2(*%W[xmllint --format --xmlout -]) do
        |stdin, stdout, wait_thr|
        normal_doc.write_xml_to(stdin)
        stdin.close
        IO.copy_stream(stdout, f)
      end
    end
  end
end
