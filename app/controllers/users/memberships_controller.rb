class Users::MembershipsController < ApplicationController

  before_filter :fetch_membership, :only => [:show, :edit, :update, :destroy]

  helper :profiles
  helper :my_echo

  access_control do
    allow logged_in
  end

  auto_complete_for :membership, :organisation, :limit => 7
  auto_complete_for :membership, :position, :limit => 7 

  # Shows the membership identified through params[:id]
  # method: GET
  def show
    render_membership :partial =>'membership'
  end

  # Render the new membership template. Currently unused.
  # method: GET
  def new
    @membership = Membership.new

    respond_to do |format|
      format.html # new.html.erb
    end
  end

  # Render the edit membership template. Currently only respond to JS.
  # method: GET
  def edit
    render_membership :partial => 'edit'
  end

  # Create a new membership with the given params. Show error messages
  # through javascript if something fails.
  # method: POST
  def create
    begin
      @membership = Membership.new(params[:membership].merge(:user_id => current_user.id))
      previous_completeness = @membership.percent_completed

      respond_to do |format|
        format.js do
          if @membership.save
            current_completeness = @membership.percent_completed
            set_info("discuss.messages.new_percentage", :percentage => current_completeness) if previous_completeness != current_completeness
            render_with_info do |p|
              p.insert_html :bottom, 'membership_list', :partial => 'users/memberships/membership'
              p << "$('#membership_organisation').val('').focus();"
              p << "$('#membership_position').val('');"
            end
          else
            set_error @membership and render_with_error
          end
        end
      end
    rescue Exception => e
      log_message_error(e, "Error creating membership.")
    else
      log_message_info("Membership has been created sucessfully.")
    end
  end

  # Update the membership attributes.
  # method: PUT
  def update
    begin
      respond_to do |format|
        format.js do
          if @membership.update_attributes(params[:membership])
            replace_content(dom_id(@membership), :partial => 'membership')
          else
            set_error @membership and render_with_error
          end
        end
      end
    rescue Exception => e
      log_message_error(e, "Error updating membership '#{@membership.id}'.")
    else
      log_message_info("Membership '#{@membership.id}' has been updated sucessfully.")
    end
  end

  # Destroy the membership specified through params[:id]
  # method: DELETE
  def destroy
    id = @membership.id

    begin
      previous_completeness = @membership.percent_completed
      @membership.destroy
      current_completeness = @membership.percent_completed
      set_info("discuss.messages.new_percentage", :percentage => current_completeness) if previous_completeness != current_completeness

      respond_to do |format|
        format.js do
          render_with_info do |p|
            p.remove dom_id(@membership)
          end
        end
      end
    rescue Exception => e
      log_message_error(e, "Error deleting membership '#{@membership.id}'.")
    else
      log_message_info("Membership '#{@membership.id}' has been deleted sucessfully.")
    end
  end

  private

  def fetch_membership
    @membership = Membership.find(params[:id])
  end

  def render_membership(opts={})
    respond_to do |format|
      format.js do
        replace_content(dom_id(@membership), :partial => opts[:partial])
      end
    end
  end
end
