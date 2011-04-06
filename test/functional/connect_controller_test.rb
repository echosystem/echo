require 'test_helper'

class ConnectControllerTest < ActionController::TestCase
  # Replace this with your real tests.
  def setup
    login_as :user
    @controller = ConnectController.new
    @user = Profile.find_by_full_name('Joe Test')
  end
  
  test "should get show" do
    get :show
    assert_response :success
    assert_not_nil assigns(:profiles)
  end
  
  test "should get Joe" do
    get :show, :search_terms => "Joe"
    assert_response :success
    assert_true(assigns(:profiles).include?(@user))
  end
  
  test "should get Joe in Affected" do
    get :show, :search_terms => "Joe", :sort => TagContext["affection"].id
    assert_response :success
    assert_true(assigns(:profiles).include?(@user))
  end
  
  test "should not get Joe in Experts" do
    get :show, :search_terms => "Joe", :sort => TagContext["expertise"].id
    assert_response :success
    assert_true(!assigns(:profiles).include?(@user))
  end
  
  test "should get roadmap" do
    get :roadmap
    assert_response :success
  end
  
end
