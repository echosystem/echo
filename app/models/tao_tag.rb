class TaoTag < ActiveRecord::Base
  attr_accessible :tag, :tag_id, :context_id,
                  :tao, :tao_type, :tao_id
                  # :tagger, :tagger_type, :tagger_id

  enum :contexts, :name => :tag_contexts

  belongs_to :tag
  belongs_to :tao, :polymorphic => true
  # belongs_to :tagger, :polymorphic => true
  
  validates_presence_of :context_id
  validates_presence_of :tag_id
  
  validates_uniqueness_of :tag_id, :scope => [:tao_type, :tao_id, :context_id]
  
  class << self
    def create_for(tags,language_id,attributes)
      tags.map { |tag|
        tag = Tag.find_or_create_with_like_by_value(tag.strip,language_id)
        tao_tag = create(attributes.merge(:tag_id => tag.id))
        tao_tag.new_record? ? nil : tao_tag
      }.compact
    end
  end
end
