class Mixin < ActiveRecord::Base
end

class ListMixin < ActiveRecord::Base
  self.table_name = "mixins"
  default_scope order(:pos)
  acts_as_list :column => "pos", :scope => :parent
end

class ListMixinSub1 < ListMixin
end

class ListMixinSub2 < ListMixin
end

class ListWithStringScopeMixin < ActiveRecord::Base
  self.table_name =  "mixins"
  default_scope order(:pos)
  acts_as_list :column => "pos", :scope => 'parent_id = #{parent_id}'
end

class ArrayScopeListMixin < ActiveRecord::Base
  self.table_name =  "mixins"
  default_scope order(:pos)
  acts_as_list :column => "pos", :scope => [:parent_id, :parent_type]
end

class AssociationScopeListMixin < ActiveRecord::Base
  self.table_name =  "mixins"
  belongs_to :parent
  default_scope order(:pos)
  acts_as_list :column => "pos", :scope => :parent
end

class PolymorphicAssociationScopeListMixin < ActiveRecord::Base
  self.table_name =  "mixins"
  belongs_to :parent, :polymorphic => true
  default_scope order(:pos)
  acts_as_list :column => "pos", :scope => :parent
end
