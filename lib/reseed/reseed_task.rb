require 'uri'
require 'fileutils'
require 'open-uri'

# Don't allow downloaded files to be created as StringIO. Force a tempfile to be created.
OpenURI::Buffer.send :remove_const, 'StringMax' if OpenURI::Buffer.const_defined?('StringMax')
OpenURI::Buffer.const_set 'StringMax', 0

class ReseedTask

   def execute name, seeds
      @current_task = name

      seeds.each do |s|
         files_to_reseed = []

         if s[:file]
            files_to_reseed = [s]
         elsif s[:files]
            arg = s.delete :files
            
            if arg.is_a? String
               files = Dir.glob arg
            elsif arg.is_a? Array
               files = arg         
            else
               return 
            end
            files_to_reseed = files.map { |f| { :file => f }.merge(s) }
         end

         reseed_files files_to_reseed
      end

      @current_task = nil
   end

   def reseed_files files
      files.each do |args|
         if args[:latest_dir]
            reseed_from_latest_dir args[:latest_dir], args[:file]
         elsif args[:dir]
            reseed_from_dir args[:dir], args[:file]
         elsif args[:web]
            reseed_from_web args[:web], args[:file]
         end
      end
   end

   def reseed_from_latest_dir base_dir, file
      source = File.join base_dir, Dir.entries(base_dir).sort.reverse.take(1).first
      reseed_from_dir source, file
   end

   def reseed_from_dir dir, file
      source = File.join(dir, File.basename(file))
      reseed source, file 
   end

   def reseed_from_web url, file
      if /\.zip$/i.match url
         extracted_to = download_and_extract url
         reseed_from_dir extracted_to, file
         return
      elsif /(\\|\/)$/.match url
         url += File.basename file
      end

      begin
         open url do |x|
            reseed x.path, file
         end
      rescue
         base_name = File.basename file
         puts "#{@current_task} : (Doesn't exist) #{base_name}"
      end
   end

   def reseed source, dest
      base_name = File.basename dest
      if File.exist? source
         begin
            FileUtils.cp source, dest
            puts "#{@current_task} : #{base_name}"
         rescue
            puts "#{@current_task} : (Unable to copy) #{base_name}"
         end
      else
         puts "#{@current_task} : (Doesn't exist) #{base_name}"
      end
   end

   def download_and_extract url_to_zip
      puts "#{@current_task} : Downloading #{url_to_zip}"

      temp_dir = Dir.mktmpdir

      open url_to_zip do |f|
         zip_path = f.path

         Zip::ZipFile.open(zip_path) do |zip|
            zip.each do |z|
               dest = File.join temp_dir, z.name
               FileUtils.mkdir_p(File.dirname(dest))
               zip.extract z, dest
            end
         end
      end

      temp_dir
   end
end
