module StatementsHelper

  include PublishableModuleHelper
  include EchoableModuleHelper
  include IncorporationModuleHelper
  include TranslationModuleHelper


  ##################
  # RENDER HELPERS #
  ##################

  #
  # Renders ancestors headers (when we have a GET operation on a child node).
  #
  def render_ancestors(ancestors, ancestor_documents)
    val = ''
    ancestors.each do |ancestor|
      val << render_ancestor(ancestor, ancestor_documents[ancestor.statement_id])
    end
    val
  end

  def render_ancestor(ancestor, document)
    render :partial => 'statements/show', :locals => {:statement_node => ancestor,
                                                      :statement_document => document,
                                                      :only_header => true}
  end

  #
  # Renders all the possible children of the current node
  # (per type, ordering must be defined in the node type definition).
  #
  def render_all_children(statement_node, children)

    content = ''
    content << render_children(statement_node, statement_node.class.children_types, children)
    content << render_children(statement_node, statement_node.class.default_children_types, children)
    content
  end


  def render_children(statement_node, children_types, children)
    return content_tag :div, '', :style => "clear:right" if children_types.blank?
    content_tag :div, :class => "children header_block discuss_right_block" do
      content = ''

      # Load variables
      children_to_render = {}
      headers = []
      selected = nil
      children_types.each_with_index do |child_type, index|
        dom_child_type = child_type.to_s.underscore
        arg = children[child_type]
        if arg.kind_of?(Integer)
          count = arg
        else
          selected = index if selected.nil?
          count = child_type.to_s.constantize.double? ? arg.map(&:total_entries).sum : arg.total_entries
          children_to_render[dom_child_type] = arg
        end
        headers << [dom_child_type, count]
      end
      headers

      # Load headers
      content << content_tag(:div, :class => "headline expandable") do
        header_content = ''
        headers.each_with_index do |h, i|
          header_content << children_heading_title(h[0],h[1],
                            :path => children_statement_node_url(statement_node, :type => h[0]),
                            :selected => i==selected)
        end
        header_content << content_tag(:span, '', :class => 'loading', :style => 'display: none')
        header_content << content_tag(:div, '', :class => 'expand_icon')
        header_content
      end

      # load children
      content << content_tag(:div, :class => 'children_content expandable_content') do
        children_content = ''
        headers.each_with_index do |h, index|
          children_content << render(:partial => h[0].classify.constantize.children_list_template,
                                     :locals => {:child_type => h[0],
                                                 :children => children_to_render[h[0]],
                                                 :parent => @statement_node,
                                                 :display => index==0,
                                                 :new_level => true}) if children_to_render[h[0]]
        end
        children_content
      end
      content
    end
  end


  #
  # Renders all the actions shown in the action panel on the left.
  #
  def render_statement_actions(statement_node, opts={})
    opts[:class] ||= ""
    opts[:class] << ' statement_actions'
    content_tag :div, opts  do
      actions = ""
      actions << content_tag(:div, :class => "add_new_container") do
        render_add_new_button(statement_node, params[:origin], params[:bids])
      end

      actions << content_tag(:div, :class => "actions_container") do
        buttons = ''
        buttons << content_tag(:div, :class => "embed_button_container") do
          render_statement_embed_button(statement_node)
        end
        buttons << content_tag(:div, :class => "copy_url_container") do
          render_copy_url_button(statement_node)
        end
        buttons
      end

      if current_user and current_user.may_delete?(statement_node)
        actions << delete_statement_node_link(statement_node)
      end
      actions
    end
  end


  #
  # Renders the embed echo button into the action panel of discuss search.
  #
  def render_discuss_search_embed_button
    content = ""
    content << content_tag(:a, :id => 'embed_link', :class => 'big_action_button') do
      link_content = ''
      link_content << content_tag(:span, '', :class => "embed_icon")
      link_content <<  content_tag(:span, I18n.t("discuss.statements.embed_button"), :class => 'label')
      link_content
    end
    content << render_embed_panel(discuss_search_url(:mode => :embed, :search_terms => params[:search_terms]), 'search',
                                  discuss_search_url(:mode => 'embed-func', :search_terms => params[:search_terms]))
  end


  #
  # Creates a link to embed echo with the given statement node as entry point into the system.
  #
  def render_statement_embed_button(statement_node)
    app_url = statement_node_url(statement_node, :locale => I18n.locale, :mode => :embed)
    func_url = statement_node_url(statement_node, :locale => I18n.locale, :mode => 'embed-func')
    content = ""
    content << link_to(I18n.t("discuss.statements.embed_button"), '#',
                       :class => 'embed_button text_button')
    content << render_embed_panel(app_url, 'statement', func_url)
    content
  end

  def iframe(url, height)
    return %Q{<iframe src="#{url}" width="100%" height="#{height}px" frameborder="0"></iframe>}
  end


  #
  # Renders the embed statement panel to copy the embed code for the currently displayed statement.
  #
  def render_embed_panel(embed_app_url, mode, embed_func_url=nil)
    embed_app_code = iframe(embed_app_url, 4000)
    embed_func_code = embed_func_url ? iframe(embed_func_url, 600) : nil
    content_tag(:div,
                :class => 'embed_panel popup_panel',
                :style => "display:none") do
      panel = ''
      panel << content_tag(:div, I18n.t("discuss.statements.embed_#{mode}_title_app"), :class => 'panel_header')
      panel << content_tag(:div, I18n.t("discuss.statements.embed_#{mode}_hint"))
      panel << content_tag(:div, h(embed_app_code), :class => 'embed_code')
      panel << "<br/>"
      if embed_func_code
        panel << content_tag(:div, I18n.t("discuss.statements.embed_#{mode}_title_func"), :class => 'panel_header')
        panel << content_tag(:div, I18n.t("discuss.statements.embed_#{mode}_hint"))
        panel << content_tag(:div, h(embed_func_code), :class => 'embed_code')
      end
      panel
    end
  end


  #
  # Creates the button to pop up the Copy URL panel.
  #
  def render_copy_url_button(statement_node)
    url = statement_node_url(statement_node, :mode => :platform)

    content = ""
    content << link_to(I18n.t("discuss.statements.copy_url"), '#',
                       :class => 'copy_url_button text_button')
    content << render_copy_url_panel(url)
    content
  end

  #
  # Renders the Copy URL panel to copy the statement URL into the clipboard.
  #
  def render_copy_url_panel(url)
    content_tag(:div, :class => 'copy_url_panel popup_panel',
                      :style => "display: none") do
      panel = ''
      panel << content_tag(:div, :class => 'panel_header') do
        I18n.t("discuss.statements.copy_url_title")
      end
      panel << content_tag(:div, I18n.t('discuss.statements.copy_url_hint'), :class => '')
      panel << content_tag(:div, h(url), :class => 'statement_url')
      panel
    end
  end


  #########
  # Links #
  #########

  #
  # Creates a link to create a new child statement of a given type for the current statement
  # (appears INSIDE of the children statements panel).
  #
  def create_new_child_statement_link(statement_node, child_type, opts={})
    url = opts.delete(:url) if opts[:url]
    css = opts.delete(:css) if opts[:css]
    label_type = opts.delete(:label_type) || child_type
    link_to(I18n.t("discuss.statements.create_#{label_type}_link"),
            url ? url : new_statement_node_url(statement_node.nil? ? nil : statement_node.target_id,child_type, opts),
            :class => "#{css} add_new_button text_button create_#{label_type}_button ttLink no_border",
            :title => I18n.t("discuss.tooltips.create_#{label_type}"))
  end

  def create_new_question_link(origin=@origin, opts={})
    type = 'question'
    parent = nil
    if !origin.blank?
      key = origin[0, 2]
      parent = case key
        when 'ds', 'sr', 'mi' then nil
        when 'fq' then type = 'follow_up_question'
                       origin[2..-1]
      end
    end
    url = parent.nil? ? new_question_url(:bids => origin, :origin => origin) : new_statement_node_url(parent, type)
    create_new_child_statement_link(parent, type, opts.merge({:url => url}))
  end


  def add_create_new_statement_button(statement_node, type, opts={})
    if statement_node.nil? # only for siblings; there ain't no child question creation possibility; hence, no new_level param is given
       content_tag :li, create_new_question_link(params[:origin], opts)
    else
       content_tag :li, create_new_child_statement_link(statement_node, type, opts)
    end
  end

  #
  # Generates the 'New Statement' panel in the action panel.
  #
  def render_add_new_button(statement_node, origin = nil, bids = nil)
    content = ''
    content << content_tag(:div, :class => 'new_statement_button big_action_button') do
      button = ''
      button << content_tag(:span, '', :class => 'add_new_button_icon')
      button << content_tag(:span, I18n.t('discuss.statements.add_new'),
                            :class => 'label')
      button
    end
    wide = statement_node.is_a?(Proposal) ? ' wide' : ''
    content << content_tag(:div, :class => "add_new_panel#{wide} popup_panel",
                           :style => "display:none") do
      panel = ''
      panel << content_tag(:div, :class => 'panel_header') do
        I18n.t("discuss.statements.add_new")
      end
      panel << content_tag(:div, '', :class => 'block_separator')
      panel << add_new_sibling_buttons(statement_node, origin)
      panel << add_new_child_buttons(statement_node)
      panel << add_new_default_child_button(statement_node)
      panel
    end
    content
  end

  #
  # Creates a link to add a new sibling for the given statement (appears in the SIDEBAR).
  #
  def add_new_sibling_buttons(statement_node, origin = nil)
    content = ''
    content << content_tag(:div, :class => 'siblings container') do
      buttons = ''
      if statement_node.parent_node
        buttons << add_new_sibling_button(statement_node) if !alternative_mode?(statement_node)
      else
        if origin.blank?
          buttons << add_new_question_button(!origin.blank? ? origin : nil)
        elsif %w(ds mi sr jp dq).include? origin[0,2] # create new question
          buttons << add_new_question_button(!origin.blank? ? origin : nil) if !origin[0,2].eql? 'dq'
        else # create sibling follow up question
          context_type = ''
          context_type << case origin[0,2]
            when 'fq' then "follow_up_question"
          end

          buttons << content_tag(:a, :href => new_statement_node_url(origin[2..-1],
                                                                     context_type,
                                                                     :origin => origin),
                                 :class => "create_#{context_type}_button_32 resource_link new_statement ttLink no_border",
                                 :title => I18n.t("discuss.statements.siblings.#{context_type}")) do
            statement_icon_title(I18n.t("discuss.statements.siblings.#{context_type}"))
          end
        end
      end

      # New alternative Button TODO: this is going to the logic above, in the future
      if statement_node.class.has_alternatives?
        buttons << content_tag(:a, :href => new_statement_node_url(statement_node.target_id,
                                                                   statement_node.class.alternative_types.first.to_s.underscore,
                                                                   :hub => "al#{statement_node.target_id}",
                                                                   :bids => params[:bids],
                                                                   :origin => origin),
                               :class => "create_alternative_button_32 resource_link new_statement ttLink no_border",
                               :title => I18n.t("discuss.tooltips.create_alternative")) do
          statement_icon_title(I18n.t("discuss.statements.types.alternative"))
        end
        if alternative_mode?(statement_node) and @discuss_alternatives_question.nil?
          buttons << add_new_child_link(statement_node, "discuss_alternatives_question", :nl => true, :bids => params[:bids], :origin => params[:origin])
        end
      end
      buttons
    end
    content << content_tag(:div, '', :class => 'block_separator')
    content
  end

  #
  # Creates a link to add a new sibling for the given statement (appears in the SIDEBAR).
  #
  def add_new_sibling_button(statement_node)
    content = ''
    statement_node.class.sub_types.map.each do |sub_type|
      sub_type = sub_type.to_s.underscore
      content << content_tag(:a, :href => new_statement_node_url(@parent_node || statement_node.parent_node, sub_type),
                             :class => "create_#{sub_type}_button_32 resource_link new_statement ttLink no_border",
                             :title => I18n.t("discuss.tooltips.create_#{sub_type}")) do
        statement_icon_title(I18n.t("discuss.statements.types.#{sub_type}"))
      end
    end
    content
  end

  #
  # Creates a link to add a new child for the given statement (appears in the SIDEBAR).
  #
  def add_new_child_buttons(statement_node)
    children_types = statement_node.class.children_types(:expand => true)
    return '' if children_types.empty?
    content = ''
    content << content_tag(:div, :class => 'container') do
      children = ''
      children_types.each do |type|
        children << add_new_child_link(statement_node, type.to_s.underscore)
      end
      children
    end
    content << content_tag(:div, '', :class => 'block_separator')
    content
  end

  #
  # Creates a link to add a new default child (follow up question, background info) for the given statement (appears in the SIDEBAR).
  #
  def add_new_default_child_button(statement_node)
    content_tag(:div, :class => 'container') do
      content = ''
      statement_node.class.default_children_types(:visibility => false).each do |default_type|
        dom_type = default_type.to_s.underscore
        content << add_new_child_link(statement_node,
                                      dom_type,
                                      :bids => params[:bids],
                                      :origin => params[:origin])
      end
      content
    end
  end

  #
  # Returns a link to create a new child statement from a given type for the given statement (appears in the SIDEBAR).
  #
  def add_new_child_link(statement_node, type, opts={})
    opts[:nl] = true
    content = ''
    content << content_tag(:a, :href => new_statement_node_url(statement_node, type, opts),
                           :class => "create_#{type}_button_32 resource_link new_statement ttLink no_border",
                           :title => I18n.t("discuss.tooltips.create_#{type}")) do
      statement_icon_title(I18n.t("discuss.statements.types.#{type}"))
    end
    content
  end

  #
  # Creates a link to edit the current document.
  #
  def edit_statement_node_link(statement_node, statement_document)
    if current_user and current_user.may_edit?(statement_node)
      link_to(I18n.t('application.general.edit'),
              edit_statement_node_url(statement_node,
                                      :current_document_id => statement_document.id,
                                      :cs => params[:cs]),
              :class => 'ajax header_button text_button edit_text_button')
    else
      ''
    end
  end

  #
  # Creates a link to show the authors of the current node.
  #
  def authors_statement_node_link(statement_node)
    link_to(I18n.t('application.general.authors'),
            authors_statement_node_url(statement_node),
            :class => 'expandable header_button text_button authors_text_button')
  end

  #
  # Render the list of authors.
  #
  def render_authors(statement_node, user, authors)
    content_tag(:ul, :class => 'authors_list') do
      content = ''
      content << render(:partial => 'statements/author', :collection => authors)
      content << author_teaser(statement_node, user) if statement_node.draftable? and !authors.include?(user)
      content
    end
  end

  #
  # Creates a teaser for authors with author styling.
  #
  def author_teaser(statement_node, user)
    content_tag :li, :class => 'author teaser' do
      content = ''
      content << image_tag(user.avatar.url(:small), :alt => '')
      content << content_tag(:span, I18n.t('users.authors.teaser.title'), :class => 'name')
      content << create_new_child_statement_link(statement_node, 'improvement', :nl => true, :css => "new_statement")
      content
    end
  end

  #
  # Creates a link to delete the current statement.
  #
  def delete_statement_node_link(statement_node)
    link_to I18n.t('discuss.statements.delete_link'),
            statement_node_url(statement_node),
            :class => 'admin_action',
            :method => :delete,
            :confirm => I18n.t('discuss.statements.delete_confirmation')
  end

  #
  # Loads the function buttons of the current statement (edit, authors).
  #
  def function_buttons(statement_node, statement_document)
    val = ''
    val << edit_statement_node_link(statement_node, statement_document)
    val << publish_statement_node_link(statement_node, statement_document) if statement_node.publishable?
    val << authors_statement_node_link(statement_node)
    content_tag :span, val, :class => 'action_buttons'
  end

  #
  # Returns the block heading for the children of the current statement node.
  #
  def children_heading_title(type, count, opts={})
    content_tag :a, :href => opts[:path],
                    :type => type.pluralize,
                    :class => "#{type.pluralize} child_header #{'selected' if opts[:selected]}" do
      content_tag :div, :class => "header_content" do
        title = ''
        title << content_tag(:span, I18n.t("discuss.statements.headings.#{type}"), :class => 'type')
        title << content_tag(:span, " (#{count})", :class => 'count')
        title
      end
    end
  end

  #
  # Returns the block heading for the siblings of the current statement node.
  #
  def sibling_box_title(type)
    content_tag :span, I18n.t("discuss.statements.headings.#{@hub_type || type}", :type => type), :class => 'label'
  end

  #
  # Creates the cancel button in the new statement form (right link will be handled in jquery).
  #
  def cancel_new_statement_node
    link_to I18n.t('application.general.cancel'),
            :back,
            :class => 'cancel text_button cancel_text_button'
  end

  #
  # Creates the cancel button in the edit statement form.
  #
  def cancel_edit_statement_node(statement_node, locked_at)
    link_to I18n.t('application.general.cancel'),
            cancel_statement_node_url(statement_node,
                                      :locked_at => locked_at.to_s,
                                      :cs => params[:cs]),
           :class => "text_button cancel_text_button ajax"
  end

  def title_hint_text(statement_node)
    I18n.t("discuss.statements.title_hint.#{node_type(statement_node)}")
  end

  def summary_hint_text(statement_node)
    text = ""
    text << I18n.t("discuss.statements.text_hint.alternative_prefix") if params[:hub].present? and params[:hub].start_with? 'al'
    text << I18n.t("discuss.statements.text_hint.#{node_type(statement_node)}")
    text
  end

  ##############
  # Sugar & UI #
  ##############

  def node_type(statement_node)
    @statement_type ||= {}
    @statement_type[statement_node.level] ||= statement_node.new_record? ? @statement_node_type.name.underscore :
                                                                           dom_class(statement_node.target_statement)
  end


  #
  # Loads the right add statement image.
  #
  def statement_form_illustration(statement_node)
    image_tag("page/discuss/add_#{node_type(statement_node)}_big.png",
              :class => 'statement_form_illustration')
  end

  #
  # Returns the right icon for a statement_node, determined from statement_node class and given size.
  #
  def statement_node_icon(statement_node, size = :medium)
    # remove me to have different sizes again
    image_tag("page/discuss/#{node_type(statement_node)}_#{size.to_s}.png")
  end

  #
  # Returns the context menu link for this statement_node.
  #
  def statement_node_context_link(statement_node, title, action = 'read', opts={})
    css = String(opts.delete(:css))
    css << " #{statement_node.info_type.code}_link" if statement_node.class.has_embeddable_data?
    link_to(statement_node_url(statement_node, opts),
            :class => "#{css} no_border statement_link #{node_type(statement_node)}_link ttLink",
            :title => I18n.t("discuss.tooltips.#{action}_#{node_type(statement_node)}")) do
      statement_icon_title(title)
    end
  end

  #
  # Render the hint on the new statement forms for users with no spoken language defined.
  #
  def define_languages_hint
    content_tag :p, I18n.t('discuss.statements.statement_language_hint', :url => my_profile_url),
                :class => 'ttLink no_border',
                :title => I18n.t('discuss.statements.statement_language_hint_tooltip')
  end

  #
  # Render the hint on the new draftable statement forms to warn about drafting language on collective text creation.
  #
  def drafting_language_hint
    content_tag :p, I18n.t('discuss.statements.drafting_language_hint')
  end

  def top_statement_hint
    content_tag :p, I18n.t("discuss.statements.fuq_formulation_hint")
  end

  #
  # Render the hint on the edit statement forms to warn about the time the users have to edit it.
  #
  def edit_period_hint
    content = ''
    content << content_tag(:li, :class => 'hint') do
      content_tag :p, I18n.t('discuss.statements.edit_period_hint', :minutes => 60)
    end
    content
  end


  ##############
  # Navigation #
  ##############

  #
  # Renders prev/next/siblings buttons for the current statement_node.
  #
  def navigation_buttons(statement_node, type, opts={})
    buttons = ''
    if statement_node and
      (opts[:form] or (!opts[:origin].blank? and opts[:origin][0,2].eql?('dq') and statement_node.level.eql?(0)))
      %w(prev next).each{|button| buttons << statement_tag(button.to_sym, type, true)}
      buttons << content_tag(:span,
                             I18n.t("discuss.statements.sibling_labels.#{type.classify.constantize.name_for_siblings}"),
                             :class => 'show_siblings_label disabled')
    else
      buttons << content_tag(:span, '', :class => 'loading', :style => 'display:none')
      %w(prev next).each do |button|
        buttons << statement_button(statement_node,
                                    statement_tag(button.to_sym, type),
                                    type,
                                    :rel => button,
                                    :class => " statement_link #{opts[:classes]} #{button}")
      end
      buttons << siblings_button(statement_node, type, opts)
    end
    buttons
  end

  def siblings_button(statement_node, type = node_type(statement_node), opts={})
    origin = opts[:origin]
    if alternative_mode?(statement_node)
      sib = statement_node
      name = "alternative"
      alternative_type = type.classify.constantize.name_for_siblings
    end
    name ||= type.classify.constantize.name_for_siblings
    url = if statement_node.nil? or statement_node.u_class_name != type # ADD TEASERS
      if statement_node.nil?
        question_descendants_url(:origin => origin)
      else
        parent = sib || (@current_stack ? @current_stack[@current_stack.length - 2] : statement_node)
        descendants_statement_node_url(parent, name, :alternative_type => alternative_type)
      end
    else  # STATEMENT NODES

      if statement_node.parent_id.nil?
        question_descendants_url(:origin => origin, :current_node => statement_node)
      else
        prev = sib ||
               (@current_stack ?
               StatementNode.find(@current_stack[@current_stack.index(statement_node.id)-1], :select => "id, lft, rgt, question_id") :
               statement_node.parent_node)

        descendants_statement_node_url(prev,
                                       name,
                                       :current_node => statement_node,
                                       :alternative_type => alternative_type,
                                       :hub => (alternative_mode?(statement_node) ? "al#{statement_node.target_id}" : nil))
      end
    end

    content_tag(:a,
                :href => url,
                :class => 'show_siblings_button expandable') do
      content_tag(:span, I18n.t("discuss.statements.sibling_labels.#{alternative_mode?(statement_node) ? alternative_type : name}"),
                  :class => 'show_siblings_label ttLink no_border',
                  :title => I18n.t("discuss.tooltips.siblings.#{name}"))
    end
  end

  #
  # Renders the correct prev/next image buttons.
  #
  def statement_tag(direction, class_identifier, disabled=false)
    if !disabled
      content_tag(:span, '&nbsp;',
                  :class => "#{direction}_stmt ttLink no_border",
                  :title => I18n.t("discuss.tooltips.#{direction}_#{class_identifier}"))
    else
      content_tag(:span, '&nbsp;',
                  :class => "#{direction}_stmt disabled")
    end
  end

  #
  # Inserts a button that links to the previous statement_node.  #
  # IMP NOTE: siblings always include the teaser at the end, so always be careful when handling it
  #
  def statement_button(statement_node, title, type, options={})
    options[:class] ||= ''
    teaser = options[:class].include? 'add'
    url_opts = {:origin => params[:origin], :bids => params[:bids]}
    # if prev/next for teaser
    unless @siblings.nil?
      if teaser
        if (siblings = @siblings["add_#{@type}"])
          element_index = siblings.index { |s| s =~ /#{@type}/ }
        end
      else # if prev/next for statement
        if (siblings = @siblings[dom_id(statement_node)])
          element_index = siblings.index(statement_node.id)
        end
      end
      unless siblings.nil?
        element_index = 0 if element_index.nil?
        index = element_index
        if options[:rel].eql? 'prev'
          index = element_index - 1
        elsif options[:rel].eql? 'next'
          index = element_index + 1
        end
        index = index < 0 ? (siblings.length - 1) : (index >= siblings.length ? 0 : index )

        url = !(siblings[index].to_s =~ /add/).nil? ? add_teaser_statement_node_path(statement_node,url_opts) :
                                                      statement_node_url(siblings[index], url_opts)
      end
    else
      url = add_teaser_statement_node_path(statement_node)
    end
    options['data-id'] =
      teaser ? "#{statement_node.nil? ? '' : "#{statement_node.id}_"}add_#{type}" : statement_node.id
    return link_to(title, url, options)
  end

  def add_teaser_statement_node_path(statement_node, opts={})
    if statement_node.nil? or statement_node.level == 0
      add_question_teaser_url(opts)
    else
      add_teaser_url(statement_node.parent_node, opts.merge(:type => dom_class(statement_node)))
    end
  end


  #
  # Loads the link to a given statement, placed in the child panel section.
  #
  def link_to_child(title, statement_node,opts={})
    opts[:type] ||= dom_class(statement_node) #TODO: This forced op must be deleted when alternatives navigation/breadcrumb are available
    # BIDS
    bids = params[:bids] || ''
    if opts[:nl]
      bids = bids.split(",")
      bid = "#{Breadcrumb.instance.generate_key(opts[:type])}#{@statement_node.target_id}"
      bids << bid
      bids = bids.join(",")
    end

    # AL
    al = @alternative_modes || []
    level = @current_stack.nil? ? statement_node.level : @current_stack.index(statement_node.id)
    al << level if opts[:alternative_link] and (@alternative_modes.nil? or !@alternative_modes.include?(@level))
    al = al.join(",")

    content = link_to(statement_icon_title(title),
                      statement_node_url(statement_node.target_id,
                                         :bids => bids,
                                         :origin => params[:origin],
                                         :nl => opts[:nl],
                                         :al => al),
                      :class => "statement_link #{opts[:type]}_link #{opts[:css]}")
    content += supporter_ratio_bar(statement_node)
    content
  end


  #
  # Creates a statement link with icon and title.
  #
  def statement_icon_title(title)
    link = content_tag(:span, '&nbsp;', :class => 'icon')
    link += content_tag(:span, h(title), :class => 'title')
    link
  end


  #
  # Draws the statement image container.
  #
  def statement_image(statement_node)
    val = ""
    editable = (current_user and current_user.may_edit?(statement_node))
    if statement_node.image.exists? or editable
      val << image_tag(statement_node.image.url(:medium), :class => 'image')
      if editable
        val << link_to(I18n.t('users.profile.picture.upload_button'),
                       edit_statement_image_url(statement_node.statement_image, statement_node),
                       :class => 'ajax upload_link button button_150')
      end
    end
    content_tag :div, val, :class => "image_container #{editable ? 'editable' : ''}" if !val.blank?
  end

  #
  # Renders the "more" link when the statement is loaded.
  #
  def more_children(statement_node,opts={})
    opts[:page] ||= 0
    link_to I18n.t("application.general.more"),
            more_statement_node_url(statement_node, :page => opts[:page].to_i+1,
                                                    :type => opts[:type],
                                                    :bids => params[:bids],
                                                    :origin => params[:origin],
                                                    :hub => opts[:hub],
                                                    :nl => opts[:new_level]),
            :class => 'more_children'
  end


  def render_alternative_types(statement_node, statement_types, selected=statement_types.first)
    if statement_types.length > 1
      render_statement_types_radio_buttons(statement_types, selected)
    else
      hidden_field_tag :type, node_type(statement_node)
    end
  end

  def render_statement_types_radio_buttons(statement_types, selected=statement_types.first)
   content = ""
   statement_types.each do |statement_type|

     content << radio_button_tag(:type, statement_type, statement_type.eql?(selected),
                                 :class => "statement_type")
     content << label_tag(statement_type, I18n.t("discuss.statements.types.#{statement_type}"),
                          :class => "statement_type_label")
   end
   content
  end

  ###############
  # BREADCRUMBS #
  ###############

  #
  # Renders the given breadcrumbs.
  #
  def render_breadcrumb(breadcrumbs)
    breadcrumb_trail = ""
    breadcrumbs.each_with_index do |b, index| #[key, classes, url, title, label, over, page_co]
      attrs = {}
      attrs[:page_count] = b[:page_count] if b[:page_count]
      breadcrumb = content_tag(:a, attrs.merge({:href => b[:url],
                                                :id => b[:key],
                                                :class => "breadcrumb #{b[:key][0..2]}"})) do
        content = ""
        content << content_tag(:span, '', :class => 'delimiter') if index != 0
        content << content_tag(:span, b[:label], :class => 'label')
        content << content_tag(:span, b[:over], :class => 'over')
        content << content_tag(:div, '', :class => b[:css]) do
          link = ""
          link << content_tag(:span, '', :class => 'icon')
          link << content_tag(:span, h(Breadcrumb.instance.decode_terms(b[:title])), :class => 'title')
          link
        end
        content
      end
      breadcrumb_trail << breadcrumb
    end
    breadcrumb_trail
  end

  ################
  # ALTERNATIVES #
  ################

  def render_alternatives(statement_node, children)
    render :partial => 'statements/alternatives',
             :locals => {:statement_node => statement_node,
                         :alternatives => children}
  end

  def close_alternative_mode_button(statement_node)
    # BIDS
    bids = params[:bids] || ''
    bids = bids.split(",")
    bids.pop
    bids = bids.join(",")
    # AL
    al = @alternative_modes - [@level]

    link_to '', statement_node_url(statement_node,
                                    :bids => bids,
                                    :origin => params[:origin],
                                    :al => al.join(",")),
            :class => "alternative_close ttLink no_border",
            :title => I18n.t("discuss.tooltips.close_alternative_mode")
  end

  #
  # Returns the block heading for the alternative tag on the alternative header
  #
  def alternative_header_box_title
    content_tag :span, "#{I18n.t("discuss.statements.headings.alternative")}", :class => 'label'
  end

  def create_discuss_alternatives_question_link(statement_node)
    create_new_child_statement_link(statement_node, "discuss_alternatives_question", :css => "new_statement", :nl => true, :origin => params[:origin], :bids => params[:bids])
  end

  def alternative_mode?(statement_node_or_level)
    return true if !params[:hub].blank?
    return false if statement_node_or_level.nil?
    index = statement_node_or_level.kind_of?(Integer) ? statement_node_or_level :
            (@current_stack ? @current_stack.index(statement_node_or_level.id) : statement_node_or_level.level)
    @alternative_modes and
    @alternative_modes.include?(index)
  end

  ####################
  # BACKGROUND INFOS #
  ####################


  def render_embedded_content(background_info)
    content_tag(:div, :class => 'embed_container') do
      content = ''
      content << content_tag(:a, I18n.t('discuss.statements.open_embedded_content'),
                             :href => background_info.external_url.info_url,
                             :class => "embedded_content_button",
                             :target => "_blank")
      content << content_tag(:span, '', :class => 'loading')
      content << content_tag(:a, '',
                             :href => background_info.external_url.info_url,
                             :class => 'embed_placeholder')
      content
    end
  end

  #
  # This class does the heavy lifting of actually building the pagination
  # links. It is used by the <tt>will_paginate</tt> helper internally.
  #
  class MoreRenderer < WillPaginate::LinkRenderer
    def to_html
      html = page_link_or_span(@collection.next_page, 'disabled more_children', @options[:next_label])
      html = html.html_safe if html.respond_to? :html_safe
      @options[:container] ? @template.content_tag(:div, html, html_attributes) : html
    end
  end

end

