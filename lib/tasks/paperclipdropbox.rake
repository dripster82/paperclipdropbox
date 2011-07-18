require "yaml"
require "dropbox"

namespace :paperclipdropbox do
	

	desc "Get User Authorise URL"
	task :authorize => :environment do
		
		SESSION_FILE = "#{Rails.root}/config/dropboxsession.yml"
		
		if File.exists?(SESSION_FILE)
			@dropboxsession = Dropbox::Session.deserialize(File.read(SESSION_FILE))
		else
			@options = (YAML.load_file("#{Rails.root}/config/paperclipdropbox.yml")[Rails.env].symbolize_keys)
			
			@dropbox_user = @options[:dropbox_user]
			@dropbox_password = @options[:dropbox_password]
			@dropbox_key = '8ti7qntpcysl91j'
			@dropbox_secret = 'i0tshr4cpd1pa4e'
			
			@dropboxsession = Dropbox::Session.new(@dropbox_key, @dropbox_secret)
			@dropboxsession.mode = :dropbox
			@dropboxsession.authorizing_user = @dropbox_user
			@dropboxsession.authorizing_password = @dropbox_password
		end
		begin
			@dropboxsession.authorize!
			
			puts "Authorized - #{@dropboxsession.authorized?}"
		rescue
			begin
				puts "Please login to dropbox using this link : #{@dropboxsession.authorize_url}"
				puts "then run this rake task again."
			rescue
				puts "Already Authorized - #{@dropboxsession.authorized?}"
			end
		end
		
		File.open(SESSION_FILE, "w") do |f|
			f.puts @dropboxsession.serialize
		end
	end

end