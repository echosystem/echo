class StatementNode < ActiveRecord::Base
  acts_as_echoable
  acts_as_subscribeable
  acts_as_nested_set :scope => :root_id

  alias_attribute :target_id, :id

  def target_statement
    self
  end

  after_destroy :destroy_statement

  def destroy_statement
    self.statement.destroy if (self.statement.statement_nodes - [self]).empty?
  end

  ##
  ## ASSOCIATIONS
  ##

  belongs_to :creator, :class_name => "User"
  belongs_to :statement

  delegate :original_language, :document_in_language, :authors, :has_author?,
           :statement_image, :statement_image=, :image, :image=, :published?, :publish,
           :taggable?, :filtered_topic_tags, :topic_tags, :topic_tags=, :hash_topic_tags, :tags, :editorial_state_id,
           :editorial_state_id=, :editorial_state, :editorial_state=, :to => :statement

  has_many :statement_documents, :through => :statement, :source => :statement_documents do
    def for_languages(lang_ids)
      find(:all,
           :conditions => {:language_id => lang_ids, :current => true},
           :order => 'created_at ASC').sort {|a, b|
        lang_ids.index(a.language_id) <=> lang_ids.index(b.language_id)
      }.first
    end
  end

  ##
  ## VALIDATIONS
  ##

  validates_presence_of :creator_id
  validates_presence_of :statement
  validates_associated :creator
  validates_associated :statement

  ##
  ## NAMED SCOPES
  ##

  #auxiliar named scopes only used for tests
  %w(question proposal improvement pro_argument contra_argument follow_up_question).each do |type|
    class_eval %(
      named_scope :#{type.pluralize}, lambda{{ :conditions => { :type => '#{type.camelize}' } } }
    )
  end

  named_scope :by_creator, lambda {|id| {:conditions => ["creator_id = ?", id]}}
  named_scope :published, lambda {|auth|
    {:joins => :statement, :conditions => ["statements.editorial_state_id = ?", StatementState['published'].id] } unless auth
  }

  # orders
  named_scope :by_creation, :order => 'created_at DESC'
  named_scope :only_id, :select => 'statement_nodes.id'


  ## ACCESSORS
  %w(title text).each do |accessor|
    class_eval %(
      def #{accessor}(lang_ids)
        doc = statement_documents.for_languages(lang_ids)
        doc ? statement_documents.for_languages(lang_ids).#{accessor} : raise('no #{accessor} found in this language')
      end
    )
  end

  ##############################
  ######### ACTIONS ############
  ##############################

  def publishable?
    false
  end



  # Initializes this statement node's statement
  def set_statement(attrs={})
    self.statement = Statement.new(attrs)
  end

  # creates a new statement_document
  def add_statement_document(attributes={ },opts={})
    self.set_statement if self.statement.nil?
    self.statement.original_language_id = attributes.delete(:original_language_id).to_i if attributes[:original_language_id]
    doc = StatementDocument.new
    doc.statement = self.statement
    attributes.each {|k,v|doc.send("#{k.to_s}=", v)}
    self.statement.statement_documents << doc
    return doc
  end

  ########################
  # DOCUMENTS' LANGUAGES #
  ########################

  #
  # Checks if there is a document in any of the languages passed as argument
  #
  def translated_document?(lang_ids)
    return statement_documents.for_languages(lang_ids).nil?
  end

  #
  # returns a translated document for passed language_codes (or nil if none is found)
  #
  def document_in_preferred_language(lang_ids)
    @current_document ||= statement_documents.for_languages(lang_ids)
  end


  #
  # Checks if there is no document written in the given language code and that the current user has the
  # required language skills to translate it (speaks both languages at least intermediate).
  #
  def translatable?(user, from_language, to_language)
    if user && from_language != to_language
      languages = user.spoken_languages_at_min_level('advanced')
      languages.include?(from_language) && languages.include?(to_language)
    else
      false
    end
  end

  # Checks if, in case the user hasn't yet set his language knowledge, the current language is different from
  # the statement original language. used for the original message warning
  def not_original_language?(user, current_language_id)
    user ? (user.spoken_languages.empty? and current_language_id != original_language.id) : false
  end

  #
  # Returns the current document in its original language.
  #
  def document_in_original_language
    document_in_language(original_language)
  end



  #####################
  # CHILDREN/SIBLINGS #
  #####################


  #
  # Collects a filtered list of all siblings statements
  #
  # about other possible attributes, check child_statements documentation
  #
  def sibling_statements(opts={})
    opts[:type] ||= self.class.to_s
    self.parent.nil? ? [] : self.parent.child_statements(opts)
  end

  #
  # Collects a filtered list of all siblings statements' ids
  #
  # about other possible attributes, check sibling_statements documentation
  #
  def siblings_to_session(opts)
    opts[:for_session] = true
    sibling_statements(opts)
  end

  #
  # Collects a filtered list of all siblings statements' ids
  #
  # about other possible attributes, check child_statements documentation
  #
  def children_to_session(opts)
    opts[:for_session] = true
    child_statements(opts)
  end

  #
  # Get the paginated children given a certain child type
  # opts attributes:
  #
  # type (String : optional) : type of child statements to get
  # page (Integer : optional) : pagination parameter (default = 1)
  # per_page (Integer : optional) : pagination parameter (default = TOP_CHILDREN)
  #
  # call with no pagination attributes returns the top children
  # about other possible attributes, check child_statements documentation
  #
  def paginated_child_statements(opts)
    opts[:page] ||= 1
    opts[:per_page] ||= TOP_CHILDREN
    children = child_statements(opts)
    opts[:type] ? opts[:type].to_s.constantize.paginate_statements(children, opts[:page], opts[:per_page]) :
    this.class.paginate_statements(children, opts[:page], opts[:per_page])
  end

  #
  # Collects a filtered list of all children statements
  # opts attributes:
  #
  # type (String : optional) : type of child statements to get
  # user (User : optional) :   gets the statements belonging to the user regardless of state (published or new)
  # language_ids (Array[Integer] : optional) : filters out statement nodes whose documents languages are not included on the array (gets all of them if nil)
  #
  # call with no attributes returns the immediate children (check awesome nested set)
  # about other possible attributes, check statements_for_parent documentation
  #
  def child_statements(opts={})
    opts[:parent_id] = self.target_id
    opts[:filter_drafting_state] = self.draftable?
    opts[:type] ? opts[:type].to_s.constantize.statements_for_parent(opts) : children
  end

  #
  # counts the children the statement has of a certain type
  # opts attributes:
  #
  # type (String : optional) : type of child statements to count
  # user (User : optional) :   gets the statements belonging to the user regardless of state (published or new)
  # language_ids (Array[Integer] : optional) : filters out statement nodes whose documents languages are not included on the array (gets all of them if nil)
  #
  # call with no attributes returns the count of immediate children (check awesome nested set)
  # about other possible attributes, check count_statements_for_parent documentation
  #
  def count_child_statements(opts={})
    opts[:parent_id] = self.target_id
    opts[:filter_drafting_state] = self.draftable?
    opts[:type] ? opts[:type].to_s.constantize.count_statements_for_parent(opts) : children.count
  end

  private

  #################
  # Class methods #
  #################

  class << self

    # Aux Function: generates new instance (overwritten in follow up question)
    def new_instance(attributes = {})
      attributes[:editorial_state] = StatementState[attributes.delete(:editorial_state_id).to_i] if attributes[:editorial_state_id]
      editorial_state = attributes.delete(:editorial_state)
      node = self.new(attributes)
      node.set_statement(:editorial_state => editorial_state)
      node
    end

    # Aux Function: GUI Helper (overwritten in follow up question)
    def is_top_statement?
      false
    end

    # Aux Function: Get Siblings Helper (overwritten in doubles)
    def name_for_siblings
      self.name.underscore
    end

    #
    # Aux Function: paginates a set of ActiveRecord Objects
    # statements (Array) : array of objects to paginate
    # page, per_page (Integer) : pagination parameters
    #
    def paginate_statements(statements, page, per_page = nil)
      per_page = statements.length if per_page.nil? or per_page < 0
      per_page = 1 if per_page.to_i == 0
      statements.paginate(default_scope.merge(:page => page, :per_page => per_page))
    end

    ################################
    # CHILDREN BLOCK QUERY HELPERS #
    ################################

    #
    # Returns the number of child statements of a certain type (or types) from a given statement
    #
    def count_statements_for_parent(opts)
      fields = parent_conditions(opts.merge({:types => sub_types.map(&:to_s)}))
      fields[:select] = "DISTINCT #{table_name}.id"
      self.count(:all, fields)
    end

    #
    # Aux Function: gets a set of children given a certain parent (used to get siblings and children)
    #
    def statements_for_parent(opts)
      get_statements_for_parent(opts)
    end

    #
    # Aux Function: gets a set of children given a certain parent (used above)
    # opts attributes:
    #
    # for_session (Boolean : optional) : if true, returns an array of statement ids with the teaser path as last argument. if false, returns, the statements array
    # parent_id (Integer : optional) : if set, the parent id is added in the beginning of the teaser path (important URL contruct)
    #
    # about other possible attributes, check parent_conditions documentation
    #
    def get_statements_for_parent(opts)
      fields = parent_conditions(opts)

      statements = []

      if opts[:for_session]
        fields[:select] = "DISTINCT #{table_name}.id, #{table_name}.question_id"
        statements = self.scoped(fields).map{|s| s.question_id.nil? ? s.id : s.question_id}
        statements << "/#{opts[:parent_id].nil? ? '' : "#{opts[:parent_id]}/" }add/#{self.name.underscore}" # ADD TEASER
      else
        fields[:select] = "DISTINCT #{table_name}.*"
        statements = self.all(fields)
      end
      statements
    end

    #
    # Aux: Builds the query attributes for standard children operations
    # opts attributes:
    #
    # language_ids (Array[Integer] : optional) : filters out documents which language is not included on the array (gets all of them if nil)
    # drafting_states (Array[String] : optional) : filters out incorporable statements per drafting state (only for incorporable types)
    #
    def parent_conditions(opts)
      fields = {}
      fields.delete(:readonly)
      fields[:joins] =  "LEFT JOIN #{StatementDocument.table_name} d ON #{table_name}.statement_id = d.statement_id "
      fields[:joins] << "LEFT JOIN #{Echo.table_name} e ON #{table_name}.echo_id = e.id"
      fields[:joins] << children_joins
      fields[:conditions] = children_conditions(opts)
      fields[:conditions] << sanitize_sql([" AND d.language_id IN (?) ", opts[:language_ids]]) if opts[:language_ids]
      fields[:conditions] << drafting_conditions if opts[:filter_drafting_state]
      fields[:order] = "e.supporter_count DESC, #{table_name}.created_at DESC, #{table_name}.id"
      fields
    end

    def children_joins
      ''
    end

    #
    # returns a string of sql conditions representing getting statement nodes of certain types filtered by parent
    # opts attributes:
    # types (Array(String)) : array of types of statement nodes to filter by
    # parent_id (Integer) : id of parent statement node
    #
    def children_conditions(opts)
      sanitize_sql(["#{table_name}.type IN (?) AND #{table_name}.parent_id = ? ",
                    opts[:types] || [self.name], opts[:parent_id]])
    end

    public


    def search_discussions(opts={})
      opts.delete(:type)
      search_statement_nodes(opts)
    end


    #
    # gets a set of statement nodes given an hash of arguments
    #
    # opts attributes:
    #
    # search_term (string : optional) : value we ought to search for on title, text and statement tags
    # only_id (boolean : optional) : if true, returns an hash of the statements only with the id attribute filled
    # type (string : optional) : defines the type of statement to look for ("Question" in most of the cases)
    # show_unpublished (boolean : optional) : if false or nil, only get the published statements (see user as well)
    # user (User : optional) : only used if show_unpublished is false or nil; gets the statements belonging to the user regardless of state (published or new)
    # language_ids (Array[Integer] : optional) : filters out documents which language is not included on the array (gets all of them if nil)
    # drafting_states (Array[String] : optional) : filters out incorporable statements per drafting state (only for incorporable types)
    #
    # Called with no attributes filled: returns all published questions
    #
    def search_statement_nodes(opts={})
      search_term = opts.delete(:search_term)
      search_attrs = opts[:type].nil? ? 'root_id' : 'id'
      tag_clause = "SELECT DISTINCT s.#{search_attrs} FROM #{table_name} s "
      tag_clause << "LEFT JOIN #{Statement.table_name}               ON #{Statement.table_name}.id = s.statement_id " +
                    "LEFT JOIN #{StatementDocument.table_name} d     ON s.statement_id = d.statement_id "
      tag_clause << Statement.extaggable_joins_clause
      tag_clause << "WHERE "


      tags_query = ''
      and_conditions = []
      and_conditions << "d.current = 1"
      unless opts[:show_unpublished]
        publish_condition = []
        publish_condition << sanitize_sql(["#{Statement.table_name}.editorial_state_id = ?",StatementState['published'].id])
        publish_condition << sanitize_sql(["s.creator_id = ?",  opts[:user].id]) if opts[:user]
        and_conditions << "(#{publish_condition.join(' OR ')})"
      end
      and_conditions << sanitize_sql(["d.language_id IN (?)", opts[:language_ids]]) if opts[:language_ids]
      and_conditions << sanitize_sql(["s.drafting_state IN (?)", opts[:drafting_states]]) if opts[:drafting_states]
      and_conditions << sanitize_sql(["s.type = ?", opts[:type]]) if opts[:type]
      if !search_term.blank?
        tags_query = []
        terms = search_term.split(/[,\s]+/)
        terms.each do |term|
          or_conditions = Statement.extaggable_conditions_for_term(term)
          if (term.length > 3)
            or_conditions << sanitize_sql([" OR d.title LIKE ? OR d.text LIKE ?", "%#{term}%", "%#{term}%"])
          end
          tags_query << (tag_clause + (and_conditions + ["(#{or_conditions})"]).join(" AND "))
        end
        tags_query = tags_query.join(" UNION ALL ")
        statements_query = "SELECT #{table_name}.#{opts[:only_id] ? search_attrs : '*'} " +
                           "FROM (#{tags_query}) statement_node_ids " +
                           "LEFT JOIN #{table_name} ON #{table_name}.id = statement_node_ids.#{search_attrs} " +
                           "LEFT JOIN #{Echo.table_name} e ON e.id = #{table_name}.echo_id " +
                           "GROUP BY statement_node_ids.#{search_attrs} " +
                           "ORDER BY COUNT(statement_node_ids.#{search_attrs}) DESC,e.supporter_count DESC, #{table_name}.created_at DESC, #{table_name}.id;"
      else
        and_conditions << "s.type = 'Question'" if opts[:type].nil?
        statements_query = "SELECT DISTINCT s.#{opts[:only_id] ? search_attrs : '*'} from #{table_name} s " +
                           "LEFT JOIN #{Statement.table_name} ON #{Statement.table_name}.id = s.statement_id " +
                           "LEFT JOIN #{StatementDocument.table_name} d ON s.statement_id = d.statement_id " +
                           "LEFT JOIN #{Echo.table_name} e ON e.id = s.echo_id " +
                           "WHERE " + and_conditions.join(' AND ') +
                           " ORDER BY e.supporter_count DESC, s.created_at DESC, s.id;"
      end
      find_by_sql statements_query
    end


    def default_scope
      { :include => :echo,
        :order => "echos.supporter_count DESC, #{table_name}.created_at DESC, #{table_name}.id" }
    end

    ###################################
    # EXPANDABLE CHILDREN GUI HELPERS #
    ###################################

    #
    # visibility = false: returns an array of symbols of the possible children types
    # visibility = true: returns an array of sub arrays representing pairs [type: symbol class , visibility : true/false]
    # default: whether we should take out from or let the default children types in the array
    # expand: whether we should replace a children type for it's sub-types
    #
    def children_types(opts={})
      types = @@children_types[self.name] || @@children_types[self.superclass.name]
      types -= @@default_children_types if opts[:no_default]
      if opts[:expand]
        array = []
        types.each{|c| array += c[0].to_s.constantize.sub_types.map{|st|[st, c[1]]} }
        types = array
      end
      return types.map{|c|c[0]} if !opts[:visibility]
      types
    end


    # PARTIAL PATHS #
    def children_list_template
      "statements/children_list"
    end

    def children_template
      "statements/children"
    end

    def more_template
      "statements/more"
    end

    def descendants_template
      "statements/descendants"
    end

    def sub_types
      [self.name.to_sym]
    end

    def default_children_types(*klasses)
      @@default_children_types = klasses
    end

    def has_children_of_types(*klasses)
      @@children_types ||= { }
      @@children_types[self.name] ||= @@default_children_types.nil? ? [] : @@default_children_types
      @@children_types[self.name] = klasses + @@children_types[self.name]
    end
  end
  default_children_types [:FollowUpQuestion, true]
end
