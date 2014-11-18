class Project < ActiveRecord::Base
  has_many :test_plans, dependent: :destroy
end
