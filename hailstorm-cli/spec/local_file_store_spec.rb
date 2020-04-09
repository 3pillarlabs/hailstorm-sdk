require 'spec_helper'

require 'tmpdir'
require 'hailstorm/local_file_store'

describe Hailstorm::LocalFileStore do

  def create_app_artifacts(*list)
    FileUtils.mkdir_p(File.join(Hailstorm.root, Hailstorm.app_dir))
    list.map do |element|
      file_name = if element.is_a?(Enumerable)
                    path = File.join(element)
                    FileUtils.mkdir_p(File.join(Hailstorm.root, Hailstorm.app_dir, File.dirname(path)))
                    path
                  else
                    element
                  end
      file_name_extn = /\..+$/.match(file_name) ? file_name : "#{file_name}.jmx"
      FileUtils.touch(File.join(Hailstorm.root, Hailstorm.app_dir, file_name_extn))
      file_name
    end
  end

  local_fs = Hailstorm::LocalFileStore.new

  before(:each) do
    FileUtils.rm_rf(File.join(Hailstorm.root, Hailstorm.app_dir))
    FileUtils.mkdir(File.join(Hailstorm.root, Hailstorm.app_dir))
    FileUtils.rm_rf(File.join(Hailstorm.root, Hailstorm.reports_dir))
    FileUtils.mkdir(File.join(Hailstorm.root, Hailstorm.reports_dir))
  end

  context '#fetch_jmeter_plans' do
    it 'should fetch file names relative to app directory' do
      expected_elements = create_app_artifacts('prime', %w[admin basic])

      actual_elements = local_fs.fetch_jmeter_plans('any')
      expect(actual_elements.size).to be == expected_elements.size
      expect(actual_elements).to include(expected_elements[0])
      expect(actual_elements).to include(expected_elements[1])
    end
  end

  context '#app_dir_tree' do
    it 'should return directory hierarchy' do
      app_path = File.join(Hailstorm.root, Hailstorm.app_dir)
      FileUtils.mkdir_p("#{app_path}/a/b/d/e")
      FileUtils.mkdir_p("#{app_path}/a/b/d/f")
      FileUtils.mkdir_p("#{app_path}/a/c/g")
      key = Hailstorm.app_dir
      structure = {}
      structure[key] = {
        a: {
          b: {
            d: { e: nil, f: nil }
          },
          c: { g: nil }
        }
      }

      structure.deep_stringify_keys!
      expect(local_fs.app_dir_tree).to eq(structure)
      expect(local_fs.tree_dir("#{app_path}/a")).to eq(structure[key])
      expect(local_fs.tree_dir("#{app_path}/a/b")).to eq({'b' => structure[key]['a']['b']})
      expect(local_fs.tree_dir("#{app_path}/a/b/d")).to eq(structure[key]['a']['b'])
      expect(local_fs.tree_dir("#{app_path}/a/b/d/e")).to eq({'e' => nil})
      expect(local_fs.tree_dir("#{app_path}/a/c")).to eq({'c' => structure[key]['a']['c']})
    end
  end

  context '#transfer_jmeter_artifacts' do
    it 'should skip backup or temporary files' do
      create_app_artifacts('prime', '.foo', %w[admin bar.jmx~], %w[admin baz])
      copied_files = []
      FileUtils.stub!(:cp) { |_source, target| copied_files << target }
      local_fs.transfer_jmeter_artifacts('any', '/')
      expect(copied_files).to include('/prime.jmx')
      expect(copied_files).to include('/admin/baz.jmx')
      expect(copied_files).to_not include('/.foo')
      expect(copied_files).to_not include('/admin/bar.jmx~')
    end
  end

  context '#export_jtl' do
    context 'single log needs to be exported' do
      it 'should be exported to the reports path' do
        jtl_file_name = 'foo.jtl'
        expected_path = File.join(Hailstorm.root, Hailstorm.reports_dir, jtl_file_name)
        Dir.mktmpdir do |root|
          jtl_path = File.join(root, jtl_file_name)
          FileUtils.touch(jtl_path)
          FileUtils.should_receive(:cp).with(jtl_path, expected_path)
          local_fs.export_jtl('any', jtl_path)
        end
      end
    end

    context 'multiple logs need to be exported' do
      it 'should be exported to multiple directories' do
        Dir.mktmpdir do |root|
          (1..3).each do |ite|
            seq_dir = "SEQ-#{ite}"
            FileUtils.mkdir(File.join(root, seq_dir))
            FileUtils.touch(File.join(root, seq_dir, "log-#{ite * 3}-#{ite * 4}.jtl"))
          end

          call_args = []
          FileUtils.stub!(:cp_r) { |*args| call_args << args }
          local_fs.export_jtl('any', root)
          reports_path = File.join(Hailstorm.root, Hailstorm.reports_dir)
          actual_files = call_args.map(&:last)
          (1..3).each do |ite|
            expect(actual_files).to include(File.join(reports_path, File.basename(root), "SEQ-#{ite}"))
          end
        end
      end
    end
  end

  context '#read_identity_file' do
    it 'should open an absolute path' do
      FileUtils.mkdir_p(Hailstorm.tmp_path)
      FileUtils.rm_rf(File.join(Hailstorm.tmp_path, '*'))
      file_path = File.join(Hailstorm.tmp_path, 'insecure.pem')
      FileUtils.touch(file_path)
      expect(local_fs.read_identity_file(file_path)).to_not be_nil
    end

    it 'should yield the file object' do
      FileUtils.mkdir_p(File.join(Hailstorm.root, Hailstorm.config_dir))
      FileUtils.rm_rf(File.join(Hailstorm.root, Hailstorm.config_dir, '*'))
      file_path = File.join(Hailstorm.root, Hailstorm.config_dir, 'insecure.pem')
      FileUtils.touch(file_path)
      file_objects = []
      local_fs.read_identity_file('insecure.pem', 'any') { |io| file_objects << io }
      expect(file_objects).to_not be_empty
    end
  end

  context '#copy_jtl' do
    it 'should copy the file to destination' do
      FileUtils.should_receive(:cp).with('/foo/bar.jtl', '/baz/bar.jtl')
      expect(local_fs.copy_jtl('any', from_path: '/foo/bar.jtl', to_path: '/baz')).to eq('/baz/bar.jtl')
    end
  end

  context '#export_report' do
    it 'should copy to report directory' do
      FileUtils.should_receive(:cp) do |_from, to|
        expect(to).to be == File.join(Hailstorm.root, Hailstorm.reports_dir, 'report.docx')
      end

      local_fs.export_report('any', '/path/to/report.docx')
    end
  end
end
