module ActsAsDouble

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods

    def double?
      false
    end

    def acts_as_double(*args)
      class_eval do
        class << self

          def double?
            true
          end

          # Setting the sub_types.
          def sub_types
            @@sub_types[self.name] || @@sub_types[self.superclass.name]
          end

          # Setting the sub_types.
          def has_sub_types(klasses)
            @@sub_types ||= { }
            @@sub_types[self.name] ||= []
            @@sub_types[self.name] |= klasses
          end

          def name_for_siblings
            self.superclass.name.underscore
          end
          
          def sibling_types
            [self.name]
          end

          #
          # Overrides normal behaviour. Delegates to sub_types and merges the results.
          #
          def statements_for_parent(opts)
            statements = []
            sub_types.each do |type|
              statements << type.to_s.constantize.get_statements_for_parent(opts)
            end
            statements = merge_statement_lists(statements) if opts[:for_session]
            statements
          end

          #
          # Overrides default behaviour. Returns a template to render both sub_types.
          #
          def children_list_template
            "statements/double/children_list"
          end

          #
          # Overrides default behaviour. Returns a template to render both sub_types.
          #
          def children_template
            "statements/double/children"
          end

          #
          # Overrides default behaviour. Returns a template to render both sub_types.
          #
          def more_template
            "statements/double/more"
          end

          #
          # Overrides default behaviour. Returns a template to render both sub_types.
          #
          def descendants_template
            "statements/double/descendants"
          end

          #
          # Overrides default behaviour.
          #
          def paginate_statements(statements, page, per_page = nil)
            per_page = statements.map(&:length).max if per_page.nil? or per_page < 0
            per_page = 1 if per_page.to_i == 0
            statements.map{|c|c.paginate(default_scope.merge(:page => page, :per_page => per_page))}
          end

          def merge_statement_lists(list)
            min = list.map(&:length).min
            ordered_list = list.map{|s|s.slice(0,min)}.transpose + list.map{|s|s[min..-1]}
            ordered_list.flatten
          end
        end

        #
        # Overrides default behaviour. Collects a filtered list of all siblings statements.
        #
        def siblings_to_session(opts)
          siblings = []
          opts[:type] ||= self.class.to_s
          sibling_statements(opts).map{|s|s.map(&:id)}.each_with_index do |s, index|
            siblings << s + ["/#{self.parent_id.nil? ? '' :
                              "#{self.parent_node.target_id}/"}add/#{self.class.sub_types[index].to_s.underscore}"]
          end
          #order them properly, as you want them to be navigated
          ordered_siblings = self.class.merge_statement_lists(siblings)
          ordered_siblings
        end



      end # --- class_eval

      has_sub_types args

    end
  end
end

