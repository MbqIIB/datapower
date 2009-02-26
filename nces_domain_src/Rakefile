begin
  require 'rubygems'
  require 'rake/gempackagetask'
rescue Exception
  nil
end
require 'rake/clean'
require 'rake/testtask'
require 'rake/rdoctask'

require 'pp'

require 'fileutils'
require 'find'
require 'zip/zipfilesystem'

require 'tempfile'


#
# Zipper provides an easy interface to create zip files
# using zip/zipfilesystem. Hand Zipper a directory tree
# and the name of the zip file and Zipper will zip the
# whole tree into the file. Optionally you can supply
# Zipper with a block which will translate the name on
# the disk into the name you want in the zip file. If
# the block returns nil, that file will be left out of
# the zip file.
#
# Example:
# 
#  Zipper.create_zip('/home/russ/zerocredit', 'b.zip', true) do |p|
#    if p =~ /.svn.*/
#      nil
#    else
#      p.sub(/.home.russ\//, '')
#    end
#  end
#
class Zipper

  #
  # Create a new Zipper that will write to the
  # given zip file. Warning: this will overwrite
  # the file given.
  #
  def initialize(zip_file_path)
    File.delete(zip_file_path) if File.exists? zip_file_path
    @zip = Zip::ZipFile.open(zip_file_path, Zip::ZipFile::CREATE)
  end

  #
  # Opens a new zip file for output.
  #
  def zip(top_path, verbose=false, &path_filter)
    Find.find(top_path) do |path|

      zip_entry_path = path_filter ? path_filter.call(path) : path

      next if not zip_entry_path

      if File.file? path
        puts "File #{path} --> #{zip_entry_path}" if verbose
        @zip.add( zip_entry_path, path)
      else
        puts "Dir #{path} --> #{zip_entry_path}" if verbose
        @zip.dir.mkdir(zip_entry_path)
      end
    end
  end

  def close
    @zip.close
  end

  def Zipper.create_zip( path, zip_file_path, verbose=true, &block)
    r = Zipper.new(zip_file_path)
    r.zip(path,verbose, &block)
    r.close
  end

  def Zipper.create_zip2( path, zip_file_path, verbose=true, &block)
    r = Zipper.new(zip_file_path)
    r.zip(path,verbose, &block)
    r.close
  end

end

module Unzipper


  def Unzipper.unzip(zip_file, target_dir=".")
    #
    # Take a pass thru and create all the directories
    #
    Zip::ZipFile.foreach(zip_file) do |e|
      if e.directory?
        path = File.join(target_dir, e.to_s)
        puts "dir: #{zip_file}:#{e}=>#{path}"
        FileUtils.mkdir_p path
      end
    end

    #
    # Take a pass and create all the files.
    #
    Zip::ZipFile.foreach(zip_file) do |e|
      if e.file?
        path = File.join(target_dir, e.to_s)
        puts "file: #{zip_file}:#{e}=>#{path}"
        e.extract(path) {true}
      end
    end

  end

  def Unzipper.recursively_unzip(zip_file, target_dir=".", create_dir=false)
    #
    # First unzip the main zip file.
    #
    path=target_dir

    if create_dir
      dir_name = File.basename(zip_file).sub(/\.zip$/, '')
      path = File.join(path, dir_name)
    end

    unzip(zip_file, path)

    Find.find(path) do |e| 
      if /\.zip$/ =~ e
        recursively_unzip(e, File.dirname(e), true)
      end
    end

  end
end


#
# Copy files with a filter
#
module FileCopier
  def FileCopier.copy_tree(src, dst, verbose=false, &path_filter)

    Find.find(src) do |path|

      dst_path = path_filter ? path_filter.call(path) : path

      next if not dst_path

      if File.file? path
        puts "File #{path} --> #{dst}/#{dst_path}" if verbose

        File.open("#{dst}/#{dst_path}", "w") do |out_f|
          File.open(path) { |in_f| out_f.write(in_f.read) }
        end     
      else
        puts "Dir #{path} --> #{dst}/#{dst_path}" if verbose
        Dir.mkdir("#{dst}/#{dst_path}")
      end
    end
  end

end

TARGET_DIR='target'
STAGE_DIR = 'stage'
TMP_DIR = 'tmp'
IMPORT_DIR = 'imported'

FINAL_ZIP="#{TARGET_DIR}/nces.zip"

DPAUX_STAGE="#{STAGE_DIR}/dp-aux"
DPAUX_SRC="src/dp-aux"


task :default => [FINAL_ZIP]


CLEAN << TARGET_DIR
CLEAN << STAGE_DIR
CLEAN << TMP_DIR


directory STAGE_DIR
directory TARGET_DIR
directory TMP_DIR
directory IMPORT_DIR

GENERATED_DIRS = [ TARGET_DIR, STAGE_DIR, TMP_DIR ]

task :create_dirs => GENERATED_DIRS



desc "Create the final export zip file."

file FINAL_ZIP => [ TARGET_DIR, :stage_files ] do |t|
  Zipper.create_zip('stage', FINAL_ZIP, true) do |p|
    if p == 'stage'
      nil
    else
      p.sub(/^stage\//, '')
    end
  end
end


#
# Create the Nces zip file.
# 
# Need to create the zip file first in a temp dir, because
# The zip creation process leaves temporary files laying round,
# which can get accidentally sucked into the master zip file.
#

desc "Create the zip file for the Nces realm."

file "#{STAGE_DIR}/Nces.zip" => FileList[ 'src/Nces/**' ] do |t|
  Zipper.create_zip('src/Nces', "#{TMP_DIR}/Nces.zip", true) do |p|
    if p =~ /.svn.*/
      nil
    elsif p == 'src/Nces'
      nil
    else
      p.sub(/^src\/Nces\//, '')
    end
  end
  FileUtils.mv( "#{TMP_DIR}/Nces.zip", "#{STAGE_DIR}/Nces.zip" )
end


desc "Create the stage/dp-aux directory, by just copying from src"

file DPAUX_STAGE => FileList["#{DPAUX_SRC}/**"] do
  FileUtils.rm_rf(DPAUX_STAGE)
  # FileUtils.cp_r(DPAUX_SRC, STAGE_DIR  )
  FileCopier.copy_tree( DPAUX_SRC, STAGE_DIR ) do |p|
    p =~ /\/\.svn/ ? nil : p.sub(/^src\//, '')
  end
end

desc "Create the export xml file by just copying from src"

file "#{STAGE_DIR}/export.xml" => FileList["src/export.xml"] do
  FileUtils.cp('src/export.xml', STAGE_DIR  )
end


desc "Create the entire stage directory, ready for zipping"

task :stage_files => [:create_dirs, DPAUX_STAGE, "#{STAGE_DIR}/export.xml", "#{STAGE_DIR}/Nces.zip"] 

desc "Clear all the working files out of the src dir. DANGEROUS!"

task :clear_working_files do
  files=[]
  Find.find('src') do |path|
    next if /\.svn/ =~ path
    next if not File.file? path
    puts "delete #{path}"
  end
end

desc "Expand export.zip into the imported directory, good for getting config back from datapower"

task :import  do
  Unzipper.recursively_unzip 'export.zip', 'src'
end
