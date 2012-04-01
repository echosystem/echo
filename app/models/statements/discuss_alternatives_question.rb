class DiscussAlternativesQuestion < FollowUpQuestion
  has_children_of_types [:Proposal,true],[:BackgroundInfo,true]
  has_linkable_types

  #has_one :hub, :class_name => "CasHub", :foreign_key => "question_id"
  
  alias :hub :parent
  
  delegate :lft, :rgt, :to => :parent_node
  def target_root_id
    self.root_id
  end
  
  def transpose_mirror_tree
    # create the new twin hub and association between twin hubs
    new_hub = CasHub.create(:root_id => question.target_id, :parent_id => question.target_id,
                            :statement => question.statement, :creator_id => question.creator_id, 
                            :twin_hub_id => hub.id)
    hub.update_attribute(:twin_hub_id, new_hub.id)
    
    
      
    # create proposals that mirror the alternatives from the parent hub
    alternatives = hub.children
    alternatives.each do |alternative|
      next if alternative.id.eql?(self.id)
      attributes = alternative.attributes
      # delete attributes that we don't want to transpose
      attributes.delete("created_at")
      attributes.delete("updated_at")
      attributes.delete("lft")
      attributes.delete("rgt")
      attributes.delete("id")
      attributes.delete("type")
      attributes.delete("drafting_state")
      # add the id of the new twin hub as the parent_id
      attributes["parent_id"] = new_hub.id
      attributes["root_id"] = new_hub.root_id
      Proposal.create(attributes)
    end
    self.reload
  end
  
  def parent_node
    hub.parent
  end

  class << self
    def new_instance(attributes = nil)
      # parent id that comes from the form is from an alternative, we have to delete it and add the new DAQ to the hub of the alternative
      parent_id = attributes ? attributes.delete(:parent_id) : nil
      hub = StatementNode.find(parent_id).hub if parent_id
      new_daq = super
      new_daq.parent = hub
      #new_daq.hub = hub 
      new_daq
    end
    
    def is_mirror_discussion?
      true
    end
    
  end
end