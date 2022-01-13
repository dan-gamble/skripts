#!/usr/bin/env ruby

require 'fileutils'
require 'optparse'
require 'shellwords'

options = {}
OptionParser.new do |parser|
  parser.banner = "Usage: #{__FILE__} [options]"

  parser.on("-pPROJECT", "--project=PROJECT", "The project directory we want to Magentoify") do |p|
    options[:project] = p
  end
end.parse!

raise "A path to a project is required!" unless options.key? :project

PROJECT_ROOT = options[:project]
MODELS_PATH = File.join(PROJECT_ROOT, 'app', 'models')
FILES_TO_SKIP = ["application_record.rb"]
MODEL_FILES = Dir["#{MODELS_PATH}/*.rb"].select { |f| !FILES_TO_SKIP.include?(f.split('/').last) }

def get_model_file_contents!(&block)
  MODEL_FILES.each do |file|
    text = File.read(file)

    block.call(file, text)
  end
end

def set_model_tables!
  get_model_file_contents! do |file, text|
    text_lines = text.lines
    index_of_class_line = text_lines.index { |line| line.include? 'class' }
    next if index_of_class_line.nil?

    text_lines.insert(index_of_class_line + 1, "  self.table_name = \"#{File.basename(file, ".*")}\"")
    text_lines.insert(index_of_class_line + 2, "\n")

    File.open(file, 'w') { |f| f.puts text_lines.join }
  end
end

def fix_attribute_references!
  get_model_file_contents! do |file, text|
    text_lines = text.lines
    index_of_wanted_line = text_lines.index { |line| line.include? "belongs_to :attribute" }
    next if index_of_wanted_line.nil?

    text_lines[index_of_wanted_line].gsub! "belongs_to :attribute", "belongs_to :eav_attribute, class_name: \"EavAttribute\", foreign_key: :attribute_id"

    File.open(file, 'w') { |f| f.puts text_lines.join }
  end
end

def fix_entity_references!
  entities = {
    "customer": "CustomerEntity",
    "customer_address": "CustomerAddressEntity",
    "catalog_category": "CatalogCategoryEntity",
    "catalog_product": "CatalogProductEntity",
  }

  entities.each do |entity, model|
    get_model_file_contents! do |file, text|
      next unless File.basename(file, ".*").start_with? entity.to_s
      text_lines = text.lines
      index_of_wanted_line = text_lines.index { |line| line.include? "belongs_to :entity" }
      next if index_of_wanted_line.nil?

      text_lines[index_of_wanted_line].gsub! "belongs_to :entity", "belongs_to :entity, class_name: \"#{model}\", foreign_key: :entity_id"

      File.open(file, 'w') { |f| f.puts text_lines.join }
    end
  end
end

def add_entity_references!
  entities = {
    "customer_entity": [
      { key: :datetimes, class_name: :CustomerEntityDatetime, attribute: :entity_id },
      { key: :decimals, class_name: :CustomerEntityDecimal, attribute: :entity_id },
      { key: :ints, class_name: :CustomerEntityInt, attribute: :entity_id },
      { key: :texts, class_name: :CustomerEntityText, attribute: :entity_id },
      { key: :varchars, class_name: :CustomerEntityVarchar, attribute: :entity_id },
    ],
    "customer_address_entity": [
      { key: :datetimes, class_name: :CustomerAddressEntityDatetime, attribute: :entity_id },
      { key: :decimals, class_name: :CustomerAddressEntityDecimal, attribute: :entity_id },
      { key: :ints, class_name: :CustomerAddressEntityInt, attribute: :entity_id },
      { key: :texts, class_name: :CustomerAddressEntityText, attribute: :entity_id },
      { key: :varchars, class_name: :CustomerAddressEntityVarchar, attribute: :entity_id },
    ],
    "catalog_category_entity": [
      { key: :datetimes, class_name: :CatalogCategoryEntityDatetime, attribute: :entity_id },
      { key: :decimals, class_name: :CatalogCategoryEntityDecimal, attribute: :entity_id },
      { key: :ints, class_name: :CatalogCategoryEntityInt, attribute: :entity_id },
      { key: :texts, class_name: :CatalogCategoryEntityText, attribute: :entity_id },
      { key: :varchars, class_name: :CatalogCategoryEntityVarchar, attribute: :entity_id },
    ],
    "catalog_product_entity": [
      { key: :datetimes, class_name: :CatalogProductEntityDatetime, attribute: :entity_id },
      { key: :decimals, class_name: :CatalogProductEntityDecimal, attribute: :entity_id },
      { key: :ints, class_name: :CatalogProductEntityInt, attribute: :entity_id },
      { key: :texts, class_name: :CatalogProductEntityText, attribute: :entity_id },
      { key: :varchars, class_name: :CatalogProductEntityVarchar, attribute: :entity_id },
    ],
  }

  entities.each do |entity, relations|
    get_model_file_contents! do |file, text|
      next unless File.basename(file, ".*") == entity.to_s
      text_lines = text.lines
      index_of_wanted_line = text_lines.index { |line| line.include? 'end' }
      next if index_of_wanted_line.nil?

      lines_to_insert = relations.map do |relation|
        "  has_many :#{relation[:key]}, class_name: \"#{relation[:class_name]}\", foreign_key: :#{relation[:attribute]}\n"
      end

      text_lines.insert(index_of_wanted_line - 1, *lines_to_insert)

      File.open(file, 'w') { |f| f.puts text_lines.join }
    end
  end
end

# set_model_tables!
# fix_attribute_references!
# fix_entity_references!
add_entity_references!
