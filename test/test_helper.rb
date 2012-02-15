require 'test/unit'
require 'rubygems'
require 'logger'
require 'active_record'
require 'sortifiable'
require 'support/migration'

if RUBY_VERSION < '1.9'
  $KCODE = 'UTF8'
end

ActiveRecord::Base.logger = Logger.new($stdout) if ENV["LOG"]

driver = (ENV['DB'] or 'sqlite3').downcase
config = YAML::load(File.open(File.expand_path("../support/#{driver}.yml", __FILE__)))
ActiveRecord::Base.establish_connection(config)
ActiveRecord::Base.configurations = { 'test' => config }

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

  include ActiveRecord::TestFixtures
  self.fixture_path = File.expand_path('../fixtures', __FILE__)
  self.use_transactional_fixtures = false

  def setup_db
    CreateModels.up
  end

  def teardown_db
    CreateModels.down
  end
end
