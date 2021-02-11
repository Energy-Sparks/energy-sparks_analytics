require 'spec_helper'

describe MeterReadingsFeeds::N3rgyConsentApi do

  describe 'when modifying consent' do

    let(:mpxn)          { 1234567891234 }

    before :each do
      @api = MeterReadingsFeeds::N3rgyConsentApi.new('abc123', 'https://api.com')
    end

    describe 'grant' do
      let(:ref)     { 'some random guid' }
      let(:success) { {'status' => {'messages' => ['2234567891000 was submitted successfully.'], 'code' => '200'}} }
      let(:failure) { {'errors' => [{'code' => 404, 'message' => 'Unsuccessful trusted consent to property'}]} }

      before :each do
        expect(Faraday).to receive(:post).and_return(response)
      end

      context 'when success' do
        let(:response) { double(success?: true, body: success.to_json) }
        it 'returns true' do
          expect(@api.grant_trusted_consent(mpxn, ref)).to eq(success)
        end
      end

      context 'when failed' do
        let(:response) { double(success?: false , body: failure.to_json) }
        it 'raises error' do
          expect{
            @api.grant_trusted_consent(mpxn, ref)
          }.to raise_error(MeterReadingsFeeds::N3rgyConsentApi::ConsentFailed)
        end
      end
    end

    describe 'withdraw' do
      let(:success) { '' }
      let(:failure) { {'errors' => [{'code' => 404, 'message' => 'No consent found'}]} }

      before :each do
        expect(Faraday).to receive(:put).and_return(response)
      end

      context 'when success' do
        let(:response) { double(success?: true, body: success.to_json) }
        it 'returns true' do
          expect(@api.withdraw_trusted_consent(mpxn)).to be true
        end
      end

      context 'when failed' do
        let(:response) { double(success?: false , body: failure.to_json) }
        it 'raises error' do
          expect{
            @api.withdraw_trusted_consent(mpxn)
          }.to raise_error(MeterReadingsFeeds::N3rgyConsentApi::ConsentFailed)
        end
      end
    end

  end
end
