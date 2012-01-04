class StatementNode < ActiveRecord::Base
  acts_as_echoable
  acts_as_subscribeable
  acts_as_nested_set :scope => :root_id, :base_conditions => "type != 'CasHub'"

  alias_attribute :target_id, :id
  alias_attribute :target_root_id, :root_id

  def target_statement
    self
  end

  def u_class_name
    self.class.name.underscore
  end

  # Deletion handling
  after_destroy :destroy_associated_objects

  def destroy_associated_objects
    #destroy_statement   # It didn't work - hard to comprehend, why.
    destroy_shortcuts
    destroy_descendants
  end

  #
  # Destroys the statement ONLY if this is the only statement node belonging the statement
  #
  def destroy_statement
    statement.destroy if statement and (statement.statement_nodes.map(&:target_id) - [target_id]).empty?
  end

  #
  # Destroys the shortcuts referencing this statement node
  #
  def destroy_shortcuts
    ShortcutCommand.destroy_all("command LIKE '%\"operation\":\"statement_node\"%' AND command LIKE '%\"id\":#{self.id}%'")
  end

  #
  # Destroys the children of this statement node, that in any other way can't be seen anymore
  #
  def destroy_descendants
    descendants.destroy_all
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
  named_scope :published, lambda {|auth| {
    :joins => :statement,
    :conditions => ["statements.editorial_state_id = ?", StatementState['published'].id] } unless auth
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

  def self.taggable?
    true
  end

  def publishable?
    false
  end

  def self.publishable?
    false
  end

  def is_referenced?
    false
  end

  def publish_descendants
    descendants.each do |node|
      if !node.published?
        node.publish
        node.statement.save
        EchoService.instance.published(node)
      end
    end
  end

#  handle_asynchronously :publish_descendants


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
    doc
  end

  # updates an existing node with a new set of attributes
  def update_node(attrs={})
    update_attributes(attrs)
  end

  #
  # Helper function to load the tags from the root
  #
  def load_root_tags
    self.topic_tags = self.root.nil? ? parent.root.topic_tags : self.root.topic_tags
  end

  ########################
  # DOCUMENTS' LANGUAGES #
  ########################

  #
  # Checks if there is a document in any of the languages passed as argument
  #
  def translated_document?(lang_ids)
    statement_documents.for_languages(lang_ids).nil?
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
      languages = user.spoken_languages_at_min_level('intermediate')
      languages.include?(from_language) && languages.include?(to_language)
    else
      false
    end
  end

  # Checks if, in case the user hasn't yet set his language knowledge, the current language is different from
  # the statement original language. used for the original message warning
  def should_set_languages?(user, current_language_id, document_language_id)
    user ? (user.spoken_languages.empty? and current_language_id != document_language_id) : false
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
    opts[:prev] ||= self.parent_node
    opts[:type] ||= self.class.to_s
    if opts[:prev].nil?
      []
    else
      opts[:lft] = opts[:prev].lft
      opts[:rgt] = opts[:prev].rgt
      opts[:filter_drafting_state] = self.incorporable?
      opts[:parent_id] = opts[:prev].target_id
      self.child_statements(opts)
    end
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
    opts[:root_id] = self.target_root_id
    opts[:parent_id] ||= self.target_id
    opts[:lft] ||= self.lft
    opts[:rgt] ||= self.rgt
    opts[:filter_drafting_state] ||= self.draftable?
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
    opts[:root_id] = self.root_id
    opts[:lft] = self.lft
    opts[:rgt] = self.rgt
    opts[:filter_drafting_state] = self.draftable?
    opts[:type] ? opts[:type].to_s.constantize.count_statements_for_parent(opts) : children.count
  end

  private

  #################
  # Class methods #
  #################

  class << self

    # Aux Function: generates new instance
    def new_instance(attributes = {})
      attributes = filter_editorial_state(attributes)
      editorial_state = attributes.delete(:editorial_state)
      node = self.new(attributes)
      node.set_statement(:editorial_state => editorial_state) if node.statement.nil?
      node
    end

    def filter_editorial_state(attributes={})
      attributes[:editorial_state] = StatementState[attributes.delete(:editorial_state_id).to_i] if attributes[:editorial_state_id]
      attributes
    end

    # Aux Function: Checks if node has more data to show or load
    def has_embeddable_data?
      false
    end


    # Aux Function: GUI Helper (overwritten in follow up question)
    def is_top_statement?
      false
    end

    # Aux Function: Function that says if this statement mirrors a sub tree somewhere
    def is_mirror_discussion?
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
        statements = self.base_class.scoped(fields).map{|s| s.question_id.nil? ? s.id : s.question_id}
        
        parent_id = opts[:hub] || opts[:parent_id]
        statements << "/#{parent_id.nil? ? '' : "#{parent_id}/" }add/#{self.name.underscore}" # ADD TEASER
      else
        fields[:select] = "DISTINCT #{table_name}.*"
        statements = self.base_class.all(fields)
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
      fields[:conditions] << state_conditions(opts)
      fields[:conditions] << alternative_conditions(opts) if !opts[:alternative_ids].blank?
      fields[:conditions] << sanitize_sql([" AND d.language_id IN (?) ", opts[:language_ids]]) if opts[:language_ids]
      fields[:conditions] << drafting_conditions if opts[:filter_drafting_state]
      fields[:order] = "e.supporter_count DESC, #{table_name}.created_at DESC, #{table_name}.id"
      fields
    end

    def children_joins
      ''
    end

    def state_conditions(opts)
      ''
    end

    #
    # returns a string of sql conditions representing getting statement nodes of certain types filtered by parent
    # opts attributes:
    # types (Array(String)) : array of types of statement nodes to filter by
    # parent_id (Integer) : id of parent statement node
    #
    def children_conditions(opts)
      sanitize_sql(["#{table_name}.type IN (?) AND
                     #{table_name}.root_id = ? AND
                     #{table_name}.lft >= ? AND #{table_name}.rgt <= ? ",
                    opts[:types] || sibling_types, opts[:root_id], opts[:lft], opts[:rgt]])
    end


    def sibling_types
      sub_types.map(&:to_s)
    end

    public

    #
    # gets a set of statement nodes given an hash of arguments
    #
    # opts attributes:
    #
    # search_term (string : optional) : value we ought to search for on title, text and statement tags
    # param (string : optional) : specifies the attribute which we should search
    # type (string : optional) : defines the type of statement to look for ("Question" in most of the cases)
    # show_unpublished (boolean : optional) : if false or nil, only get the published statements (see user as well)
    # user (User : optional) : only used if show_unpublished is false or nil; gets the statements belonging to the user regardless of state (published or new)
    # language_ids (Array[Integer] : optional) : filters out documents which language is not included on the array (gets all of them if nil)
    # drafting_states (Array[String] : optional) : filters out incorporable statements per drafting state (only for incorporable types)
    #
    # Called with no attributes filled: returns all published questions
    #
    def search_statement_nodes(opts={})
      aggregator_field = opts[:types].nil? ? 'root_id' : 'id'

      # Constant criteria
      document_conditions = []

      # Languages
      if opts[:user] and !opts[:user].spoken_languages.empty? and opts[:language_ids]
        document_conditions << sanitize_sql(["d.language_id IN (?)", opts[:language_ids]])
      end

      # Permissions
      opts[:node_conditions] ||= []
      opts[:node_conditions].map!{|cond|sanitize_sql(cond)}
      opts[:node_conditions] << Statement.conditions(opts, "s.closed_statement", "s.granted_user_id")
      opts[:node_conditions] << "s.top_level = 1"

      # Statement type
      if opts[:types]
        opts[:node_conditions] << sanitize_sql(["s.type IN (?)", opts[:types]])
      end

      # Published state
      unless opts[:show_unpublished]
        publish_condition = []
        publish_condition << sanitize_sql(["s.editorial_state_id = ?",StatementState['published'].id])
        publish_condition << sanitize_sql(["s.creator_id = ?",  opts[:user].id]) if opts[:user]
        opts[:node_conditions] << "(#{publish_condition.join(' OR ')})"
      end

      # Drafting state
      if opts[:drafting_states]
        opts[:node_conditions] << sanitize_sql(["s.drafting_state IN (?)", opts[:drafting_states]])
      end

      # Limit
      limit = "LIMIT #{opts[:limit]}" if opts[:limit]

      opts[:joins] ||= ""

      # Search terms
      search_term = opts.delete(:search_term)
      if !search_term.blank?
        term_query = "SELECT DISTINCT statement_id AS id FROM search_statement_text d "
        term_query << "WHERE "

        term_queries = []
        if search_term.include? ','
          terms = search_term.split(',')
        else
          terms = search_term.split(/[\s]+/)
        end

        terms.map(&:strip).each do |term|
          or_conditions = StatementDocument.term_conditions(term)
          term_queries << (term_query + (document_conditions + ["(#{or_conditions})"]).join(" AND "))
        end
        term_queries = term_queries.join(" UNION ALL ")

        joins = "LEFT JOIN search_statement_nodes s ON statement_ids.id = s.statement_id "
        joins << opts[:joins]
        statements_query = "SELECT s.#{opts[:param] || '*'} " +
                           "FROM (#{term_queries}) statement_ids " + joins +
                           "WHERE #{opts[:node_conditions].join(" AND ")} " +
                           "GROUP BY s.#{aggregator_field} " +
                           "ORDER BY COUNT(s.#{aggregator_field}) DESC, " +
                           "s.supporter_count DESC, s.id DESC #{limit};"
      else
        document_conditions << "d.current = 1"

        opts[:node_conditions] << "s.type = 'Question'" if opts[:types].nil?

        joins = "LEFT JOIN statement_documents d ON d.statement_id = s.statement_id " +
                Statement.extaggable_joins_clause("s.statement_id")
        joins << opts[:joins]

        statements_query = "SELECT DISTINCT s.#{opts[:param] || '*'} from search_statement_nodes s " + joins +
                           "WHERE " + (opts[:node_conditions] + document_conditions).join(' AND ') +
                           " ORDER BY s.supporter_count DESC, s.id DESC #{limit};"
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

    # TYPE-RELATIONS

    #
    # visibility = false: returns an array of symbols of the possible children types
    # visibility = true: returns an array of sub arrays representing pairs [type: symbol class , visibility : true/false]
    # expand: whether we should replace a children type for it's sub-types
    #
    def children_types(opts={})
      format_types @@children_types[self.name] || @@children_types[self.superclass.name], opts
    end

    #
    # visibility = false: returns an array of symbols of the possible children types
    # visibility = true: returns an array of sub arrays representing pairs [type: symbol class , visibility : true/false]
    # expand: whether we should replace a children type for it's sub-types
    #
    def default_children_types(opts={})
      format_types @@default_children_types, opts
    end

    def all_children_types(opts={})
      children_types(opts) + default_children_types(opts)
    end

    def format_types(types, opts={})
      if opts[:expand]
        array = []
        types.each{|c| array += c[0].to_s.constantize.sub_types.map{|st|[st, c[1]]} }
        types = array
      end
      return types.map{|c|c[0]} if !opts[:visibility]
      types
    end


    # gets the statement node types this content can be linked with
    def linkable_types
      @@linkable_types[self.name]
    end

    def sub_types
      [self.name.to_sym]
    end

    def has_default_children_of_types(*klasses)
      @@default_children_types = klasses
    end

    def has_children_of_types(*klasses)
      @@children_types ||= { }
      @@children_types[self.name] ||= []
      @@children_types[self.name] += klasses
    end

    def has_linkable_types(*klasses)
      @@linkable_types ||= { }
      @@linkable_types[self.name] ||= klasses
    end
  end
  has_default_children_of_types [:FollowUpQuestion,true]
end
