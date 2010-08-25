class UpdateTagsLanguageId < ActiveRecord::Migration
  def self.up
    Tag.all.each do |tag|
      tag.language = Tag.languages("de") if tag.language.nil?
      tag.save
    end
  end

  def self.down
  end
end
