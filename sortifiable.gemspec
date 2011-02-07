# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "sortifiable/version"

Gem::Specification.new do |s|
  s.name        = "sortifiable"
  s.version     = Sortifiable::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Andrew White"]
  s.email       = ["andyw@pixeltrix.co.uk"]
  s.homepage    = %q{http://github.com/pixeltrix/sortifiable/}
  s.summary     = %q{Sort your models}
  s.description = <<-EOF
This gem provides an acts_as_list compatible capability for sorting
and reordering a number of objects in a list. The class that has this
specified needs to have a +position+ column defined as an integer on
the mapped database table.

This gem requires ActiveRecord 3.0 as it has been refactored to use
the scope methods and query interface introduced with Ruby on Rails 3.0
EOF

  s.files = [
    ".gemtest",
    "CHANGELOG",
    "LICENSE",
    "README",
    "Rakefile",
    "lib/sortifiable.rb",
    "lib/sortifiable/version.rb",
    "sortifiable.gemspec",
    "test/sortifiable_test.rb"
  ]

  s.test_files    = ["test/sortifiable_test.rb"]
  s.require_paths = ["lib"]

  s.add_dependency "activesupport", "~> 3.0.3"
  s.add_dependency "activerecord", "~> 3.0.3"
  s.add_development_dependency "bundler", "~> 1.0.10"
  s.add_development_dependency "sqlite3", "~> 1.3.3"
end
