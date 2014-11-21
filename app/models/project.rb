class Project < ActiveRecord::Base
  has_many :cluster, dependent: :destroy
  has_many :test_plans, dependent: :destroy

  validates :title, presence: true
  validates :title, uniqueness: true

  def self.pagination(current_page, items_per_page)
    self.paginate(page: current_page, per_page: items_per_page).order("updated_at DESC")
  end

end
