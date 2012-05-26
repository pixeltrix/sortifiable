Sortifiable
===========

[![Build Status][build]][travis] [![Dependency Status][depends]][gemnasium]

This gem provides an acts_as_list compatible capability for sorting
and reordering a number of objects in a list. The class that has this
specified needs to have a +position+ column defined as an integer on
the mapped database table.

This gem requires ActiveRecord 3.0 as it has been refactored to use
the scope methods and query interface introduced with Ruby on Rails 3.0

Example
-------

``` ruby
class TodoList < ActiveRecord::Base
  has_many :todo_items, :order => "position"
end

class TodoItem < ActiveRecord::Base
  belongs_to :todo_list
  acts_as_list :scope => :todo_list
end

todo_list.first.move_to_bottom
todo_list.last.move_higher
```

Contributions
-------------

Bug fixes and new feature patches are welcome. Please provide tests and
documentation wherever possible - without them it is unlikely your patch
will be accepted. If you're fixing a bug then a failing test for the bug
is essential. Once you have completed your patch please open a GitHub
pull request and I will review it and respond as quickly as possible.

Thanks to the following people for their contributions:

* Manuel Meurer
* Reinier de Lange

Copyright (c) 2011 Andrew White, released under the MIT license

[build]: https://secure.travis-ci.org/pixeltrix/sortifiable.png
[travis]: http://travis-ci.org/pixeltrix/sortifiable
[depends]: https://gemnasium.com/pixeltrix/sortifiable.png?travis
[gemnasium]: https://gemnasium.com/pixeltrix/sortifiable
