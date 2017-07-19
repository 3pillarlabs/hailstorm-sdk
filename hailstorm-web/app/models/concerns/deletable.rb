module Deletable
  extend ActiveSupport::Concern

  # A project dependency can not be deleted once it has been used in a setup.
  #
  # @return [Boolean] true if the model can be deleted
  def can_delete?
    self.project.partial_configured? ||
        (self.project.ready_start? && self.created_at > self.project.updated_at) ||
        (self.project.configured? && (self.project.load_tests.count == 0 ||
            self.created_at > self.project.most_recent_finished_load_test.stopped_at))
  end
end