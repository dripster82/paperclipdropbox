module Paperclipdropbox
  require 'paperclipdropbox/railtie' if defined?(Rails)
end

require 'http'
require "dropbox_api"

module Paperclip
	module Storage
		module Dropbox
    
			CONFIG_FILE = "/config/paperclipdropbox.yml"

			def self.extended(base)
				base.instance_eval do
					@options[:escape_url] = false
					app_folder = @options[:app_folder] || 'Paperclip_Dropbox/'
          unless @options[:url].to_s.match(/\A:dropdox.com\z/)
						@options[:path] = app_folder + @options[:path].gsub(/:url/, @options[:url]).gsub(/\A:rails_root\/public\/system\//, "")
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
						public_url(style, file.size)
					rescue
					end
				end
        
        after_flush_writes
        @queued_for_write = {}
			end

			def flush_deletes
				path_styles = styles.keys.push(:original).map {|val| val.to_s}

				@queued_for_delete.each do |path|
					begin
						
						dropbox_client.delete("/#{path}")
					rescue
					end
				end

				if has_dropbox_share_urls? && !@queued_for_delete.empty?
        	new_share_urls = dropbox_share_urls

        	path_styles.each do |style|
        		Rails.cache.delete("#{@instance.class}_#{@instance.id}_#{name}_#{style}")
        		new_share_urls.delete("#{name}_#{style}")
        	end

        	update_dropbox_share_urls(new_share_urls.to_json)if @instance.persisted?
        end

				@queued_for_delete = []
			end

			def public_url(style = default_style, size = 0)
				return cached_url(style, size) if can_use_cached_url?("#{name}_#{style}") 

				shared_link = dropbox_shared_link(style, size)

				if has_dropbox_share_urls?
        	new_share_urls = dropbox_share_urls

		    	new_share_urls["#{name}_#{style}"] = shared_link
        	update_dropbox_share_urls(new_share_urls.to_json)
		    end
				shared_link
			end

			private

			def dropbox_shared_link(style = default_style, size = 0)
				begin
					shared_link = @options[:default_url]
					shared_link = dropbox_client.list_shared_links(path: "/#{path(style)}").links.first.url.gsub("/s/", "/s/raw/")
				rescue
					shared_link = dropbox_client.create_shared_link_with_settings("/#{path(style)}").url.gsub("/s/", "/s/raw/")
				end

				shared_link
			end

			def remove_redirects(shared_link)
				loop do 
					res = HTTP.get(shared_link)

					break unless res.status == 302
					shared_link = res['location']
				end
				
				shared_link
			end

			def dropbox_share_urls
				begin
      		@_dropbox_share_urls ||= JSON.parse(@instance.dropbox_share_urls)
      	rescue
      		@_dropbox_share_urls ||= {}
      	end
			end

			def update_dropbox_share_urls(value)
				@instance.update_column(:dropbox_share_urls, value)
			end

			def has_dropbox_share_urls?
				@instance.has_attribute?(:dropbox_share_urls)
			end

			def max_size
				@_max_size ||= @options['max_file_size'] || 1024 * 1024 * 3
			end

			def cached_url(style = default_style, size = 0)
				if has_dropbox_share_urls?
					remove_url_redirects = @options[:remove_url_redirects] || false

					if dropbox_share_urls.has_key?("#{name}_#{style}")
						return dropbox_share_urls["#{name}_#{style}"] unless remove_url_redirects

						return Rails.cache.fetch("#{@instance.class}_#{@instance.id}_#{name}_#{style}", expires_in: 3.hours) do
							shared_link = dropbox_share_urls["#{name}_#{style}"]
							shared_link = remove_redirects(shared_link) if remove_url_redirects && size <= max_size

							shared_link
						end
					end
        end

        false
			end

			def can_use_cached_url?(style_key)
				has_dropbox_share_urls? && dropbox_share_urls.has_key?(style_key)
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
							warn("#{CONFIG_FILE} does not exist\nEnsure you have authorised paperclipdropbox")
						end
					end
				
				@_dropbox_client
			end
		end
	end
end
