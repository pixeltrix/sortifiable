require 'active_support/concern'
require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/hash/reverse_merge'
require 'active_record'
require 'sortifiable/version'

# This +acts_as+ extension provides the capabilities for sorting and
# reordering a number of objects in a list. The class that has this
# specified needs to have a +position+ column defined as an integer on
# the mapped database table.
#
# Todo list example:
#
#   class TodoList < ActiveRecord::Base
#     has_many :todo_items, :order => "position"
#   end
#
#   class TodoItem < ActiveRecord::Base
#     belongs_to :todo_list
#     acts_as_list :scope => :todo_list
#   end
#
#   todo_list.first.move_to_bottom
#   todo_list.last.move_higher
module Sortifiable
  extend ActiveSupport::Concern

  included do
    class_attribute :acts_as_list_options, :instance_writer => false
    self.acts_as_list_options = {}

    before_create :add_to_list_bottom
    before_destroy :decrement_position_on_lower_items, :if => :in_list?
  end

  module ClassMethods
    # Configuration options are:
    #
    # * +column+ - specifies the column name to use for keeping the
    #   position integer (default: +position+)
    # * +scope+ - restricts what is to be considered a list. Given a symbol,
    #   it'll attach <tt>_id</tt> (if it hasn't already been added) and use
    #   that as the foreign key restriction. It's also possible to give it
    #   an entire string that is interpolated if you need a tighter scope
    #   than just a foreign key. Example:
    #
    #     acts_as_list :scope => 'user_id = #{user_id} AND completed = 0'
    #
    #   It can also be given an array of symbols or a belongs_to association.
    def acts_as_list(options = {})
      options.reverse_merge!(:scope => [], :column => :position)

      if options[:scope].is_a?(Symbol) && reflections.key?(options[:scope])
        reflection = reflections[options.delete(:scope)]

        if reflection.belongs_to?
          if reflection.options[:polymorphic]
            options[:scope] = [
              reflection.association_foreign_key.to_sym,
              reflection.options[:foreign_type].to_sym
            ]
          else
            reflection.association_foreign_key.to_sym
          end
        else
          raise ArgumentError, "Only belongs_to associations can be used as a scope"
        end
      elsif options[:scope].is_a?(Symbol) && options[:scope].to_s !~ /_id$/
        options[:scope] = "#{options[:scope]}_id".to_sym
      end

      self.acts_as_list_options = options
    end
  end

  # All the methods available to a record that has had <tt>acts_as_list</tt>
  # specified. Each method works by assuming the object to be the item in the
  # list, so <tt>chapter.move_lower</tt> would move that chapter lower in the
  # list of all chapters. Likewise, <tt>chapter.first?</tt> would return +true+
  # if that chapter is the first in the list of all chapters.

  # Add the item to the end of the list
  def add_to_list
    remove_from_list if in_list?
    update_attribute(position_column, last_position + 1)
  end

  # Returns the current position
  def current_position
    send(position_column).to_i
  end

  # Decrease the position of this item without adjusting the rest of the list.
  def decrement_position
    in_list? && update_attribute(position_column, current_position - 1)
  end

  # Return +true+ if this object is the first in the list.
  def first?
    in_list? && current_position == 1
  end
  alias_method :top?, :first?

  # Returns the first item in the list
  def first_item
    list_scope.first
  end
  alias_method :top_item, :first_item

  # Return the next higher item in the list.
  def higher_item
    item_at_offset(-1)
  end
  alias_method :previous_item, :higher_item

  # Return items lower than this item or an empty array if it is the last item
  def higher_items
    list_scope.where(["#{quoted_position_column} < ?", current_position]).all
  end

  # Test if this record is in a list
  def in_list?
    !new_record? && !send(position_column).nil?
  end

  # Increase the position of this item without adjusting the rest of the list.
  def increment_position
    in_list? && update_attribute(position_column, current_position + 1)
  end

  # Insert the item at the given position (defaults to the top position of 1).
  def insert_at(position = 1)
    if position > 0
      remove_from_list
      if position > last_position
        add_to_list
      else
        increment_position_on_lower_items(position - 1)
        update_attribute(position_column, position)
      end
    else
      false
    end
  end

  # Return the item at the offset specified from the current position
  def item_at_offset(offset)
    in_list? ? offset_scope(offset).first : nil
  end

  # Return +true+ if this object is the last in the list.
  def last?
    in_list? && current_position == last_position
  end
  alias_method :bottom?, :last?

  # Returns the bottom item
  def last_item
    list_scope.last
  end
  alias_method :bottom_item, :last_item

  # Returns the bottom position in the list.
  def last_position
    item = last_item
    item ? item.current_position : 0
  end
  alias_method :bottom_position, :last_position

  # Return the next lower item in the list.
  def lower_item
    item_at_offset(1)
  end
  alias_method :next_item, :lower_item

  # Return items lower than this item or an empty array if it is the last item
  def lower_items
    list_scope.where(["#{quoted_position_column} > ?", current_position]).all
  end

  # Swap positions with the next higher item, if one exists.
  def move_higher
    in_list? && (first? || insert_at(current_position - 1))
  end
  alias_method :move_up, :move_higher

  # Swap positions with the next lower item, if one exists.
  def move_lower
    in_list? && (last? || insert_at(current_position + 1))
  end
  alias_method :move_down, :move_lower

  # Move to the bottom of the list. If the item is already in the list,
  # the items below it have their position adjusted accordingly.
  def move_to_bottom
    in_list? && (last? || add_to_list)
  end

  # Move to the top of the list. If the item is already in the list,
  # the items above it have their position adjusted accordingly.
  def move_to_top
    in_list? && (first? || insert_at(1))
  end

  # Removes the item from the list.
  def remove_from_list
    if in_list?
      decrement_position_on_lower_items
      update_attribute(position_column, nil)
    else
      false
    end
  end

  private
    def add_to_list_bottom #:nodoc:
      send("#{position_column}=".to_sym, last_position + 1)
    end

    def base_scope #:nodoc:
      self.class.unscoped.where(scope_condition)
    end

    def decrement_position_on_lower_items #:nodoc:
      lower_scope(current_position).update_all(position_update('- 1'))
    end

    def increment_position_on_lower_items(position) #:nodoc:
      lower_scope(position).update_all(position_update('+ 1'))
    end

    def list_scope #:nodoc:
      base_scope.order(position_column).where("#{quoted_position_column} IS NOT NULL")
    end

    def lower_scope(position) #:nodoc:
      base_scope.where(["#{quoted_position_column} > ?", position])
    end

    def offset_scope(offset) #:nodoc:
      base_scope.where(position_column => current_position + offset)
    end

    def position_column #:nodoc:
      acts_as_list_options[:column]
    end

    def position_update(direction) #:nodoc:
      "#{quoted_position_column} = (#{quoted_position_column} #{direction})"
    end

    def quoted_position_column #:nodoc:
      connection.quote_column_name(position_column)
    end

    def scope_condition #:nodoc:
      if acts_as_list_options[:scope].is_a?(String)
        instance_eval("\"#{acts_as_list_options[:scope]}\"")
      else
        Array.wrap(acts_as_list_options[:scope]).inject({}){ |m,k| m[k] = send(k); m }
      end
    end

end

ActiveRecord::Base.send(:include, Sortifiable)
