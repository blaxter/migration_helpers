require 'migration_helper'
require 'unsigned_int'

ActiveRecord::ConnectionAdapters::AbstractAdapter.
  send :include, MigrationConstraintHelpers
