module Paperclipdropbox
  require 'paperclipdropbox/railtie' if defined?(Rails)
end

require 'paperclipdropbox/url_generator'

module Paperclip
	module Storage
		module Dropboxstorage
    
			CONFIG_FILE = "/config/paperclipdropbox.yml"

			def self.extended(base)
				require "dropbox_api"
				base.instance_eval do
					@options[:url_generator] = Paperclipdropbox::UrlGenerator
					@url_generator = options[:url_generator].new(self)

          unless @options[:url].to_s.match(/\A:dropdox.com\z/)
						@options[:path] = @options[:path].gsub(/:url/, @options[:url]).gsub(/\A:rails_root\/public\/system\//, "")
          	@options[:url]  = ":dropbox_file_url"
          end
				end

        unless Paperclip::Interpolations.respond_to? :dropbox_file_url
          Paperclip.interpolates(:dropbox_file_url) do |attachment, style|
            attachment.public_url(style)
          end
        end
			end

			def exists?(style = default_style)
				begin
					dropbox_client.get_metadata("/#{path(style)}")
					true
				rescue
					false
				end
			end

			def flush_writes
				share_urls = false
				share_urls = {} unless @queued_for_write.empty?
				@queued_for_write.each do |style, file|
					begin
						dropbox_client.upload_by_chunks "/#{path(style)}", file
						public_url(style)
					rescue
					end
				end
        
        after_flush_writes
        @queued_for_write = {}
			end

			def flush_deletes
				path_styles = styles.keys.push(:original).map {|val| "#{name}_#{val.to_s}"}

				@queued_for_delete.each do |path|
					begin
						
						dropbox_client.delete("/#{path}")
					rescue
					end
				end

				if has_dropbox_share_ids? && !@queued_for_delete.empty?
        	new_share_urls = dropbox_share_ids

        	path_styles.each do |style|
        		new_share_urls.delete(style)
        	end

        	update_dropbox_share_ids(new_share_urls.to_json)if self.instance.persisted?
        end

				@queued_for_delete = []
			end

			def dropbox_share_ids
				begin
        		JSON.parse(self.instance.dropbox_share_ids)
        	rescue
        		{}
        	end
			end

			def update_dropbox_share_ids(value)
				self.instance.update_column(:dropbox_share_ids, value)
			end

			def has_dropbox_share_ids?
				self.instance.has_attribute?(:dropbox_share_ids)
			end

			def public_url(style = default_style)
				if has_dropbox_share_ids?
        	share_urls = dropbox_share_ids

        	return share_urls["#{name}_#{style}"] if share_urls.has_key?("#{name}_#{style}")
        end

				shared_link = @options[:default_url]
				begin
					shared_link = dropbox_client.list_shared_links(path: "/#{path(style)}").links.first.url
				rescue
					shared_link = dropbox_client.create_shared_link_with_settings("/#{path(style)}").url
				end

				if has_dropbox_share_ids?
        	new_share_urls = dropbox_share_ids

		    	new_share_urls["#{name}_#{style}"] = shared_link
        	update_dropbox_share_ids(new_share_urls.to_json)
		    end
				shared_link
			end

			def dropbox_client
					if @_dropbox_client.blank?
						if File.exists?("#{Rails.root}#{CONFIG_FILE}")
							dropbox_config = YAML.load_file("#{Rails.root}#{CONFIG_FILE}")
							authenticator = DropboxApi::Authenticator.new(dropbox_config[:dropbox_key], dropbox_config[:dropbox_secret])
							access_token = OAuth2::AccessToken.from_hash(authenticator, dropbox_config[:access_token])
							@_dropbox_client = DropboxApi::Client.new(
									access_token: access_token,
	  							on_token_refreshed: lambda { |new_token_hash|
	  								dropbox_config = YAML.load_file("#{Rails.root}#{CONFIG_FILE}")
	  								dropbox_config[:access_token] = new_token_hash
										File.open("#{Rails.root}#{CONFIG_FILE}",'w') do |h| 
											h.write dropbox_config.to_yaml
										end
	  							}
  							)
						else
							warn("#{CONFIG_FILE} does not exist\nEnsure you have authorise paperclipdropbox")
						end
					end
				
				@_dropbox_client
			end
		end
	end
end
