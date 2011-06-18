require 'test/unit'
require 'rubygems'
require 'active_record'
require 'sortifiable'
require 'support/migration'

if RUBY_VERSION < '1.9'
  $KCODE = 'UTF8'
end

driver = (ENV['DB'] or 'sqlite3').downcase
config = File.expand_path("../support/#{driver}.yml", __FILE__)
ActiveRecord::Base.establish_connection(YAML::load(File.open(config)))

ActiveRecord::Base.connection.tables.each do |table|
  ActiveRecord::Base.connection.drop_table(table)
end

ActiveRecord::Migration.verbose = false
CreateModels.up
require 'support/models'
CreateModels.down

class ActiveSupport::TestCase
  setup :setup_db
  teardown :teardown_db

  def setup_db
    CreateModels.up
  end

  def teardown_db
    CreateModels.down
  end
end
