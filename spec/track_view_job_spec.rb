# frozen_string_literal: true

require 'rails_helper'

describe Jobs::TrackApiTopicView do
  let(:topic) { Fabricate(:topic) }
  let(:user) { Fabricate(:user) }
  let(:ip_address) { "192.168.1.1" }

  describe "#execute" do
    it "increments topic view count" do
      initial_views = topic.views
      
      subject.execute({
        topic_id: topic.id,
        ip: ip_address,
        user_id: nil
      })

      topic.reload
      expect(topic.views).to eq(initial_views + 1)
    end

    it "tracks user visit when user is present" do
      expect {
        subject.execute({
          topic_id: topic.id,
          ip: ip_address,
          user_id: user.id
        })
      }.to change { TopicUser.where(topic_id: topic.id, user_id: user.id).count }
    end

    it "handles missing topic gracefully" do
      expect {
        subject.execute({
          topic_id: 999999,
          ip: ip_address,
          user_id: nil
        })
      }.not_to raise_error
    end

    it "handles missing parameters gracefully" do
      expect {
        subject.execute({})
      }.not_to raise_error
    end
  end
end

