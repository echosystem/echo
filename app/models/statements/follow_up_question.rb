class FollowUpQuestion < Question
  has_children_of_types [:Proposal,true],[:BackgroundInfo,true]
  has_linkable_types :Question
  
  belongs_to :question

  delegate :level, :ancestors, :topic_tags, :topic_tags=, :tags, :taggable?, :echoable?, :editorial_state_id,
           :editorial_state_id=, :published, :locked_at, :supported?, :taggable?, :creator_id=,
           :creator_id, :creator, :author_support, :ancestors, :target_id, :target_root_id, :to => :question

  validates_associated :question

  def target_statement
    self.question
  end

  def set_statement(attrs={})
    self.statement = self.question.statement = Statement.new(attrs)
  end

  #################################################
  # string helpers (acts_as_echoable overwriting) #
  #################################################

  class << self
    
    def new_instance(attributes = nil)
      parent = attributes ? attributes.delete(:parent_id) : nil
      root = attributes.delete(:root_id)
      statement = Statement.find(attributes.delete(:statement_id)) if !attributes[:statement_id].blank?
      question = statement.nil? ? Question.new_instance(attributes) : statement.statement_nodes.all(:conditions => "type = 'Question'").first
      self.new({:parent_id => parent,
                :root_id => root,
                :question => question,
                :creator => question.creator,
                :echo => question.echo,
                :statement => question.statement})
    end

    # helper function to differentiate this model as a level 0 model
    def is_top_statement?
      true
    end
    
    protected

    def children_joins
      " LEFT JOIN #{Statement.table_name} ON #{self.table_name}.statement_id = #{Statement.table_name}.id"
    end

    def state_conditions(opts)
      sanitize_sql(["AND (#{Statement.table_name}.editorial_state_id = ? OR #{self.table_name}.creator_id = ?) ",
                        StatementState['published'].id, opts[:user] ? opts[:user].id : -1])
    end
    
    def sub_types
      [:FollowUpQuestion, :DiscussAlternativesQuestion]
    end
  end
end