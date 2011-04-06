Given /^there are no user reports$/ do
  Report.destroy_all
end

Then /^"([^\"]*)" should be reported with a reason$/ do |name|
  user = Profile.find_by_full_name(name).user
  user.reports.should_not be_empty
  user.reports.first.reason.should_not be_nil
end

Then /^I should see ([0-9]+) (.+) reports$/ do |count, status|
  within "##{status}_reports_container" do |content|
    content.should have_selector(".report") # working with :count?
    content.should contain("#{count} #{status} reports")
  end
end

Then /^I should see ([0-9]+) reports$/ do |count|
  response.should have_selector(".report", :count => count.to_i)
end

When /^I follow the "([^\"]*)" link for the (.+) report of "([^\"]*)"$/ do |link, status, name|
  user = Profile.find_by_full_name(name).user
  status = status.to_sym
  report = user.reports.select(&status).first
  When "I follow \"#{link.downcase}\" within \"#report_#{report.id}\""
end
