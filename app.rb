require 'sinatra'
require 'digest/md5'
require 'webrick'

# Configuration
set :public_folder, 'public'
set :views, 'views'
set :server, :webrick

# Routes
get '/' do
  erb :index
end

post '/scan' do
  @path = params[:path].to_s.strip
  @recursive = params[:recursive] == '1'
  
  if @path.empty? || !Dir.exist?(@path)
    @error = "Invalid folder path. Please provide a valid directory."
    return erb :index
  end

  begin
    # Find all files
    pattern = @recursive ? File.join(@path, '**', '*') : File.join(@path, '*')
    all_items = Dir.glob(pattern)
    
    file_hashes = Hash.new { |h, k| h[k] = [] }
    @total_files = 0
    
    all_items.each do |item|
      next unless File.file?(item)
      @total_files += 1
      
      begin
        # Calculate MD5 hash
        md5 = Digest::MD5.file(item).hexdigest
        file_hashes[md5] << {
          name: File.basename(item),
          path: item,
          size: File.size(item)
        }
      rescue Errno::EACCES, Errno::ENOENT
        next # Skip files we can't read
      end
    end

    # Filter for duplicates
    @duplicates = file_hashes.select { |hash, files| files.size > 1 }
    
    # Calculate wasted space
    total_wasted_bytes = 0
    @duplicates.each do |hash, files|
      file_size = files.first[:size]
      total_wasted_bytes += (files.size - 1) * file_size
    end
    
    @wasted_space_mb = total_wasted_bytes / (1024.0 * 1024.0)
    
    erb :results

  rescue => e
    @error = "An error occurred during scanning: #{e.message}"
    erb :index
  end
end

# Run the app if executed directly
if __FILE__ == $0
  # Set host to allow connections (default is localhost)
  set :bind, '0.0.0.0'
  set :port, 4567
end
