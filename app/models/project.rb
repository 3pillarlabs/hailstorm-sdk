class Project < ActiveRecord::Base
  validates :title, presence: true
  validates :title, uniqueness: true
end
