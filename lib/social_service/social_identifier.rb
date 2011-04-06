class SocialIdentifier < ActiveRecord::Base
  validates_presence_of :identifier
  validates_uniqueness_of :identifier
  
  belongs_to :user
end