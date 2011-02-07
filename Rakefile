require 'rake'
require 'rake/rdoctask'
require 'rake/testtask'
require 'bundler'

Bundler::GemHelper.install_tasks

desc 'Default: run sortifiable unit tests.'
task :default => :test

desc 'Test the sortifiable gem.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

desc 'Generate documentation for the sortifiable gem.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'Sortifiable'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
