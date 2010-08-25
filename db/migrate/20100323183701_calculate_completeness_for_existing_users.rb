class CalculateCompletenessForExistingUsers < ActiveRecord::Migration
  def self.up
    Profile.all.each do |p|
      p.calculate_completeness
      p.show_profile = 1
      p.save!
    end
  end

  def self.down
  end
end
