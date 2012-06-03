class Project::YouthDetail < ProjectDetail
  
  INSPECTION_TITLE = "Bike Overhaul Inspection"

  has_one :inspection, :class_name=>'ResponseSet', :as => :surveyable_process

  state_machine :initial => :under_repair do

    before_transition do |proj_detail|
      if proj_detail.proj.open?
        true
      else
        proj_detail.errors.add(:action_unallowed, "Project is closed")
        throw :halt
        false
      end
    end

    after_transition (any-:done) => :done, :do => "proj.close"
    after_transition (any-:inspected) => :inspected, :do => :start_inspection_action

    event :mark_for_inspection do
      transition :under_repair => :ready_to_inspect
    end

    event :start_inspection do
      transition :ready_to_inspect => :inspected
    end

    event :resume_inspection do
      transition :inspected => :inspected
    end

    event :pass_inspection do
      transition :inspected => :ready_for_program, :if => :pass_inspection?
    end

    event :fail_inspection do
      transition :inspected => :under_repair, :if => :fail_inspection?
    end

    event :reinspect do
      transition [:ready_for_program, :class_material] => :inspected
    end

    event :select_for_class do
      transition :ready_for_program => :class_material
    end

    event :remove_from_class do
      transition :class_material => :ready_for_program
    end
    
    event :finish do
      transition :class_material => :done, :if => :pass_req?
      #transition :class_material => :done, :if => current_user.admin?
    end

    state :under_repair
    state :ready_to_inspect
    state :inspected do
      def process_hash
        h = {:controller => :surveyor, :action => :edit,
          :survey_code => self.class.inspection_survey_code,
          :response_set_code => self.inspection_access_code}
      end
    end
    state :ready_for_program
    state :class_material
    state :done

  end

  def pass_req?
    self.class_material?
  end

  def pass_inspection?
    # Inspection is complete and all checks pass
    inspection.reload
    inspection_complete? && inspection.correct?
  end

  def fail_inspection?
    # Inspection is complete but not all checks pass
    # FIXME OLD INSPECTION Messes this up
    inspection.reload
    inspection_complete? && ! inspection.correct? 
  end

  def inspection_complete?
    inspection && inspection.mandatory_questions_complete?
  end

  # TODO Modularize inspection logic in a mixin

  def surveyable_context
    proj
  end

  private

  def self.inspection_survey_code
    survey = SurveyorUtil.find(INSPECTION_TITLE)
    survey.access_code if survey
  end

  def start_inspection_action
    # If an inspection already exists, remove it
    self.inspection = nil
    self.inspection_access_code = nil
    self.save
    proj.bike.inspection = nil
    proj.bike.save

    # Find the right survey to use
    @survey = SurveyorUtil.find(INSPECTION_TITLE)
    
    if @survey
      # Build the response set
      uid ||= @current_user.id if @current_user
      @response_set = ResponseSet.create(:survey => @survey, 
                                       :user_id => uid,
                                       :surveyable_type => self.proj.bike.class.to_s,
                                       :surveyable_id => self.proj.bike.id,
                                       :surveyable_process_type => self.class.to_s,
                                       :surveyable_process_id => self.id)
      if @response_set
        # Assign to this project
        self.inspection_access_code = @response_set.access_code
        self.save
      end
    end

    # Error and stop transition if the inspection can not be made?
  end

end
# == Schema Information
#
# Table name: project_youth_details
#
#  id                     :integer         not null, primary key
#  proj_id                :integer
#  proj_type              :string(255)
#  state                  :string(255)
#  created_at             :datetime        not null
#  updated_at             :datetime        not null
#  inspection_access_code :string(255)
#

