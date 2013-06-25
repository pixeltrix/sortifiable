module ActiveRecord
  class Base
    def self.active_record_3_0?
      VERSION::MAJOR == 3 && VERSION::MINOR == 0
    end
  end
end

class Mixin < ActiveRecord::Base
end

class ListMixin < ActiveRecord::Base
  self.table_name = "mixins"
  acts_as_list :column => "pos", :scope => :parent

  if active_record_3_0?
    default_scope order(:pos)
  else
    default_scope { order(:pos) }
  end
end

class ListMixinSub1 < ListMixin
end

class ListMixinSub2 < ListMixin
end

class ListWithStringScopeMixin < ActiveRecord::Base
  self.table_name =  "mixins"
  acts_as_list :column => "pos", :scope => 'parent_id = #{parent_id}'

  if active_record_3_0?
    default_scope order(:pos)
  else
    default_scope { order(:pos) }
  end
end

class ArrayScopeListMixin < ActiveRecord::Base
  self.table_name =  "mixins"
  acts_as_list :column => "pos", :scope => [:parent_id, :parent_type]

  if active_record_3_0?
    default_scope order(:pos)
  else
    default_scope { order(:pos) }
  end
end

class AssociationScopeListMixin < ActiveRecord::Base
  self.table_name =  "mixins"
  belongs_to :parent
  acts_as_list :column => "pos", :scope => :parent

  if active_record_3_0?
    default_scope order(:pos)
  else
    default_scope { order(:pos) }
  end
end

class PolymorphicAssociationScopeListMixin < ActiveRecord::Base
  self.table_name =  "mixins"
  belongs_to :parent, :polymorphic => true
  acts_as_list :column => "pos", :scope => :parent

  if active_record_3_0?
    default_scope order(:pos)
  else
    default_scope { order(:pos) }
  end
end

class ParanoidMixin < ActiveRecord::Base
  self.table_name =  "mixins"
  acts_as_list :column => "pos", :scope => :parent

  if active_record_3_0?
    default_scope where(:deleted_at => nil).order(:pos)
  else
    default_scope { where(:deleted_at => nil).order(:pos) }
  end

  def self.deleted
    unscoped.where('deleted_at IS NOT NULL')
  end

  def destroy
    update_attributes(:deleted_at => Time.current)
  end

  def restore
    update_attributes(:deleted_at => nil)
  end
end