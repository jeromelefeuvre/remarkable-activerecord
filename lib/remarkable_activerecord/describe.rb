module Remarkable
  module ActiveRecord

    def self.after_include(target) #:nodoc:
      target.class_inheritable_reader :describe_subject_attributes, :default_subject_attributes
      target.send :include, Describe
      target.send :extend, Describe::ClassMethods
    end

    # Overwrites describe to provide quick way to configure your subject:
    #
    #   describe Post
    #     should_validate_presente_of :title
    #
    #     describe :published => true do
    #       should_validate_presence_of :published_at
    #     end
    #   end
    #
    # This is the same as:
    #
    #   describe Post
    #     should_validate_presente_of :title
    #
    #     describe "when published is true" do
    #       subject { Post.new(:published => true) }
    #       should_validate_presence_of :published_at
    #     end
    #   end
    #
    # The string can be localized using I18n. An example yml file is:
    #
    #   locale:
    #     remarkable:
    #       active_record:
    #         describe:
    #           each: "{{key}} is {{value}}"
    #           prepend: "when "
    #           connector: " and "
    #
    # You can also call subject attributes to set the default attributes for a
    # subject. You can even mix with a fixture replacement tool:
    #
    #   describe Post
    #     # Fixjour example
    #     subject_attributes { valid_post_attributes }
    #
    #     describe :published => true do
    #       should_validate_presence_of :published_at
    #     end
    #   end
    #
    # You can retrieve the merged result of all attributes given using the
    # subject_attributes instance method:
    #
    #   describe Post
    #     # Fixjour example
    #     subject_attributes { valid_post_attributes }
    #
    #     describe :published => true do
    #       it "should have default subject attributes" do
    #         subject_attributes.should == { :title => 'My title', :published => true }
    #       end
    #     end
    #   end
    #
    module Describe

      module ClassMethods

        # Overwrites describe to provide quick way to configure your subject:
        #
        #   describe Post
        #     should_validate_presente_of :title
        #
        #     describe :published => true do
        #       should_validate_presence_of :published_at
        #     end
        #   end
        #
        # This is the same as:
        #
        #   describe Post
        #     should_validate_presente_of :title
        #
        #     describe "when published is true" do
        #       subject { Post.new(:published => true) }
        #       should_validate_presence_of :published_at
        #     end
        #   end
        #
        # The string can be localized using I18n. An example yml file is:
        #
        #   locale:
        #     remarkable:
        #       active_record:
        #         describe:
        #           each: "{{key}} is {{value}}"
        #           prepend: "when "
        #           connector: " and "
        #
        # See also subject_attributes instance and class methods for more
        # information.
        #
        def describe(*args, &block)
          if described_class && args.first.is_a?(Hash)
            attributes = args.shift

            prepend_with = prepend_subject_description unless self.describe_subject_attributes.blank?
            description = subject_attributes_description(klass, attributes, prepend_with)

            args.unshift(description)

            # Creates an example group, set the subject and eval the given block.
            #
            example_group = super(*args) do
              write_inheritable_hash(:describe_subject_attributes, attributes)
              set_described_subject!
              instance_eval(&block)
            end
          else
            super(*args, &block)
          end
        end

        # Sets default attributes for the subject. You can use this to set up
        # your subject with valid attributes. You can even mix with a fixture
        # replacement tool and still use quick subjects:
        #
        #   describe Post
        #     # Fixjour example
        #     subject_attributes { valid_post_attributes }
        #
        #     describe :published => true do
        #       should_validate_presence_of :published_at
        #     end
        #   end
        #
        def subject_attributes(options=nil, &block)
          write_inheritable_attribute(:default_subject_attributes, options || block)
          set_described_subject!
        end

        def set_described_subject!
          subject {
            record = self.described_class.new
            record.send(:attributes=, subject_attributes, false)
            record
          }
        end

        private

        # Generates a human-readble, translated description
        def subject_attributes_description(target, attributes, prepend = nil)
          connector = subject_description_connector
          prepend ||= connector
          (prepend + humanize_subject_attributes.join(connector)).gsub(/^\s+/, '')
        end

        # Gets the translated connector
        def subject_description_connector
          Remarkable.t("remarkable.active_record.describe.connector", :default => " and ")
        end

        # Gets the translated prepend
        def prepend_subject_description
          Remarkable.t("remarkable.active_record.describe.prepend", :default => "when ")
        end

        # Generates an arry of humanized attribute names and translates them
        def humanize_subject_attributes(target, attributes)
          attributes.inject([]) do |pieces, (key, value)|
            translated_key = if target.respond_to?(:human_attribute_name)
              target.human_attribute_name(key.to_s, :locale => Remarkable.locale)
            else
              key.to_s.humanize
            end

            pieces << Remarkable.t("remarkable.active_record.describe.each",
                                    :default => "{{key}} is {{value}}",
                                    :key => translated_key.downcase, :value => value.inspect)
          end
        end

      end

      # Returns a hash with the subject attributes declared using the
      # subject_attributes class method and the attributes given using the
      # describe method.
      #
      #   describe Post
      #     subject_attributes { valid_post_attributes }
      #
      #     describe :published => true do
      #       it "should have default subject attributes" do
      #         subject_attributes.should == { :title => 'My title', :published => true }
      #       end
      #     end
      #   end
      #
      def subject_attributes
        default = self.class.default_subject_attributes
        default = self.instance_eval(&default) if default.is_a?(Proc)
        default ||= {}

        default.merge(self.class.describe_subject_attributes || {})
      end

    end
  end
end
