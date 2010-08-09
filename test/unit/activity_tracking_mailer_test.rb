require 'test_helper'

class ActivityTrackingMailerTest < ActionMailer::TestCase
  def test_activity_tracking_email_question
    user = users(:user)
    question_events = [events(:event_test_question)]
    tags = {'#echonomyjam' => 1,'user' => 2}
    events = []
    # Send the email, then test that it got queued
    email = ActivityTrackingMailer.deliver_activity_tracking_email!(user,question_events,tags,events)
    assert !ActionMailer::Base.deliveries.empty?
    # Test the body of the sent email contains what we expect it to
    assert_equal [user.email], email.to
    assert_equal "Activity Tracking", email.subject
    assert_match /Activity Tracking/, email.encoded
    assert_match /New Debates!/, email.encoded
    assert_match /New Debates from last week: 1/, email.encoded
    assert_match /New Tags from last week:/, email.encoded
    assert_match /user/, email.encoded
    assert_match /(2)/, email.encoded
  end
  
  def test_activity_tracking_email_proposal
    user = users(:user)
    question_events = []
    tags = {}
    proposal_event = events(:event_second_proposal)
    parent_id = JSON.parse(proposal_event.event)['proposal']['parent_id']
    title = JSON.parse(proposal_event.event)['proposal']['statement']['statement_documents'][0]['title']
    events = [proposal_event]
    # Send the email, then test that it got queued
    email = ActivityTrackingMailer.deliver_activity_tracking_email!(user,question_events,tags,events)
    assert !ActionMailer::Base.deliveries.empty?
    # Test the body of the sent email contains what we expect it to
    assert_equal [user.email], email.to
    assert_equal "Activity Tracking", email.subject
    assert_match /Activity Tracking/, email.encoded
    assert_match /#{Question.find(parent_id).translated_document(EnumKey.find_by_code("en")).title}/, email.encoded
    assert_match /#{title}/, email.encoded
  end

  def test_activity_tracking_email_improvement_proposal
    user = users(:user)
    question_events = []
    tags = {}
    impro_proposal_event = events(:event_first_impro_proposal)
    parent_id = JSON.parse(impro_proposal_event.event)['improvement_proposal']['parent_id']
    root_id = JSON.parse(impro_proposal_event.event)['improvement_proposal']['root_id']
    title = JSON.parse(impro_proposal_event.event)['improvement_proposal']['statement']['statement_documents'][0]['title']
    events = [impro_proposal_event]
    # Send the email, then test that it got queued
    email = ActivityTrackingMailer.deliver_activity_tracking_email!(user,question_events,tags,events)
    assert !ActionMailer::Base.deliveries.empty?
    # Test the body of the sent email contains what we expect it to
    assert_equal [user.email], email.to
    assert_equal "Activity Tracking", email.subject
    assert_match /Activity Tracking/, email.encoded
    assert_match /#{Proposal.find(parent_id).translated_document(EnumKey.find_by_code("en")).title}/, email.encoded
    assert_match /#{Question.find(root_id).translated_document(EnumKey.find_by_code("en")).title}/, email.encoded
    assert_match /#{title}/, email.encoded
  end
  
  def test_approval_notification_email
    users = [users(:user),users(:joe),users(:ben)]
    statement_node = statement_nodes('first-impro-proposal')
    statement_document = statement_documents('first-impro-proposal-doc-english')
    # Send the email, then test that it got queued
    email = ActivityTrackingMailer.deliver_approval_notification!(statement_node, statement_document, users)
    assert !ActionMailer::Base.deliveries.empty?
    # Test the body of the sent email contains what we expect it to
    assert_equal users.map{|u|u.email}, email.to
    assert_equal "An Improvement Proposal was approved for incorporation", email.subject
    assert_match /#{statement_document.title}/, email.encoded
    assert_match /#{statement_node.id}/, email.encoded
  end
  
  def test_incorporation_notification_email
    users = [users(:user),users(:joe),users(:ben)]
    statement_node = statement_nodes('first-proposal')
    statement_document = statement_documents('first-proposal-doc-english')
    # Send the email, then test that it got queued
    email = ActivityTrackingMailer.deliver_incorporation_notification!(statement_node, statement_document, users)
    assert !ActionMailer::Base.deliveries.empty?
    # Test the body of the sent email contains what we expect it to
    assert_equal users.map{|u|u.email}, email.to
    assert_equal "A Proposal you support has been updated!", email.subject
    assert_match /#{statement_document.title}/, email.encoded
    assert_match /#{statement_node.id}/, email.encoded
  end
  
end