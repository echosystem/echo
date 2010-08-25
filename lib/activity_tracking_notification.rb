#job class responsible for getting all user related events and sending an email
class ActivityTrackingNotification

#  @@user_split_condition = {}
#  @@tracking_period = 7.days.ago
#  @@delivery_period = Time.now.tomorrow.midnight

  def initialize
  end

  def self.user_split_condition
    @@user_split_condition
  end

  def self.tracking_period
    @@tracking_period
  end

  def self.delivery_period
    @@delivery_period
  end

  def self.user_split_condition=(value)
    @@user_split_condition = value
  end

  def self.tracking_period=(value)
    @@tracking_period = value
  end

  def self.delivery_period=(value)
    @@delivery_period = value
  end


  def perform
    week_day = Time.now.wday
    User.all(@@user_split_condition).each do |user|

      next if !user.email_notification?

      events = Event.find_tracked_events(user, @@tracking_period.ago)
      next if events.blank? #if there are no events to send per email, then get the hell out

      question_events = eventsselect{|e|JSON.parse(e.event).keys[0] == 'question'}
      tags = Hash.new
      question_events.each do |question|
        question_data = JSON.parse(question.event)
        question_data['question']['tao_tags'].each do |tao_tag|
          tags[tao_tag['tag']['value']] = tags[tao_tag['tag']['value']] ? tags[tao_tag['tag']['value']] + 1 : 1
        end
      end
      events.sort! do |a,b|
        a_parsed = JSON.parse(a.event)
        root_x = a_parsed[a_parsed.keys[0]]['root_id'] || -1
        parent_x = a_parsed[a_parsed.keys[0]]['parent_id'] || -1
        b_parsed = JSON.parse(b.event)
        root_y = b_parsed[b_parsed.keys[0]]['root_id'] || -1
        parent_y = b_parsed[b_parsed.keys[0]]['parent_id'] || -1
        [root_x,parent_x] <=> [root_y,parent_y]
      end

      user.deliver_activity_tracking_email!(question_events, tags, events - question_events)
    end
    Delayed::Job.enqueue ActivityTrackingNotification.new, 0, @@delivery_period.from_now
  end
end
