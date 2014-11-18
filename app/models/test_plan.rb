class TestPlan < ActiveRecord::Base
  belongs_to :project

  has_attached_file :jmx,
                    :path => ":rails_root/public/Jmx_Files/:project_id/:basename.:extension",
                    :url => "/Jmx_Files/:project_id/:basename.:extension"
  validates_attachment_file_name :jmx, :matches => [/jmx\Z/]
  validates :jmx_file_name, :uniqueness => {:scope => :project_id}

end
