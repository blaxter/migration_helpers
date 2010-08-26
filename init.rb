LIB_PATH = File.join(
    File.expand_path( File.dirname __FILE__ ), 'lib'
  )

require File.join( LIB_PATH, 'migration_helper' )

ActiveRecord::Migration.extend MigrationConstraintHelpers
