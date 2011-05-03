require 'test/unit'
require 'rubygems'
require 'active_record'
require 'active_support/core_ext/kernel/reporting'
require 'sortifiable'

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")

def setup_db
  silence_stream(STDOUT) do
    ActiveRecord::Schema.define(:version => 1) do
      create_table :mixins do |t|
        t.column :type, :string
        t.column :pos, :integer
        t.column :parent_id, :integer
        t.column :parent_type, :string
        t.column :created_at, :datetime
        t.column :updated_at, :datetime
      end
    end
  end
end

def teardown_db
  ActiveRecord::Base.connection.tables.each do |table|
    ActiveRecord::Base.connection.drop_table(table)
  end
end

setup_db

class Mixin < ActiveRecord::Base
end

class ListMixin < ActiveRecord::Base
  acts_as_list :column => "pos", :scope => :parent
  set_table_name "mixins"
  default_scope order(:pos)
end

class ListMixinSub1 < ListMixin
end

class ListMixinSub2 < ListMixin
end

class ListWithStringScopeMixin < ActiveRecord::Base
  acts_as_list :column => "pos", :scope => 'parent_id = #{parent_id}'
  set_table_name "mixins"
  default_scope order(:pos)
end

class ArrayScopeListMixin < ActiveRecord::Base
  acts_as_list :column => "pos", :scope => [:parent_id, :parent_type]
  set_table_name "mixins"
  default_scope order(:pos)
end

class AssociationScopeListMixin < ActiveRecord::Base
  belongs_to :parent
  acts_as_list :column => "pos", :scope => :parent
  set_table_name "mixins"
  default_scope order(:pos)
end

class PolymorphicAssociationScopeListMixin < ActiveRecord::Base
  belongs_to :parent, :polymorphic => true
  acts_as_list :column => "pos", :scope => :parent
  set_table_name "mixins"
  default_scope order(:pos)
end

teardown_db

class NonListTest < Test::Unit::TestCase

  def setup
    setup_db
  end

  def teardown
    teardown_db
  end

  def test_callbacks_are_not_added_to_all_models
    Mixin.create! :pos => 1, :parent_id => 5
    assert_equal 1, Mixin.first.id

    Mixin.find(1).destroy
    assert_equal [], Mixin.all
  end

  def test_instance_methods_are_not_included_in_all_models
    Mixin.create! :pos => 1, :parent_id => 5
    assert_equal false, Mixin.first.respond_to?(:in_list?)
  end

end

class ListTest < Test::Unit::TestCase

  def setup
    setup_db
    [5, 6].each do |parent_id|
      (1..4).each do |i|
        ListMixin.create! :pos => i, :parent_id => parent_id
      end
    end
  end

  def teardown
    teardown_db
  end

  def test_reordering
    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5).map(&:id)

    ListMixin.find(2).move_lower
    assert_equal [1, 3, 2, 4], ListMixin.where(:parent_id => 5).map(&:id)

    ListMixin.find(2).move_higher
    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5).map(&:id)

    ListMixin.find(1).move_to_bottom
    assert_equal [2, 3, 4, 1], ListMixin.where(:parent_id => 5).map(&:id)

    ListMixin.find(1).move_to_top
    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5).map(&:id)

    ListMixin.find(2).move_to_bottom
    assert_equal [1, 3, 4, 2], ListMixin.where(:parent_id => 5).map(&:id)

    ListMixin.find(4).move_to_top
    assert_equal [4, 1, 3, 2], ListMixin.where(:parent_id => 5).map(&:id)
  end

  def test_bounds_checking
    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5).map(&:pos)

    ListMixin.find(1).move_higher
    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5).map(&:pos)

    ListMixin.find(4).move_lower
    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5).map(&:pos)
  end

  def test_move_to_bottom_with_next_to_last_item
    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5).map(&:id)

    ListMixin.find(3).move_to_bottom
    assert_equal [1, 2, 4, 3], ListMixin.where(:parent_id => 5).map(&:id)
  end

  def test_next_prev
    assert_equal ListMixin.find(2), ListMixin.find(1).lower_item
    assert_nil ListMixin.find(1).higher_item
    assert_equal ListMixin.find(3), ListMixin.find(4).higher_item
    assert_nil ListMixin.find(4).lower_item
  end

  def test_injection
    item = ListMixin.new(:parent_id => 1)
    assert_equal({ :parent_id => 1 }, item.send(:scope_condition))
    assert_equal("pos", item.send(:position_column))
  end

  def test_insert
    new = ListMixin.create(:parent_id => 20)
    assert_equal 1, new.pos
    assert new.first?
    assert new.last?

    new = ListMixin.create(:parent_id => 20)
    assert_equal 2, new.pos
    assert !new.first?
    assert new.last?

    new = ListMixin.create(:parent_id => 20)
    assert_equal 3, new.pos
    assert !new.first?
    assert new.last?

    new = ListMixin.create(:parent_id => 0)
    assert_equal 1, new.pos
    assert new.first?
    assert new.last?
  end

  def test_insert_at
    new = ListMixin.create(:parent_id => 20)
    assert_equal 1, new.pos

    new = ListMixin.create(:parent_id => 20)
    assert_equal 2, new.pos

    new = ListMixin.create(:parent_id => 20)
    assert_equal 3, new.pos

    new4 = ListMixin.create(:parent_id => 20)
    assert_equal 4, new4.pos

    new4.insert_at(3)
    assert_equal 3, new4.pos

    new.reload
    assert_equal 4, new.pos

    new.insert_at(2)
    assert_equal 2, new.pos

    new4.reload
    assert_equal 4, new4.pos

    new5 = ListMixin.create(:parent_id => 20)
    assert_equal 5, new5.pos

    new5.insert_at(1)
    assert_equal 1, new5.pos

    new4.reload
    assert_equal 5, new4.pos
  end

  def test_delete_middle
    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5).map(&:id)

    ListMixin.find(2).destroy

    assert_equal [1, 3, 4], ListMixin.where(:parent_id => 5).map(&:id)

    assert_equal 1, ListMixin.find(1).pos
    assert_equal 2, ListMixin.find(3).pos
    assert_equal 3, ListMixin.find(4).pos

    ListMixin.find(1).destroy

    assert_equal [3, 4], ListMixin.where(:parent_id => 5).map(&:id)

    assert_equal 1, ListMixin.find(3).pos
    assert_equal 2, ListMixin.find(4).pos
  end

  def test_nil_scope
    new1, new2, new3 = ListMixin.create, ListMixin.create, ListMixin.create
    new2.move_higher
    assert_equal [new2, new1, new3], ListMixin.where(:parent_id => nil)
  end

  def test_remove_from_list_should_then_fail_in_list?
    assert_equal true, ListMixin.find(1).in_list?
    ListMixin.find(1).remove_from_list
    assert_equal false, ListMixin.find(1).in_list?
  end

  def test_remove_from_list_should_set_position_to_nil
    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5).map(&:id)

    ListMixin.find(2).remove_from_list

    assert_equal [2, 1, 3, 4], ListMixin.where(:parent_id => 5).map(&:id)

    assert_equal 1,   ListMixin.find(1).pos
    assert_equal nil, ListMixin.find(2).pos
    assert_equal 2,   ListMixin.find(3).pos
    assert_equal 3,   ListMixin.find(4).pos
  end

  def test_remove_before_destroy_does_not_shift_lower_items_twice
    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5).map(&:id)

    ListMixin.find(2).remove_from_list
    ListMixin.find(2).destroy

    assert_equal [1, 3, 4], ListMixin.where(:parent_id => 5).map(&:id)

    assert_equal 1, ListMixin.find(1).pos
    assert_equal 2, ListMixin.find(3).pos
    assert_equal 3, ListMixin.find(4).pos
  end

  def test_remove_from_list_by_updating_should_shift_lower_items
    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5).map(&:id)

    ListMixin.find(2).update_attributes! :parent_id => 6

    assert_equal [1, 3, 4], ListMixin.where(:parent_id => 5).map(&:id)

    assert_equal 1, ListMixin.find(1).pos
    assert_equal 2, ListMixin.find(3).pos
    assert_equal 3, ListMixin.find(4).pos
  end

  def test_move_to_new_list_by_updating_should_append
    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5).map(&:id)
    assert_equal [5, 6, 7, 8], ListMixin.where(:parent_id => 6).map(&:id)

    ListMixin.find(2).update_attributes! :parent_id => 6

    assert_equal [5, 6, 7, 8, 2], ListMixin.where(:parent_id => 6).map(&:id)

    assert_equal 1, ListMixin.find(5).pos
    assert_equal 2, ListMixin.find(6).pos
    assert_equal 3, ListMixin.find(7).pos
    assert_equal 4, ListMixin.find(8).pos
    assert_equal 5, ListMixin.find(2).pos
  end

  def test_before_destroy_callbacks_do_not_update_position_to_nil_before_deleting_the_record
    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5).map(&:id)

    # We need to trigger all the before_destroy callbacks without actually
    # destroying the record so we can see the affect the callbacks have on
    # the record.
    list = ListMixin.find(2)
    if list.respond_to?(:run_callbacks)
      list.run_callbacks(:destroy)
    else
      list.send(:callback, :before_destroy)
    end

    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5).map(&:id)

    assert_equal 1, ListMixin.find(1).pos
    assert_equal 2, ListMixin.find(2).pos
    assert_equal 2, ListMixin.find(3).pos
    assert_equal 3, ListMixin.find(4).pos
  end

  def test_higher_items
    assert_equal [1, 2], ListMixin.find(3).higher_items.map(&:id)
    assert_equal     [], ListMixin.find(1).higher_items.map(&:id)
  end

  def test_lower_items
    assert_equal [3, 4], ListMixin.find(2).lower_items.map(&:id)
    assert_equal     [], ListMixin.find(4).lower_items.map(&:id)
  end

  def test_moving_first_and_last_items_return_true
    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5).map(&:id)
    assert_equal true, ListMixin.find(1).move_to_top
    assert_equal true, ListMixin.find(1).move_higher
    assert_equal true, ListMixin.find(4).move_to_bottom
    assert_equal true, ListMixin.find(4).move_lower
  end

  def test_add_to_list_should_return_true
    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5).map(&:id)

    item = ListMixin.new(:parent_id => 5)
    assert_equal true, item.new_record?
    assert_equal false, item.in_list?
    assert_equal true, item.add_to_list

    item = ListMixin.create(:parent_id => 5)
    item.remove_from_list
    assert_equal false, item.new_record?
    assert_equal false, item.in_list?
    assert_equal true, item.add_to_list
  end

  def test_decrement_callbacks_should_return_true
    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5).map(&:id)

    item = ListMixin.find(4)
    assert_equal 4, item.pos
    assert_equal true, item.send(:decrement_position_on_lower_items)

    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5).map(&:id)

    item = ListMixin.find(4)
    item.parent_id = 6

    assert_equal 4, item.pos
    assert_equal true, item.will_leave_list?
    assert_equal true, item.send(:decrement_position_on_lower_items_in_old_list)
  end

end

class ListWithStringScopeTest < Test::Unit::TestCase

  def setup
    setup_db
    [5, 6].each do |parent_id|
      (1..4).each do |i|
        ListWithStringScopeMixin.create! :parent_id => parent_id
      end
    end
  end

  def teardown
    teardown_db
  end

  def test_insert
    new = ListWithStringScopeMixin.create(:parent_id => 500)
    assert_equal 1, new.pos
    assert new.first?
    assert new.last?

    new = ListWithStringScopeMixin.create(:parent_id => 500)
    assert_equal 2, new.pos
    assert !new.first?
    assert new.last?

    new = ListWithStringScopeMixin.create(:parent_id => 500)
    assert_equal 3, new.pos
    assert !new.first?
    assert new.last?

    new = ListWithStringScopeMixin.create(:parent_id => 0)
    assert_equal 1, new.pos
    assert new.first?
    assert new.last?
  end

  def test_remove_from_list_by_updating_should_shift_lower_items
    assert_equal [1, 2, 3, 4], ListWithStringScopeMixin.where(:parent_id => 5).map(&:id)

    ListWithStringScopeMixin.find(2).update_attributes! :parent_id => 6

    assert_equal [1, 3, 4], ListWithStringScopeMixin.where(:parent_id => 5).map(&:id)

    assert_equal 1, ListWithStringScopeMixin.find(1).pos
    assert_equal 2, ListWithStringScopeMixin.find(3).pos
    assert_equal 3, ListWithStringScopeMixin.find(4).pos
  end

  def test_move_to_new_list_by_updating_should_append
    assert_equal [1, 2, 3, 4], ListWithStringScopeMixin.where(:parent_id => 5).map(&:id)
    assert_equal [5, 6, 7, 8], ListWithStringScopeMixin.where(:parent_id => 6).map(&:id)

    ListWithStringScopeMixin.find(2).update_attributes! :parent_id => 6

    assert_equal [5, 6, 7, 8, 2], ListWithStringScopeMixin.where(:parent_id => 6).map(&:id)

    assert_equal 1, ListWithStringScopeMixin.find(5).pos
    assert_equal 2, ListWithStringScopeMixin.find(6).pos
    assert_equal 3, ListWithStringScopeMixin.find(7).pos
    assert_equal 4, ListWithStringScopeMixin.find(8).pos
    assert_equal 5, ListWithStringScopeMixin.find(2).pos
  end

end

class ListSubTest < Test::Unit::TestCase

  def setup
    setup_db
    (1..4).each do |i|
      klass = ((i % 2 == 1) ? ListMixinSub1 : ListMixinSub2)
      klass.create! :pos => i, :parent_id => 5000
    end
  end

  def teardown
    teardown_db
  end

  def test_sti_class
    assert_instance_of ListMixinSub1, ListMixin.find(1)
    assert_instance_of ListMixinSub2, ListMixin.find(2)
    assert_instance_of ListMixinSub1, ListMixin.find(3)
    assert_instance_of ListMixinSub2, ListMixin.find(4)
  end

  def test_reordering
    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5000).map(&:id)

    ListMixin.find(2).move_lower
    assert_equal [1, 3, 2, 4], ListMixin.where(:parent_id => 5000).map(&:id)

    ListMixin.find(2).move_higher
    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5000).map(&:id)

    ListMixin.find(1).move_to_bottom
    assert_equal [2, 3, 4, 1], ListMixin.where(:parent_id => 5000).map(&:id)

    ListMixin.find(1).move_to_top
    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5000).map(&:id)

    ListMixin.find(2).move_to_bottom
    assert_equal [1, 3, 4, 2], ListMixin.where(:parent_id => 5000).map(&:id)

    ListMixin.find(4).move_to_top
    assert_equal [4, 1, 3, 2], ListMixin.where(:parent_id => 5000).map(&:id)
  end

  def test_bounds_checking
    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5000).map(&:pos)

    ListMixin.find(1).move_higher
    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5000).map(&:pos)

    ListMixin.find(4).move_lower
    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5000).map(&:pos)
  end

  def test_move_to_bottom_with_next_to_last_item
    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5000).map(&:id)
    ListMixin.find(3).move_to_bottom
    assert_equal [1, 2, 4, 3], ListMixin.where(:parent_id => 5000).map(&:id)
  end

  def test_next_prev
    assert_equal ListMixin.find(2), ListMixin.find(1).lower_item
    assert_nil ListMixin.find(1).higher_item
    assert_equal ListMixin.find(3), ListMixin.find(4).higher_item
    assert_nil ListMixin.find(4).lower_item
  end

  def test_injection
    item = ListMixin.new(:parent_id => 1)
    assert_equal({ :parent_id => 1 }, item.send(:scope_condition))
    assert_equal("pos", item.send(:position_column))
  end

  def test_insert_at
    new = ListMixin.create(:parent_id => 20)
    assert_equal 1, new.pos

    new = ListMixinSub1.create(:parent_id => 20)
    assert_equal 2, new.pos

    new = ListMixinSub2.create(:parent_id => 20)
    assert_equal 3, new.pos

    new4 = ListMixin.create(:parent_id => 20)
    assert_equal 4, new4.pos

    new4.insert_at(3)
    assert_equal 3, new4.pos

    new.reload
    assert_equal 4, new.pos

    new.insert_at(2)
    assert_equal 2, new.pos

    new4.reload
    assert_equal 4, new4.pos

    new5 = ListMixinSub1.create(:parent_id => 20)
    assert_equal 5, new5.pos

    new5.insert_at(1)
    assert_equal 1, new5.pos

    new4.reload
    assert_equal 5, new4.pos
  end

  def test_delete_middle
    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5000).map(&:id)

    ListMixin.find(2).destroy

    assert_equal [1, 3, 4], ListMixin.where(:parent_id => 5000).map(&:id)

    assert_equal 1, ListMixin.find(1).pos
    assert_equal 2, ListMixin.find(3).pos
    assert_equal 3, ListMixin.find(4).pos

    ListMixin.find(1).destroy

    assert_equal [3, 4], ListMixin.where(:parent_id => 5000).map(&:id)

    assert_equal 1, ListMixin.find(3).pos
    assert_equal 2, ListMixin.find(4).pos
  end

  def test_higher_items
    ListMixin.find(2).remove_from_list
    assert_equal [1], ListMixin.find(3).higher_items.map(&:id)
    assert_equal  [], ListMixin.find(1).higher_items.map(&:id)
  end

  def test_lower_items
    ListMixin.find(3).remove_from_list
    assert_equal [4], ListMixin.find(2).lower_items.map(&:id)
    assert_equal  [], ListMixin.find(4).lower_items.map(&:id)
  end

  def test_list_class
    assert_equal [1, 2, 3, 4], ListMixin.all.map(&:pos)
  end

end

class ArrayScopeListTest < Test::Unit::TestCase

  def setup
    setup_db
    ['ParentClass', 'bananas'].each do |parent_type|
      [5, 6].each do |parent_id|
        (1..4).each do |i|
          ArrayScopeListMixin.create!(
            :pos => i,
            :parent_id => parent_id,
            :parent_type => parent_type
          )
        end
      end
    end
  end

  def teardown
    teardown_db
  end

  def conditions(options = {})
    { :parent_id => 5, :parent_type => 'ParentClass' }.merge(options)
  end

  def test_reordering
    assert_equal [1, 2, 3, 4], ArrayScopeListMixin.where(conditions).map(&:id)

    ArrayScopeListMixin.find(2).move_lower
    assert_equal [1, 3, 2, 4], ArrayScopeListMixin.where(conditions).map(&:id)

    ArrayScopeListMixin.find(2).move_higher
    assert_equal [1, 2, 3, 4], ArrayScopeListMixin.where(conditions).map(&:id)

    ArrayScopeListMixin.find(1).move_to_bottom
    assert_equal [2, 3, 4, 1], ArrayScopeListMixin.where(conditions).map(&:id)

    ArrayScopeListMixin.find(1).move_to_top
    assert_equal [1, 2, 3, 4], ArrayScopeListMixin.where(conditions).map(&:id)

    ArrayScopeListMixin.find(2).move_to_bottom
    assert_equal [1, 3, 4, 2], ArrayScopeListMixin.where(conditions).map(&:id)

    ArrayScopeListMixin.find(4).move_to_top
    assert_equal [4, 1, 3, 2], ArrayScopeListMixin.where(conditions).map(&:id)
  end

  def test_bounds_checking
    assert_equal [1, 2, 3, 4], ArrayScopeListMixin.where(conditions).map(&:pos)

    ArrayScopeListMixin.find(1).move_higher
    assert_equal [1, 2, 3, 4], ArrayScopeListMixin.where(conditions).map(&:pos)

    ArrayScopeListMixin.find(4).move_lower
    assert_equal [1, 2, 3, 4], ArrayScopeListMixin.where(conditions).map(&:pos)
  end

  def test_move_to_bottom_with_next_to_last_item
    assert_equal [1, 2, 3, 4], ArrayScopeListMixin.where(conditions).map(&:id)
    ArrayScopeListMixin.find(3).move_to_bottom
    assert_equal [1, 2, 4, 3], ArrayScopeListMixin.where(conditions).map(&:id)
  end

  def test_next_prev
    assert_equal ArrayScopeListMixin.find(2), ArrayScopeListMixin.find(1).lower_item
    assert_nil ArrayScopeListMixin.find(1).higher_item
    assert_equal ArrayScopeListMixin.find(3), ArrayScopeListMixin.find(4).higher_item
    assert_nil ArrayScopeListMixin.find(4).lower_item
  end

  def test_injection
    item = ArrayScopeListMixin.new(conditions)
    assert_equal conditions, item.send(:scope_condition)
    assert_equal "pos", item.send(:position_column)
  end

  def test_insert
    new = ArrayScopeListMixin.create(conditions(:parent_id => 20))
    assert_equal 1, new.pos
    assert new.first?
    assert new.last?

    new = ArrayScopeListMixin.create(conditions(:parent_id => 20))
    assert_equal 2, new.pos
    assert !new.first?
    assert new.last?

    new = ArrayScopeListMixin.create(conditions(:parent_id => 20))
    assert_equal 3, new.pos
    assert !new.first?
    assert new.last?

    new = ArrayScopeListMixin.create(conditions(:parent_id => 0))
    assert_equal 1, new.pos
    assert new.first?
    assert new.last?
  end

  def test_insert_at
    new = ArrayScopeListMixin.create(conditions(:parent_id => 20))
    assert_equal 1, new.pos

    new = ArrayScopeListMixin.create(conditions(:parent_id => 20))
    assert_equal 2, new.pos

    new = ArrayScopeListMixin.create(conditions(:parent_id => 20))
    assert_equal 3, new.pos

    new4 = ArrayScopeListMixin.create(conditions(:parent_id => 20))
    assert_equal 4, new4.pos

    new4.insert_at(3)
    assert_equal 3, new4.pos

    new.reload
    assert_equal 4, new.pos

    new.insert_at(2)
    assert_equal 2, new.pos

    new4.reload
    assert_equal 4, new4.pos

    new5 = ArrayScopeListMixin.create(conditions(:parent_id => 20))
    assert_equal 5, new5.pos

    new5.insert_at(1)
    assert_equal 1, new5.pos

    new4.reload
    assert_equal 5, new4.pos
  end

  def test_delete_middle
    assert_equal [1, 2, 3, 4], ArrayScopeListMixin.where(conditions).map(&:id)

    ArrayScopeListMixin.find(2).destroy

    assert_equal [1, 3, 4], ArrayScopeListMixin.where(conditions).map(&:id)

    assert_equal 1, ArrayScopeListMixin.find(1).pos
    assert_equal 2, ArrayScopeListMixin.find(3).pos
    assert_equal 3, ArrayScopeListMixin.find(4).pos

    ArrayScopeListMixin.find(1).destroy

    assert_equal [3, 4], ArrayScopeListMixin.where(conditions).map(&:id)

    assert_equal 1, ArrayScopeListMixin.find(3).pos
    assert_equal 2, ArrayScopeListMixin.find(4).pos
  end

  def test_remove_from_list_by_updating_scope_part_1_should_shift_lower_items
    assert_equal [1, 2, 3, 4], ArrayScopeListMixin.where(conditions).map(&:id)

    ArrayScopeListMixin.find(2).update_attributes! :parent_id => 6

    assert_equal [1, 3, 4], ArrayScopeListMixin.where(conditions).map(&:id)

    assert_equal 1, ArrayScopeListMixin.find(1).pos
    assert_equal 2, ArrayScopeListMixin.find(3).pos
    assert_equal 3, ArrayScopeListMixin.find(4).pos
  end

  def test_remove_from_list_by_updating_scope_part_2_should_shift_lower_items
    assert_equal [1, 2, 3, 4], ArrayScopeListMixin.where(conditions).map(&:id)

    ArrayScopeListMixin.find(2).update_attributes! :parent_type => 'bananas'

    assert_equal [1, 3, 4], ArrayScopeListMixin.where(conditions).map(&:id)

    assert_equal 1, ArrayScopeListMixin.find(1).pos
    assert_equal 2, ArrayScopeListMixin.find(3).pos
    assert_equal 3, ArrayScopeListMixin.find(4).pos
  end

  def test_remove_from_list_by_updating_complete_scope_should_shift_lower_items
    assert_equal [1, 2, 3, 4], ArrayScopeListMixin.where(conditions).map(&:id)

    ArrayScopeListMixin.find(2).update_attributes! :parent_id => 6, :parent_type => 'bananas'

    assert_equal [1, 3, 4], ArrayScopeListMixin.where(conditions).map(&:id)

    assert_equal 1, ArrayScopeListMixin.find(1).pos
    assert_equal 2, ArrayScopeListMixin.find(3).pos
    assert_equal 3, ArrayScopeListMixin.find(4).pos
  end

  def test_move_to_new_list_by_updating_scope_part_1_should_append
    assert_equal [1, 2, 3, 4], ArrayScopeListMixin.where(conditions).map(&:id)
    assert_equal [5, 6, 7, 8], ArrayScopeListMixin.where(conditions(:parent_id => 6)).map(&:id)

    ArrayScopeListMixin.find(2).update_attributes! :parent_id => 6

    assert_equal [5, 6, 7, 8, 2], ArrayScopeListMixin.where(conditions(:parent_id => 6)).map(&:id)

    assert_equal 1, ArrayScopeListMixin.find(5).pos
    assert_equal 2, ArrayScopeListMixin.find(6).pos
    assert_equal 3, ArrayScopeListMixin.find(7).pos
    assert_equal 4, ArrayScopeListMixin.find(8).pos
    assert_equal 5, ArrayScopeListMixin.find(2).pos
  end

  def test_move_to_new_list_by_updating_scope_part_2_should_append
    assert_equal [1,  2,  3,  4], ArrayScopeListMixin.where(conditions).map(&:id)
    assert_equal [9, 10, 11, 12], ArrayScopeListMixin.where(conditions(:parent_type => 'bananas')).map(&:id)

    ArrayScopeListMixin.find(2).update_attributes! :parent_type => 'bananas'

    assert_equal [9, 10, 11, 12, 2], ArrayScopeListMixin.where(conditions(:parent_type => 'bananas')).map(&:id)

    assert_equal 1, ArrayScopeListMixin.find(9).pos
    assert_equal 2, ArrayScopeListMixin.find(10).pos
    assert_equal 3, ArrayScopeListMixin.find(11).pos
    assert_equal 4, ArrayScopeListMixin.find(12).pos
    assert_equal 5, ArrayScopeListMixin.find(2).pos
  end

  def test_move_to_new_list_by_updating_complete_scope_should_append
    assert_equal [ 1,  2,  3,  4], ArrayScopeListMixin.where(conditions).map(&:id)
    assert_equal [13, 14, 15, 16], ArrayScopeListMixin.where(:parent_id => 6, :parent_type => 'bananas').map(&:id)

    ArrayScopeListMixin.find(2).update_attributes! :parent_id => 6, :parent_type => 'bananas'

    assert_equal [13, 14, 15, 16, 2], ArrayScopeListMixin.where(:parent_id => 6, :parent_type => 'bananas').map(&:id)

    assert_equal 1, ArrayScopeListMixin.find(13).pos
    assert_equal 2, ArrayScopeListMixin.find(14).pos
    assert_equal 3, ArrayScopeListMixin.find(15).pos
    assert_equal 4, ArrayScopeListMixin.find(16).pos
    assert_equal 5, ArrayScopeListMixin.find(2).pos
  end

  def test_remove_from_list_should_then_fail_in_list?
    assert_equal true, ArrayScopeListMixin.find(1).in_list?

    ArrayScopeListMixin.find(1).remove_from_list

    assert_equal false, ArrayScopeListMixin.find(1).in_list?
  end

  def test_remove_from_list_should_set_position_to_nil
    assert_equal [1, 2, 3, 4], ArrayScopeListMixin.where(conditions).map(&:id)

    ArrayScopeListMixin.find(2).remove_from_list

    assert_equal [2, 1, 3, 4], ArrayScopeListMixin.where(conditions).map(&:id)

    assert_equal 1,   ArrayScopeListMixin.find(1).pos
    assert_equal nil, ArrayScopeListMixin.find(2).pos
    assert_equal 2,   ArrayScopeListMixin.find(3).pos
    assert_equal 3,   ArrayScopeListMixin.find(4).pos
  end

  def test_remove_before_destroy_does_not_shift_lower_items_twice
    assert_equal [1, 2, 3, 4], ArrayScopeListMixin.where(conditions).map(&:id)

    ArrayScopeListMixin.find(2).remove_from_list
    ArrayScopeListMixin.find(2).destroy

    assert_equal [1, 3, 4], ArrayScopeListMixin.where(conditions).map(&:id)

    assert_equal 1, ArrayScopeListMixin.find(1).pos
    assert_equal 2, ArrayScopeListMixin.find(3).pos
    assert_equal 3, ArrayScopeListMixin.find(4).pos
  end

  def test_higher_items
    assert_equal [1, 2], ArrayScopeListMixin.find(3).higher_items.map(&:id)
    assert_equal     [], ArrayScopeListMixin.find(1).higher_items.map(&:id)
  end

  def test_lower_items
    assert_equal [3, 4], ArrayScopeListMixin.find(2).lower_items.map(&:id)
    assert_equal     [], ArrayScopeListMixin.find(4).lower_items.map(&:id)
  end

end

class AssociationScopeListTest < Test::Unit::TestCase

  def setup
    setup_db
    (1..4).each do |i|
      AssociationScopeListMixin.create!(
        :pos => i,
        :parent_id => 5
      )
    end

    (1..4).each do |i|
      PolymorphicAssociationScopeListMixin.create!(
        :pos => i,
        :parent_id => 5,
        :parent_type => 'ParentClass'
      )
    end
  end

  def teardown
    teardown_db
  end

  def test_association_scope_is_configured
    assert_equal :parent_id,
      AssociationScopeListMixin.acts_as_list_options[:scope]
  end

  def test_polymorphic_association_scope_is_configured
    assert_equal [:parent_id, :parent_type],
      PolymorphicAssociationScopeListMixin.acts_as_list_options[:scope]
  end

end
