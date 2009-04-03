require 'migration_helper'

ActiveRecord::ConnectionAdapters.constants.grep( /Adapter$/ ).
each do |adapter|
  if ActiveRecord::ConnectionAdapters.const_defined? adapter
    ActiveRecord::ConnectionAdapters.const_get( adapter ).
      send :include, MigrationConstraintHelpers
  end
end
