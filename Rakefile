require 'fpm'

require 'fileutils'
require 'net/http'
require 'uri'

vendordir = 'vendor'
buildbase = 'build'
resdir = 'res'
packagedir = 'packages'

basedir_gl = '/opt/gitlab-ce'
confdir_gl = '/etc/gitlab-ce'
logdir_gl = '/var/log/gitlab-ce'
rundir_gl = '/var/run/gitlab-ce'
tmpdir_gl = '/tmp/gitlab-ce'

builddir_gl = "#{buildbase}/gitlab-ce"
pkgdir_gl = "#{builddir_gl}/pkg"
installdir_gl = "#{pkgdir_gl}#{basedir_gl}"
resdir_gl = "#{resdir}/gitlab-ce"

basedir_wh = '/opt/gitlab-workhorse'
builddir_wh = "#{buildbase}/gitlab-workhorse"
pkgdir_wh = "#{builddir_wh}/pkg"
installdir_wh = "#{pkgdir_wh}#{basedir_wh}"
resdir_wh = "#{resdir}/gitlab-workhorse"

def download_archive(source, target)
  uri = URI(source)
  if (not File.exists?(target)) then
    File.open(target, 'wb') do |archive|
      Net::HTTP.start(uri.host, uri.port, :use_ssl => true) do |http|
        http.request_get(uri.request_uri) do |resp|
          resp.read_body do |segment|
            archive.write(segment)
          end
        end
      end
    end
  end
end

task :default => [:download, :deb]

task :download => [:download_gl, :download_wh]

task :deb => [:deb_gl, :deb_wh]

task :deb_gl => [:clean_gl, :prep_gl, :build_deb_gl]

task :deb_wh => [:clean_wh, :prep_wh, :build_deb_wh]

desc "Download the GitLab release specified in the environment variable 'gl_tag'."
task :download_gl do
  tag = ENV['gl_tag'] || raise('Must set the environment variable "gl_tag".')
  version = tag.sub(/^v/, '')
  source_uri = "https://gitlab.com/gitlab-org/gitlab-ce/repository/archive.tar.gz?ref=#{tag}"
  target_path = "#{vendordir}/gitlab-ce-#{version}.tar.gz"
  Dir.mkdir(vendordir) unless File.exists?(vendordir)
  download_archive(source_uri, target_path)
end

task :clean_downloads do
  FileUtils.rm_rf(vendordir, :secure => true) if File.exists?(vendordir)
end

desc "Clear out data from old builds of GitLab."
task :clean_gl do
  FileUtils.rm_rf(builddir_gl, :secure => true) if File.exists?(builddir_gl)
end

desc "Prepare the GitLab build directory."
task :prep_gl do
  version = ENV['gl_tag'].sub(/^v/, '') || raise('Must set the environment variable "gl_tag".')
  src_tarball = "#{vendordir}/gitlab-ce-#{version}.tar.gz"
  Dir.mkdir(builddir_gl) unless File.exists?(builddir_gl)
  %x(tar -xf #{src_tarball} -C #{builddir_gl})
end

task :build_deb_gl do
  version = ENV['gl_tag'].sub(/^v/, '') || raise('Must set the environment variable "gl_tag".')
  iteration = ENV['iteration'] || raise('Must set the package iteration!')
  if (not RUBY_PLATFORM == 'x86_64-linux') then
    raise('Must be on x86_64-linux to build gitlab-ce.')
  end

  FileUtils.rm_rf(pkgdir_gl, :secure => true) if File.exists?(pkgdir_gl)
  FileUtils.mkdir_p([basedir_gl, '/etc', tmpdir_gl, logdir_gl, rundir_gl, '/lib/systemd'].map { |x| "#{pkgdir_gl}#{x}" })

  File.rename(Dir.glob("#{builddir_gl}/gitlab-ce-*").first, installdir_gl)
  File.delete("#{installdir_gl}/config/unicorn.rb.example", "#{installdir_gl}/config/unicorn.rb.example.development")
  File.rename("#{installdir_gl}/tmp", "#{pkgdir_gl}#{tmpdir_gl}")
  File.rename("#{installdir_gl}/config", "#{pkgdir_gl}#{confdir_gl}")
  File.rename("#{installdir_gl}/log", "#{pkgdir_gl}#{logdir_gl}")
  File.symlink(tmpdir_gl, "#{pkgdir_gl}#{basedir_gl}/tmp")
  File.symlink(confdir_gl, "#{pkgdir_gl}#{basedir_gl}/config")
  File.symlink(logdir_gl, "#{pkgdir_gl}#{basedir_gl}/log")
  FileUtils.cp("#{resdir_gl}/unicorn.rb", "#{pkgdir_gl}#{confdir_gl}/unicorn.rb")
  FileUtils.cp_r("#{resdir_gl}/systemd", "#{pkgdir_gl}/lib/systemd/system")

  system("bundle install --gemfile=#{pkgdir_gl}#{basedir_gl}/Gemfile --deployment --without development mysql test aws kerberos")

  package = FPM::Package::Dir.new
  package.attributes[:chdir] = pkgdir_gl
  package.input('.')
  deb = package.convert(FPM::Package::Deb)
  deb.name = 'gitlab-ce'
  deb.version = version
  deb.iteration = "plops#{iteration}"
  deb.description = 'GitLab Community Edition (non-Omnibus package)'
  deb.dependencies = ['ruby >= 2.1.0', 'gitlab-workhorse', ]
  deb.attributes['deb_recommends'] = ['redis-server > 2.8.0', 'postgresql > 9.1', ]
  deb.maintainer = 'Puppet Labs SysOps Department <opsteam@puppetlabs.net>'
  deb.architecture = 'all'
  deb.scripts[:after_install] = File.open("#{resdir_gl}/post-install.sh", 'rb') { |f| f.read }

  outputname = packagedir + '/' + deb.to_s()

  if File.exists? outputname
    puts "File already exists at " + outputname
    exit 1
  end

  puts "Executing FPM."
  begin
    deb.output(outputname)
  ensure
    deb.cleanup
  end
end

desc "Download the specified release of gitlab-workhorse"
task :download_wh do
  tag = ENV['wh_tag'] || raise('Must set the environment variable "wh_tag"')
  version = tag.sub(/^v/, '')
  source_uri = "https://gitlab.com/gitlab-org/gitlab-workhorse/repository/archive.tar.gz?ref=#{tag}"
  target_path = "#{vendordir}/gitlab-workhorse-#{version}.tar.gz"
  download_archive(source_uri, target_path)
end

desc "Clear out data from old builds of gitlab-workhorse."
task :clean_wh do
  FileUtils.rm_rf(builddir_wh, :secure => true) if File.exists?(builddir_wh)
end

desc "Prepare the gitlab-workhorse build directory."
task :prep_wh do
  version = ENV['wh_tag'] || raise('Must set the environment variable "wh_tag".')
  src_tarball = "#{vendordir}/gitlab-workhorse-#{version}.tar.gz"
  Dir.mkdir(builddir_wh) unless File.exists?(builddir_wh)
  %x(tar -xf #{src_tarball} -C #{builddir_wh})
end

desc "Compile the specified release of gitlab-workhorse and package as a .deb."
task :build_deb_wh do
  if (not RUBY_PLATFORM == 'x86_64-linux') then
    raise('Must be on x86_64-linux to build gitlab-workhorse.')
  end
  version = ENV['wh_tag'] || raise('Must set the environment variable "wh_tag"')
  iteration = ENV['iteration'] || raise('Must set the package iteration!')
  FileUtils.rm_rf(pkgdir_wh, :secure => true) if File.exists?(pkgdir_wh)
  FileUtils.mkdir_p(["#{basedir_wh}/bin", 'lib/systemd'].map { |x| "#{pkgdir_wh}/#{x}" })
  srcdir = Dir.glob("#{builddir_wh}/gitlab-workhorse-*").first
  prefixdir = Dir.getwd() + '/' + installdir_wh

  if (not system("make -C #{srcdir} install PREFIX=#{prefixdir} VERSION=#{version}")) then
    raise('Compilation of gitlab-workhorse failed!')
  end

  FileUtils.cp_r("#{resdir_wh}/systemd", "#{pkgdir_wh}/lib/systemd/system")

  package = FPM::Package::Dir.new
  package.attributes[:chdir] = pkgdir_wh
  package.input('.')
  deb = package.convert(FPM::Package::Deb)
  deb.name = 'gitlab-workhorse'
  deb.version = version
  deb.iteration = "plops#{iteration}"
  deb.description = 'gitlab-workhorse is a reverse proxy that handles slow HTTP requests for GitLab'
  deb.maintainer = 'Puppet Labs SysOps Department <opsteam@puppetlabs.net>'
  deb.architecture = 'x86_64'
  deb.scripts[:after_install] = File.open("#{resdir_wh}/post-install.sh", 'rb') { |f| f.read }

  outputname = packagedir + '/' + deb.to_s()

  if File.exists? outputname
    puts "File already exists at " + outputname
    exit 1
  end

  puts "Executing FPM."
  begin
    deb.output(outputname)
  ensure
    deb.cleanup
  end
end

