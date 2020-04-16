require 'spec_helper'
require 'hailstorm/support/jmeter_installer'

describe Hailstorm::Support::JmeterInstaller do

  context '.create' do
    it 'should default to tarball strategy' do
      installer = Hailstorm::Support::JmeterInstaller.create
      expect(installer).to be_kind_of(Hailstorm::Support::JmeterInstaller::Tarball)
    end
  end

  context Hailstorm::Support::JmeterInstaller::Tarball do
    it 'should have @download_url' do
      installer = Hailstorm::Support::JmeterInstaller.create.with(:download_url, 'http//foo.com/jmeter.tar.gz')
      expect(installer.download_url).to eql('http//foo.com/jmeter.tar.gz')
    end
    it 'should have @user_home' do
      installer = Hailstorm::Support::JmeterInstaller.create.with(:user_home, '/Users/alice')
      expect(installer.user_home).to eql('/Users/alice')
    end
    it 'should have @jmeter_version' do
      installer = Hailstorm::Support::JmeterInstaller.create.with(:jmeter_version, 3.2)
      expect(installer.jmeter_version).to eql('3.2')
    end

    context '#install' do
      before(:each) do
        @installer = Hailstorm::Support::JmeterInstaller.create.with(:user_home, '/Users/john.doe')
      end
      context 'with jmeter_version' do
        context 'with(:jmeter_version) >= 2.6' do
          before(:each) do
            @installer.jmeter_version = 3.2
            @instructions = []
            @installer.install { |e| @instructions.push(e) }
            @instructions.compact!
          end
          it 'should download from default download url to versioned directory' do
            instr = @instructions[0]
            download_file = "apache-jmeter-#{@installer.jmeter_version}.tgz"
            download_url = "https://archive.apache.org/dist/jmeter/binaries/#{download_file}"
            expect(instr).to eql("wget '#{download_url}' -O #{download_file}")
          end
          it 'should create a jmeter symlink' do
            instr = @instructions[2]
            user_home = @installer.user_home
            jmeter_directory = "apache-jmeter-#{@installer.jmeter_version}"
            expect(instr).to eql("ln -s #{user_home}/#{jmeter_directory} #{user_home}/jmeter")
          end
          it 'should add post install instructions' do
            last_inst = @instructions.last
            expect(last_inst).to match(/# End of additions by Hailstorm/)
          end
        end
      end

      context 'with download_url' do
        before(:each) do
          @download_dir = 'apache-jmeter-3.1'
          @download_file = "#{@download_dir}.tar.gz"
          @installer.download_url = "https://maxcdn.in/#{@download_file}"
          @instructions = []
          @installer.install { |e| @instructions.push(e) }
          @instructions.compact!
        end
        it 'should download from download_url' do
          instr = @instructions[0]
          expect(instr).to eql("wget '#{@installer.download_url}' -O #{@download_file}")
        end
        it 'should create a jmeter symlink' do
          instr = @instructions[2]
          user_home = @installer.user_home
          expect(instr).to eql("ln -s #{user_home}/#{@download_dir} #{user_home}/jmeter")
        end
        it 'should add post install instructions' do
          last_inst = @instructions.last
          expect(last_inst).to match(/# End of additions by Hailstorm/)
        end
      end

      context 'both jmeter_version and download_url' do
        it 'should use download_url when it is assigned after jmeter_version' do
          @installer.jmeter_version = '3.1.1'
          @installer.download_url = 'https://maxcdn.in/apache-jmeter-ndc-3.1.tgz'
          @installer.install {}
          expect(@installer).to be_kind_of(Hailstorm::Support::JmeterInstaller::Tarball::DownloadUrlStrategy)
          expect(@installer).to_not be_kind_of(Hailstorm::Support::JmeterInstaller::Tarball::JmeterVersionStrategy)
        end
        it 'should use download_url when it is assigned before jmeter_version' do
          @installer.download_url = 'https://maxcdn.in/apache-jmeter-ndc-3.1.tgz'
          @installer.jmeter_version = '3.1.1'
          @installer.install {}
          expect(@installer).to be_kind_of(Hailstorm::Support::JmeterInstaller::Tarball::DownloadUrlStrategy)
          expect(@installer).to_not be_kind_of(Hailstorm::Support::JmeterInstaller::Tarball::JmeterVersionStrategy)
        end
      end

      context 'neither jmeter_version or download_url specified' do
        it 'should raise error' do
          expect { @installer.install {} }.to raise_error(ArgumentError)
        end
      end

      context 'user_home is not specified' do
        it 'should raise error' do
          expect { Hailstorm::Support::JmeterInstaller.create.install { |e| e } }.to raise_error(ArgumentError)
        end
      end
    end
  end

  context Hailstorm::Support::JmeterInstaller::Validator do
    before(:each) do
      @validator_klass = Hailstorm::Support::JmeterInstaller::Validator
    end
    context '.validate_download_url_format' do
      it 'should be invalid if ends with something other than .tgz or .tar.gz' do
        expect(@validator_klass.validate_download_url_format('http://whodunit.org/my-jmeter-3.2_rhode.tar')).to be_false
      end
    end

    context '.validate_version' do
      it 'should be false if version is lower than major.minor' do
        expect(@validator_klass.validate_version('1.9', 2, 0)).to be_false
        expect(@validator_klass.validate_version('2.0', 2, 1)).to be_false
      end
      it 'should be true if version is equal to major.minor' do
        expect(@validator_klass.validate_version('2.1', 2, 1)).to be_true
      end
      it 'should be true if version is higher than major.minor' do
        expect(@validator_klass.validate_version('2.3', 2, 2)).to be_true
        expect(@validator_klass.validate_version('4.1', 3, 2)).to be_true
      end
    end
  end
end
