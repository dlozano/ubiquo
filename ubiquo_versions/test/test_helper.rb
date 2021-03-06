# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require File.expand_path("../dummy/config/application.rb",  __FILE__)
require 'ubiquo/test/test_helper'

# Run any available migration
ActiveRecord::Migrator.migrate File.expand_path("../../install/db/migrate/", __FILE__)

class ActiveSupport::TestCase
  def self.create_ar_test_backend_for_versionable
    return if @versionable_backend_created
    silence_stderr do
      # Creates a test table for AR things work properly
      if ActiveRecord::Base.connection.tables.include?("test_versionable_models")
        ActiveRecord::Base.connection.drop_table :test_versionable_models
      end
      ActiveRecord::Base.connection.create_table :test_versionable_models, :versionable => true do |t|
        t.string :my_field
      end
    end
    @versionable_backend_created = true
  end

  def set_test_model_as_versionable(options = {})
    TestVersionableModel.class_eval do
      versionable options
      attr_accessible :my_field
    end
  end
end

# Models used to test Versionable extensions
TestVersionableModel = Class.new(ActiveRecord::Base)
TestVersionableModelSubclass = Class.new(TestVersionableModel)
