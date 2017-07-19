class DataCenter < Cluster

  validates :user_name, :machines, :title, presence: true
  validates_attachment_presence :ssh_identity

  before_validation :remove_empty_machines
  before_save :convert_machines_ary_to_json
  after_find :convert_machines_json_to_ary
  after_rollback :convert_machines_json_to_ary, on: [:update]
  after_validation :convert_machines_json_to_ary, unless: ->(r) { r.errors[:machines].empty? }

  def initialize(*args)
    super
    self.user_name = Rails.configuration.data_center_default_user_name if self.user_name.blank?
    self.machines = [''] if self.machines.nil?
  end

  private

  def remove_empty_machines
    self.machines.select! { |m| not m.blank? } if machines.is_a?(Array)
  end

  def convert_machines_json_to_ary
    self.machines = JSON.parse(machines) unless machines.blank?
    self.machines = [''] if machines.blank?
  end

  def convert_machines_ary_to_json
    self.machines = self.machines.to_json if machines.is_a?(Array)
  end

end