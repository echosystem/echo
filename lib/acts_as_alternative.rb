module ActiveRecord
  module Acts
    module Alternative

      def self.included(base)
        base.extend(ClassMethods)
        base.instance_eval do
          include InstanceMethods
        end
      end

      module InstanceMethods
        def parent_node
          parent
        end
      end

      module ClassMethods

        def has_alternatives?
          false
        end

        def acts_as_alternative(*args)
          args.flatten! if args
          args.compact! if args

          belongs_to :hub, :class_name => 'CasHub', :foreign_key => 'parent_id'

          #TODO: WHEN RAILS ALLOWS THIS TO WORK, PLEASE ACTIVATE THIS RELSHIP: currently fails because the has many
          #      through joins the statement nodes table with itself (correct) without alias (false!).
          #      when all goes well, please update the paginated alternative statements function
          #
          #has_many :alternatives, :through => :hub
          has_many :alternatives,
                   :class_name => "StatementNode",
                   :finder_sql => 'select s.* from statement_nodes s ' +
                                  'LEFT JOIN statement_nodes hubs ON hubs.id = s.parent_id AND hubs.type = \'CasHub\' ' +
                                  'WHERE hubs.id = #{hub.nil? ? -1 : hub.id} AND ' +
                                  's.id != #{id} AND ' +
                                  's.type IN (#{self.class.alternative_types.map{|s|"\"#{s.to_s}\""}})'

          after_create :create_mirror_alternative 
          
          class_eval do
            class << self

              def has_alternatives(klasses)
                @@alternative_types ||= { }
                @@alternative_types[self.name] ||= klasses
              end

              def has_alternatives?
                true
              end

              def alternative_types
                @@alternative_types[self.name]
              end

              def alternative_more_template
                'statements/more'
              end

              def alternative_conditions(opts)
                sanitize_sql([" AND statement_nodes.id IN (?) ", opts[:alternative_ids]])
              end
            end
            
            def create_mirror_alternative
              return if hub.nil? or hub.twin_hub.nil? or ([self.statement_id] - hub.twin_hub.alternatives.map(&:statement_id)).empty?
              
              # if a twin hub exists, then i can assume all my siblings are already mirrored
              
              sibling_alternative = alternatives.first
              mirrored_sibling_alternative = sibling_alternative.statement.statement_nodes.find(:first, :conditions => ["id != ? AND parent_id = ?", sibling_alternative.id, hub.twin_hub_id])
              
              mirrored_type = mirrored_sibling_alternative.class.alternative_types.first
              
              attributes = self.attributes
              # delete attributes that we don't want to transpose
              attributes.delete("created_at")
              attributes.delete("updated_at")
              attributes.delete("lft")
              attributes.delete("rgt")
              attributes.delete("id")
              attributes.delete("type")
              attributes.delete("drafting_state")
              # add the id of the new twin hub as the parent_id
              attributes["parent_id"] = hub.twin_hub_id
              attributes["root_id"] = mirrored_sibling_alternative.root_id
              
              mirrored_type.to_s.constantize.create(attributes)
            end

            def parent_node
              hub.nil? ? parent : hub.parent
            end
            
            def discuss_alternatives_question
              hub ? hub.discuss_alternatives_question : nil
            end
            
            def has_alternative?(node)
              parent_id == node.parent_id
            end

            def paginated_alternatives(page, per_page = nil,opts={})
              alternative_statements = []
              if hub.present?
                alternative_ids = alternatives.map(&:id)
                alternative_ids << target_id if opts[:with_self]
                #TODO: When the support of multiple alternatives is set, we have to rethink this
                alternative_statements = hub.child_statements(opts.merge({:type => self.class.alternative_types.first.to_s,
                                                                                          :alternative_ids => alternative_ids,
                                                                                          :filter_drafting_state => true})).flatten
              end
              
              per_page = alternative_statements.length if per_page.nil? or per_page < 0
              per_page = 1 if per_page.to_i == 0
              alternative_statements.paginate(self.class.base_class.default_scope.merge(:page => page,
                                                                                        :per_page => per_page))
            end

            # Function called on the alternative creation process
            #
            # node_id id of the original statement for which this statement is an alternative
            def move_to_alternatives_hub(node_id)
              alternative = StatementNode.find(node_id)
              if alternative
                hub = alternative.hub
                if hub.nil?
                  hub = CasHub.create(:root_id => alternative.root_id, :parent_id => alternative.parent_id,
                                      :statement => alternative.parent_node.statement, :creator_id => alternative.parent_node.creator_id)
                  alternative.move_to_child_of hub
                end
                self.parent_id = hub.id
              end
            end
          end # --- class_eval
          has_alternatives args
        end
      end
    end
  end
end
