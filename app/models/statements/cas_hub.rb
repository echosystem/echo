class CasHub < StatementNode
  
  has_many :alternatives, :class_name => "StatementNode", :foreign_key => 'parent_id', :conditions => "#{table_name}.type != 'DiscussAlternativesQuestion'"

  has_one :discuss_alternatives_question, :foreign_key => 'parent_id', :class_name => "DiscussAlternativesQuestion"
  belongs_to :twin_hub, :class_name => "CasHub"
  
  def target_id
    parent_id
  end
  
end