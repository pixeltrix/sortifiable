require 'rake/testtask'
require 'rdoc/task'
require "bundler/gem_tasks"

desc 'Default: run sortifiable unit tests.'
task :default => :test

desc 'Test the sortifiable gem.'
Rake::TestTask.new(:test) do |t|
  t.libs += %w[lib test]
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

desc 'Generate documentation for the sortifiable gem.'
RDoc::Task.new do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'Sortifiable'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('lib/**/*.rb')
end

namespace :test do
  desc 'Test using the mysql connection adapter'
  task :mysql do
    sh 'rake test DB=mysql'
  end

  desc 'Test using the mysql2 connection adapter'
  task :mysql2 do
    sh 'rake test DB=mysql2'
  end

  desc 'Test using the postgresql connection adapter'
  task :postgresql do
    sh 'rake test DB=postgresql'
  end

  desc 'Test using the sqlite3 connection adapter'
  task :sqlite3 do
    sh 'rake test DB=sqlite3'
  end

  desc 'Test all connection adapters'
  task :all do
    sh 'rake test DB=mysql'
    sh 'rake test DB=mysql2'
    sh 'rake test DB=postgresql'
    sh 'rake test DB=sqlite3'
  end
end
