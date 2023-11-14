# frozen_string_literal: true

require 'spec_helper'

describe MeterReadingsFeeds::N3rgyConsentApi do
  describe 'when modifying consent' do
    let(:mpxn) { 1_234_567_891_234 }

    before do
      @api = described_class.new('abc123', 'https://api.com')
    end

    describe 'grant' do
      let(:ref)     { 'some random guid' }
      let(:success) { { 'status' => { 'messages' => ['2234567891000 was submitted successfully.'], 'code' => '200' } } }
      let(:failure) { { 'errors' => [{ 'code' => 404, 'message' => 'Unsuccessful trusted consent to property' }] } }
      let(:auth_failure) { { 'message' => 'Unauthorized' } }

      before do
        expect(Faraday).to receive(:post).and_return(response)
      end

      context 'when success' do
        let(:response) { double(success?: true, body: success.to_json) }

        it 'returns true' do
          expect(@api.grant_trusted_consent(mpxn, ref)).to eq(success)
        end
      end

      context 'when failed' do
        let(:response) { double(success?: false, body: failure.to_json) }

        it 'raises error' do
          expect do
            @api.grant_trusted_consent(mpxn, ref)
          end.to raise_error(MeterReadingsFeeds::N3rgyConsentApi::ConsentFailed,
                             'Unsuccessful trusted consent to property')
        end
      end

      context 'when authorization problem' do
        let(:response) { double(success?: false, body: auth_failure.to_json) }

        it 'raises error' do
          expect do
            @api.grant_trusted_consent(mpxn, ref)
          end.to raise_error(MeterReadingsFeeds::N3rgyConsentApi::ConsentFailed, 'Unauthorized')
        end
      end
    end

    describe 'withdraw' do
      let(:success) { '' }
      let(:failure) { { 'errors' => [{ 'code' => 404, 'message' => 'No consent found' }] } }

      before do
        expect(Faraday).to receive(:put).and_return(response)
      end

      context 'when success' do
        let(:response) { double(success?: true, body: success.to_json) }

        it 'returns true' do
          expect(@api.withdraw_trusted_consent(mpxn)).to be true
        end
      end

      context 'when failed' do
        let(:response) { double(success?: false, body: failure.to_json) }

        it 'raises error' do
          expect do
            @api.withdraw_trusted_consent(mpxn)
          end.to raise_error(MeterReadingsFeeds::N3rgyConsentApi::ConsentFailed)
        end
      end
    end
  end
end
