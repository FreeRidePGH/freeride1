# == Schema Information
#
# Table name: programs
#
#  id         :integer         not null, primary key
#  title      :string(255)
#  category   :string(255)
#  created_at :datetime
#  updated_at :datetime
#

class Program < ActiveRecord::Base
  
  has_many :projects, :as => :projectable

  validates_presence_of :category
  
end
