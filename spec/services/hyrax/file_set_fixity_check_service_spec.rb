require 'spec_helper'

RSpec.describe Hyrax::FileSetFixityCheckService do
  let(:f)                 { create(:file_set, content: File.open(fixture_path + '/world.png')) }
  let(:service_by_object) { described_class.new(f) }
  let(:service_by_id)     { described_class.new(f.id) }

  describe '#fixity_check' do
    context 'when a file has two versions' do
      before do
        Hyrax::VersioningService.create(f.original_file) # create a second version -- the factory creates the first version when it attaches +content+
      end
      subject { service_by_object.fixity_check[f.original_file.id] }
      specify 'returns two log results' do
        expect(subject.length).to eq(2)
      end
    end
  end

  describe '#fixity_check_file' do
    subject { service_by_object.send(:fixity_check_file, f.original_file) }
    specify 'returns a single result' do
      expect(subject.length).to eq(1)
    end
  end

  describe '#fixity_check_file_version' do
    subject { service_by_object.send(:fixity_check_file_version, f.original_file.id, f.original_file.uri) }
    specify 'returns a single ChecksumAuditLog for the given file' do
      expect(subject).to be_kind_of ChecksumAuditLog
      expect(subject.file_set_id).to eq(f.id)
      expect(subject.checked_uri).to eq(f.original_file.uri)
    end
  end

  describe '#logged_fixity_status' do
    context "with an object" do
      subject { service_by_object.logged_fixity_status }

      it "doesn't trigger fixity checks" do
        expect(service_by_object).not_to receive(:fixity_check_file)
        expect(subject).to eq "Fixity checks have not yet been run on this object"
      end

      context "when no fixity check is passing" do
        before do
          ChecksumAuditLog.create!(pass: 1, file_set_id: f.id, checked_uri: f.original_file.versions.first.label, file_id: 'original_file')
        end

        it "reports the fixity check result" do
          expect(subject).to include "passed"
        end
      end

      context "when most recent fixity check is passing" do
        before do
          ChecksumAuditLog.create!(pass: 0, file_set_id: f.id, checked_uri: f.original_file.versions.first.label, file_id: 'original_file', created_at: 1.day.ago)
          ChecksumAuditLog.create!(pass: 1, file_set_id: f.id, checked_uri: f.original_file.versions.first.label, file_id: 'original_file')
        end

        it "records the fixity check result" do
          expect(subject).to include "passed"
        end
      end
    end

    context "with an id" do
      subject { service_by_id.logged_fixity_status }

      before do
        ChecksumAuditLog.create!(pass: 1, file_set_id: f.id, checked_uri: f.original_file.versions.first.label, file_id: 'original_file')
      end

      it "records the fixity result" do
        expect(subject).to include "passed"
      end
    end
  end
end
