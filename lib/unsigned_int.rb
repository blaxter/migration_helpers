require 'active_record/connection_adapters/mysql_adapter.rb'

module ActiveRecord
  module ConnectionAdapters
    class MysqlAdapter
      def native_database_types_with_unsigned_primary_key
        returning native_database_types_without_unsigned_primary_key do |types|
          types[:primary_key] = 'int(10) UNSIGNED DEFAULT NULL auto_increment PRIMARY KEY'
        end
      end
      # This is cool, but backward compatibility is a big deal
      # you should uncomment this only for new databases
      #alias_method_chain :native_database_types, :unsigned_primary_key
    end
  end
end

module ActiveRecord
  module ConnectionAdapters

    class MysqlAdapter
      def type_to_sql_with_unsigned(type, limit = nil, precision = nil, scale = nil, unsigned = false)
        returning type_to_sql_without_unsigned(type, limit, precision, scale) do |sql|
          sql << ' UNSIGNED' if unsigned && type.to_s == 'integer'
        end
      end
      alias_method_chain :type_to_sql, :unsigned

      def add_column(table_name, column_name, type, options = {})
        add_column_sql = "ALTER TABLE #{quote_table_name(table_name)} ADD #{quote_column_name(column_name)} #{type_to_sql(type, options[:limit], options[:precision], options[:scale], options[:unsigned])}"
        add_column_options!(add_column_sql, options)
        execute(add_column_sql)
      end

      def change_column(table_name, column_name, type, options = {})
        unless options_include_default?(options)
          if column = columns(table_name).find { |c| c.name == column_name.to_s }
            options[:default] = column.default
          else
            raise "No such column: #{table_name}.#{column_name}"
          end
        end

        change_column_sql = "ALTER TABLE #{quote_table_name(table_name)} CHANGE #{quote_column_name(column_name)} #{quote_column_name(column_name)} #{type_to_sql(type, options[:limit], options[:precision], options[:scale], options[:unsigned])}"
        add_column_options!(change_column_sql, options)
        execute(change_column_sql)
      end
    end

    class Column
      attr_reader :unsigned

      def initialize_with_unsigned(name, default, sql_type = nil, null = true)
        initialize_without_unsigned(name, default, sql_type, null)
        @unsigned = extract_unsigned(sql_type)
      end
      alias_method_chain :initialize, :unsigned

      def extract_unsigned(sql_type)
        false
      end
    end

    class MysqlColumn
      def extract_unsigned(sql_type)
        sql_type =~ /unsigned/ ? true : false
      end
    end

    class ColumnDefinition
      attr_accessor :unsigned

      def sql_type
        base.type_to_sql(type.to_sym, limit, precision, scale, unsigned)
      rescue
        ( unsigned && type.to_s == 'integer' ) ? "#{type} UNSIGNED" : type
      end
    end

    class Table
      def integer(*args)
        options = args.extract_options!
        column_names = args

        column_names.each do |name|
          column = ColumnDefinition.new(@base, name, 'integer')
          if options[:limit]
            column.limit = options[:limit]
          elsif native[:integer].is_a?(Hash)
            column.limit = native[:integer][:limit]
          end
          column.precision = options[:precision]
          column.scale = options[:scale]
          column.default = options[:default]
          column.null = options[:null]
          column.unsigned = options[:unsigned]
          @base.add_column(@table_name, name, column.sql_type, options)
        end
      end
    end

    class TableDefinition
      def column_with_unsigned(name, type, options = {})
         column_without_unsigned(name, type, options)[name].unsigned = options[:unsigned]
      end
      alias_method_chain :column, :unsigned
    end

  end
end

module ActiveRecord
  class SchemaDumper
    def table(table, stream)
      columns = @connection.columns(table)
      begin
        tbl = StringIO.new

        if @connection.respond_to?(:pk_and_sequence_for)
          pk, pk_seq = @connection.pk_and_sequence_for(table)
        end
        pk ||= 'id'

        tbl.print "  create_table #{table.inspect}"
        if columns.detect { |c| c.name == pk }
          if pk != 'id'
            tbl.print %Q(, :primary_key => "#{pk}")
          end
        else
          tbl.print ", :id => false"
        end
        tbl.print ", :force => true"
        tbl.puts " do |t|"

        column_specs = columns.map do |column|
          raise StandardError, "Unknown type '#{column.sql_type}' for column '#{column.name}'" if @types[column.type].nil?
          next if column.name == pk
          spec = {}
          spec[:name]      = column.name.inspect
          spec[:type]      = column.type.to_s
          spec[:limit]     = column.limit.inspect if column.limit != @types[column.type][:limit] && column.type != :decimal
          spec[:precision] = column.precision.inspect if !column.precision.nil?
          spec[:scale]     = column.scale.inspect if !column.scale.nil?
          spec[:null]      = 'false' if !column.null
          spec[:default]   = default_string(column.default) if !column.default.nil?
          spec[:unsigned]  = 'true' if column.unsigned == true
          (spec.keys - [:name, :type]).each{ |k| spec[k].insert(0, "#{k.inspect} => ")}
          spec
        end.compact

        # find all migration keys used in this table
        keys = [:name, :limit, :precision, :scale, :default, :null, :unsigned] & column_specs.map(&:keys).flatten

        # figure out the lengths for each column based on above keys
        lengths = keys.map{ |key| column_specs.map{ |spec| spec[key] ? spec[key].length + 2 : 0 }.max }

        # the string we're going to sprintf our values against, with standardized column widths
        format_string = lengths.map{ |len| "%-#{len}s" }

        # find the max length for the 'type' column, which is special
        type_length = column_specs.map{ |column| column[:type].length }.max

        # add column type definition to our format string
        format_string.unshift "    t.%-#{type_length}s "

        format_string *= ''

        column_specs.each do |colspec|
          values = keys.zip(lengths).map{ |key, len| colspec.key?(key) ? colspec[key] + ", " : " " * len }
          values.unshift colspec[:type]
          tbl.print((format_string % values).gsub(/,\s*$/, ''))
          tbl.puts
        end

        tbl.puts "  end"
        tbl.puts

        indexes(table, tbl)

        tbl.rewind
        stream.print tbl.read
      rescue => e
        stream.puts "# Could not dump table #{table.inspect} because of following #{e.class}"
        stream.puts "#   #{e.message}"
        stream.puts
      end

      stream
    end
  end
end
