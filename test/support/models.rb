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

class MediaFile < ActiveRecord::Base
  has_many :playlist_media_files, :dependent => :destroy
  has_many :playlists, :through => :playlist_media_files
end

class PlaylistMediaFile < ActiveRecord::Base
  acts_as_list :scope => :playlist
  belongs_to :playlist, :touch => true, :counter_cache => :file_count
  belongs_to :media_file
  default_scope order(:position)
end

class Playlist < ActiveRecord::Base
  has_many :playlist_media_files, :dependent => :destroy
  has_many :media_files, :through => :playlist_media_files
end
