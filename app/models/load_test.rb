class LoadTest < ActiveRecord::Base

  belongs_to :project

  scope :reverse_chronological_list, -> { order('started_at DESC') }

  default_scope -> { where(active: true) }

  # @return [String] duration of test in minutes:seconds
  def duration_hms
    if not stopped_at.nil?
      elapsed_seconds = (stopped_at - started_at).to_i
      hh = elapsed_seconds / 3600
      mm = (elapsed_seconds / 60) % 60
      ss = elapsed_seconds % 60
      "#{hh}h:#{mm}m:#{ss}s"
    else
      ''
    end
  end

end