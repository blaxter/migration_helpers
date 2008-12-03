require 'migration_helper'

%w( MySql Jdbc ).each do |driver|
  adapter = "#{driver}Adapter"
  if ActiveRecord::ConnectionAdapters.const_defined? adapter then
    ActiveRecord::ConnectionAdapters.const_get(adapter).send :include, MysqlMigrationHelpers
  end
end