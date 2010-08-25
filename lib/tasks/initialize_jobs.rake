namespace :jobs do
  desc "move all Web Address sorts to type_ids"
  task :initialize => :environment do
    # Deletes old delayed Jobs and starts a new one for the activity tracking email sending
    Delayed::Job.destroy_all
    Delayed::Job.enqueue ActivityTrackingNotification.new, 0, ActivityTrackingNotification.delivery_period.from_now
  end
end