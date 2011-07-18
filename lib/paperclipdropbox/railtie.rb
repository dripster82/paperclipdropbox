require 'paperclipdropbox'
require 'rails'
module Paperclipdropbox
  class Railtie < Rails::Railtie
    railtie_name :paperclipdropbox

    rake_tasks do
      load "tasks/paperclipdropbox.rake"
    end
  end
end