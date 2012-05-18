require "lolcommits/version"
require "choice"
require "fileutils"
require "git"
require "RMagick"
require "open3"
require "launchy"
include Magick
require "imgur2"

module Lolcommits
  $home = ENV['HOME']
  LOLBASEDIR = File.join $home, ".lolcommits"
  LOLCOMMITS_ROOT = File.join(File.dirname(__FILE__), '..')

  def is_mac?
    RUBY_PLATFORM.downcase.include?("darwin")
  end

  def is_linux?
    RUBY_PLATFORM.downcase.include?("linux")
  end

  def is_windows?
    if RUBY_PLATFORM =~ /(win|w)32$/
      true
    end
  end

  def most_recent(dir='.')
    loldir, commit_sha, commit_msg = parse_git
    Dir.glob(File.join loldir, "*").max_by {|f| File.mtime(f)}
  end
  
  def loldir(dir='.')
    loldir, commit_sha, commit_msg = parse_git
    return loldir
  end
  
  def parse_git(dir='.')
    g = Git.open('.')
    commit = g.log.first
    commit_msg = commit.message.split("\n").first
    commit_sha = commit.sha[0..10]
    basename = File.basename(g.dir.to_s)
    basename.sub!(/^\./, 'dot') #no invisible directories in output, thanks!
    loldir = File.join LOLBASEDIR, basename
    return loldir, commit_sha, commit_msg
  end

  def upload(filepath)
    client = Imgur2.new 'b5ca7b73c0885e3208e1907b3d587f97' # lolcommits API key

    image = File.open File.join(filepath), 'rb'
    result = client.upload image
    image.close

    if result['error']
      STDERR.puts "Unable to upload lolcommit: #{result['error']['message']}"
    elsif result['upload']
      url = result['upload']['links']['large_thumbnail']
      if client.paste url
        puts "*** Image URL: #{url} (copied to your clipboard)"
      else
        puts "*** Image URL: #{url}"
      end
      url
    end
  end

  def capture(msg_file, capture_delay=0, is_test=false, test_msg=nil, test_sha=nil)
    #
    # Read the git repo information from the current working directory
    #
    if not is_test
      loldir, commit_sha, commit_msg = parse_git

      # overwrite commit_msg
      open(msg_file) do |f|
        commit_msg = f.readline.strip
      end
    else
      commit_msg = test_msg
      commit_sha = test_sha
      loldir = File.join LOLBASEDIR, "test"
    end
    
    #
    # Create a directory to hold the lolimages
    #
    if not File.directory? loldir
      FileUtils.mkdir_p loldir
    end

    #
    # SMILE FOR THE CAMERA! 3...2...1...
    # We're just assuming the captured image is 640x480 for now, we may
    # need updates to the imagesnap program to manually set this (or resize)
    # if this changes on future mac isights.
    #
    puts "*** Preserving this moment in history."
    snapshot_loc = File.join loldir, "tmp_snapshot.jpg"
    if is_mac?
      imagesnap_bin = File.join LOLCOMMITS_ROOT, "ext", "imagesnap", "imagesnap"
      system("#{imagesnap_bin} -q #{snapshot_loc} -w #{capture_delay}")
    elsif is_linux?
      tmpdir = File.expand_path "#{loldir}/tmpdir#{rand(1000)}/"
      FileUtils.mkdir_p( tmpdir )
      # There's no way to give a capture delay in mplayer, but a number of frame
      # I've found that 6 is a good value for me.
      frames = if capture_delay != 0 then capture_delay else 6 end

      # mplayer's output is ugly and useless, let's throw it away
      _, r, _ = Open3.popen3("mplayer -vo jpeg:outdir=#{tmpdir} -frames #{frames} tv://")
      # looks like we still need to read the output for something to happen
      r.read
      FileUtils.mv(tmpdir + "/%08d.jpg" % frames, snapshot_loc)
      FileUtils.rm_rf( tmpdir )
    elsif is_windows?
      commandcam_exe = File.join LOLCOMMITS_ROOT, "ext", "CommandCam", "CommandCam.exe"
      # DirectShow takes a while to show... at least for me anyway
      delaycmd = " /delay 3000"
      if capture_delay > 0
        # CommandCam delay is in milliseconds
        delaycmd = " /delay #{capture_delay * 1000}"
      end
      _, r, _ = Open3.popen3("#{commandcam_exe} /filename #{snapshot_loc}#{delaycmd}")
      # looks like we still need to read the output for something to happen
      r.read
    end


    #
    # Process the image with ImageMagick to add loltext
    #

    # read in the image, and resize it via the canvas
    canvas = ImageList.new("#{snapshot_loc}")
    if (canvas.columns > 640 || canvas.rows > 480)
      canvas.resize_to_fill!(640,480)
    end

    # create a draw object for annotation
    draw = Magick::Draw.new
    #if is_mac?
    #  draw.font = "/Library/Fonts/Impact.ttf"
    #else
    #  draw.font = "/usr/share/fonts/TTF/impact.ttf"
    #end
    draw.font = File.join(LOLCOMMITS_ROOT, "fonts", "Impact.ttf")

    draw.fill = 'white'
    draw.stroke = 'black'

    # convenience method for word wrapping
    # based on https://github.com/cmdrkeene/memegen/blob/master/lib/meme_generator.rb
    def word_wrap(text, col = 28)
      wrapped = text.gsub(/(.{1,#{col + 4}})(\s+|\Z)/, "\\1\n")
      wrapped.chomp!
    end

    draw.annotate(canvas, 0, 0, 0, 0, word_wrap(commit_msg)) do
      self.gravity = SouthWestGravity
      self.pointsize = 48
      self.interline_spacing = -(48 / 5) if self.respond_to?(:interline_spacing)
      self.stroke_width = 2
    end if commit_msg

    #
    # Squash the images and write the files
    #
    filename = Time.now.strftime("%Y%m%d_%H%M")
    filepath = File.join loldir, "#{filename}.jpg"
    canvas.write filepath
    FileUtils.rm(snapshot_loc)

    # if in test mode, open image for inspection
    Launchy.open(filepath) if is_test

    return filepath
  end

  def format_url(url)
    "\nlolcommits:\n    !#{url}!\n"
  end

  def upload_and_append_to_commit_msg(img_file, msg_file)
    url = upload img_file
    open(msg_file, 'a') do |f|
      f.write format_url(url)
    end if url
  end

  def capture_imgur(msg_file, capture_delay=0, is_test=false, test_msg=nil, test_sha=nil)
    filepath = capture(msg_file, capture_delay, is_test, test_msg, test_sha)
    upload_and_append_to_commit_msg(filepath, msg_file)
  end
  
end
