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
  def self.included(base) #:nodoc:
    base.extend(ClassMethods)
    base.class_eval do
      class_attribute :acts_as_list_options, :instance_writer => false
      self.acts_as_list_options = {}
    end
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

      if options[:scope].is_a?(Symbol)
        if reflections.key?(options[:scope])
          reflection = reflections[options.delete(:scope)]

          if reflection.belongs_to?
            options[:scope] = scope_from_association_reflection(reflection)
          else
            raise ArgumentError, "Only belongs_to associations can be used as a scope"
          end
        elsif options[:scope].to_s !~ /_id$/
          scope_name = "#{options[:scope]}_id"
          options[:scope] = scope_name.to_sym if column_names.include?(scope_name)
        end
      end

      options[:class] = self

      include InstanceMethods

      before_create  :add_to_list
      before_destroy :decrement_position_on_lower_items,             :if => :in_list?
      before_save    :decrement_position_on_lower_items_in_old_list, :if => :will_leave_list?
      before_save    :add_to_bottom_of_new_list,                     :if => :will_leave_list?

      self.acts_as_list_options = options
    end

    private
      def scope_from_association_reflection(reflection) #:nodoc:
        if reflection.options[:polymorphic]
          if reflection.respond_to?(:foreign_type)
            [reflection.foreign_key, reflection.foreign_type].map(&:to_sym)
          else
            [reflection.association_foreign_key, reflection.options[:foreign_type]].map(&:to_sym)
          end
        else
          if reflection.respond_to?(:foreign_type)
            reflection.foreign_key.to_sym
          else
            reflection.association_foreign_key.to_sym
          end
        end
      end

  end

  # All the methods available to a record that has had <tt>acts_as_list</tt>
  # specified. Each method works by assuming the object to be the item in the
  # list, so <tt>chapter.move_lower</tt> would move that chapter lower in the
  # list of all chapters. Likewise, <tt>chapter.first?</tt> would return +true+
  # if that chapter is the first in the list of all chapters.
  module InstanceMethods
    # Add the item to the end of the list
    def add_to_list
      if in_list?
        move_to_bottom
      else
        list_class.transaction do
          ids = lock_list!
          last_position = ids.size
          if persisted?
            update_position last_position + 1
          else
            set_position last_position + 1
          end
        end
      end
    end

    # Returns the current position
    def current_position
      send(position_column).to_i
    end

    # Decrease the position of this item without adjusting the rest of the list.
    def decrement_position
      in_list? && update_position(current_position - 1)
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

    # Test if this record is in a scoped list but will leave the scoped list when saved
    def will_leave_list?
      in_list? && scope_parts.any? { |scope_part| send("#{scope_part}_changed?") }
    end

    # Increase the position of this item without adjusting the rest of the list.
    def increment_position
      in_list? && update_position(current_position + 1)
    end

    # Insert the item at the given position (defaults to the top position of 1).
    def insert_at(position = 1)
      list_class.transaction do
        ids = lock_list!
        position = [[1, position].max, ids.size].min

        if persisted?
          current_position = ids.index(id) + 1

          sql = <<-SQL
            #{quoted_position_column} = CASE
            WHEN #{quoted_position_column} = #{current_position} THEN #{position}
            WHEN #{quoted_position_column} > #{current_position}
            AND #{quoted_position_column} < #{position} THEN #{quoted_position_column} - 1
            WHEN #{quoted_position_column} < #{current_position}
            AND #{quoted_position_column} >= #{position} THEN #{quoted_position_column} + 1
            ELSE #{quoted_position_column}
            END
          SQL

          list_scope.update_all(sql)
          update_position(position)
        else
          save!

          sql = <<-SQL
            #{quoted_position_column} = CASE
            WHEN #{quoted_position_column} >= #{position} THEN #{quoted_position_column} + 1
            ELSE #{quoted_position_column}
            END
          SQL

          list_scope.update_all(sql)
          update_position(position)
        end
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
      last_item.try(:current_position) || 0
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
      if in_list?
        list_class.transaction do
          ids = lock_list!
          current_position, last_position = ids.index(id) + 1, ids.size

          if current_position > 1
            sql = <<-SQL
              #{quoted_position_column} = CASE
              WHEN #{quoted_position_column} = #{current_position} - 1 THEN #{current_position}
              WHEN #{quoted_position_column} = #{current_position} THEN #{current_position} - 1
              ELSE #{quoted_position_column}
              END
            SQL

            set_position current_position - 1
            list_scope.update_all(sql) > 0
          else
            true
          end
        end
      else
        false
      end
    end
    alias_method :move_up, :move_higher

    # Swap positions with the next lower item, if one exists.
    def move_lower
      if in_list?
        list_class.transaction do
          ids = lock_list!
          current_position, last_position = ids.index(id) + 1, ids.size

          if current_position < last_position
            sql = <<-SQL
              #{quoted_position_column} = CASE
              WHEN #{quoted_position_column} = #{current_position} + 1 THEN #{current_position}
              WHEN #{quoted_position_column} = #{current_position} THEN #{current_position} + 1
              ELSE #{quoted_position_column}
              END
            SQL

            set_position current_position + 1
            list_scope.update_all(sql) > 0
          else
            true
          end
        end
      else
        false
      end
    end
    alias_method :move_down, :move_lower

    # Move to the bottom of the list. If the item is already in the list,
    # the items below it have their position adjusted accordingly.
    def move_to_bottom
      if in_list?
        list_class.transaction do
          ids = lock_list!
          current_position, last_position = ids.index(id) + 1, ids.size

          if current_position < last_position
            sql = <<-SQL
              #{quoted_position_column} = CASE
              WHEN #{quoted_position_column} = #{current_position} THEN #{last_position}
              WHEN #{quoted_position_column} > #{current_position} THEN #{quoted_position_column} - 1
              ELSE #{quoted_position_column}
              END
            SQL

            set_position last_position
            list_scope.update_all(sql) > 0
          else
            true
          end
        end
      else
        false
      end
    end

    # Move to the top of the list. If the item is already in the list,
    # the items above it have their position adjusted accordingly.
    def move_to_top
      if in_list?
        list_class.transaction do
          ids = lock_list!
          current_position, last_position = ids.index(id) + 1, ids.size

          if current_position > 1
            sql = <<-SQL
              #{quoted_position_column} = CASE
              WHEN #{quoted_position_column} = #{current_position} THEN 1
              WHEN #{quoted_position_column} < #{current_position} THEN #{quoted_position_column} + 1
              ELSE #{quoted_position_column}
              END
            SQL

            set_position 1
            list_scope.update_all(sql) > 0
          else
            true
          end
        end
      else
        false
      end
    end

    # Removes the item from the list.
    def remove_from_list
      if in_list?
        list_class.transaction do
          ids = lock_list!
          current_position, last_position = ids.index(id) + 1, ids.size

          sql = <<-SQL
            #{quoted_position_column} = CASE
            WHEN #{quoted_position_column} = #{current_position} THEN NULL
            WHEN #{quoted_position_column} > #{current_position} THEN #{quoted_position_column} - 1
            ELSE #{quoted_position_column}
            END
          SQL

          set_position nil
          list_scope.update_all(sql) > 0
        end
      else
        false
      end
    end

    private
      def base_scope #:nodoc:
        list_class.unscoped.where(scope_condition)
      end

      def decrement_position_on_lower_items #:nodoc:
        if last?
          true
        else
          update = "#{quoted_position_column} = #{quoted_position_column} - 1"
          conditions = "#{quoted_position_column} > #{current_position}"
          list_scope.update_all(update, conditions) > 0
        end
      end

      def decrement_position_on_lower_items_in_old_list #:nodoc:
        with_old_scope do
          decrement_position_on_lower_items
        end
      end

      def with_old_scope #:nodoc:
        # Save new scope in variable
        new_scope = scope_parts.map { |scope_part| send(scope_part) }

        # Set old scope
        scope_parts.each { |scope_part| send "#{scope_part}=", send("#{scope_part}_was") }

        retval = yield

        # Set new scope
        scope_parts.each_with_index { |scope_part, i| send "#{scope_part}=", new_scope[i] }

        retval
      end

      def scope_parts_from_string(string) #:nodoc:
        string.split('AND').map(&:strip).map { |condition| condition.split.first }
      end

      def scope_parts #:nodoc:
        if acts_as_list_options[:scope].is_a?(String)
          scope_parts_from_string(acts_as_list_options[:scope])
        else
          Array(acts_as_list_options[:scope])
        end
      end

      def add_to_bottom_of_new_list #:nodoc:
        set_position nil
        add_to_list
      end

      def set_position(position) #:nodoc:
        send "#{position_column}=", position
        true
      end

      def list_class #:nodoc:
        acts_as_list_options[:class]
      end

      def list_scope #:nodoc:
        base_scope.order(position_column).where("#{quoted_position_column} IS NOT NULL")
      end

      def lock_list! #:nodoc:
        connection.select_values(list_scope.select(list_class.primary_key).lock(true).to_sql)
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

      def quoted_position_column #:nodoc:
        connection.quote_column_name(position_column)
      end

      def scope_condition #:nodoc:
        if acts_as_list_options[:scope].is_a?(String)
          instance_eval %("#{acts_as_list_options[:scope]}")
        else
          Array(acts_as_list_options[:scope]).each_with_object({}) { |k, m| m[k] = send(k) }
        end
      end

      def update_position(new_position) #:nodoc:
        list_class.update_all({ position_column => new_position }, { list_class.primary_key => id })
        set_position new_position
      end
  end
end

ActiveRecord::Base.send(:include, Sortifiable)
