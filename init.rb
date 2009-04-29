require File.join( 
    File.expand_path(File.dirname(__FILE__)), 'lib', 'migration_helper'
  )
require File.join(
    File.expand_path(File.dirname(__FILE__)), 'lib', 'unsigned_int'
  )

ActiveRecord::ConnectionAdapters::AbstractAdapter.
  send :include, MigrationConstraintHelpers
