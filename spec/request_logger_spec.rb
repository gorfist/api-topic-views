# frozen_string_literal: true

require 'rails_helper'

describe ApiTopicViews::RequestLogger do
  before do
    SiteSetting.api_topic_views_enabled = true
  end

  let(:topic) { Fabricate(:topic) }
  let(:user) { Fabricate(:user) }
  let(:ip_address) { "192.168.1.1" }

  describe ".track_api_topic_view" do
    let(:env) do
      {
        "REQUEST_METHOD" => "GET",
        "PATH_INFO" => "/t/test-topic/#{topic.id}",
        "action_dispatch.remote_ip" => ip_address
      }
    end

    let(:data) do
      {
        is_api: true,
        is_user_api: false,
        status: 200,
        is_background: false,
        is_crawler: false
      }
    end

    context "when plugin is enabled" do
      it "enqueues a job to track the view" do
        expect {
          described_class.track_api_topic_view(env, data)
        }.to change { Jobs::TrackApiTopicView.jobs.size }.by(1)
      end

      it "includes topic_id in the job" do
        described_class.track_api_topic_view(env, data)
        job = Jobs::TrackApiTopicView.jobs.last
        expect(job["args"].first["topic_id"]).to eq(topic.id)
      end

      it "includes ip address in the job" do
        described_class.track_api_topic_view(env, data)
        job = Jobs::TrackApiTopicView.jobs.last
        expect(job["args"].first["ip"]).to eq(ip_address)
      end
    end

    context "when plugin is disabled" do
      before { SiteSetting.api_topic_views_enabled = false }

      it "does not enqueue a job" do
        expect {
          described_class.track_api_topic_view(env, data)
        }.not_to change { Jobs::TrackApiTopicView.jobs.size }
      end
    end

    context "when request is not from API" do
      before do
        data[:is_api] = false
        data[:is_user_api] = false
      end

      it "does not enqueue a job" do
        expect {
          described_class.track_api_topic_view(env, data)
        }.not_to change { Jobs::TrackApiTopicView.jobs.size }
      end
    end

    context "when status is not 200" do
      before { data[:status] = 404 }

      it "does not enqueue a job" do
        expect {
          described_class.track_api_topic_view(env, data)
        }.not_to change { Jobs::TrackApiTopicView.jobs.size }
      end
    end

    context "when request is from a crawler" do
      before { data[:is_crawler] = true }

      it "does not enqueue a job" do
        expect {
          described_class.track_api_topic_view(env, data)
        }.not_to change { Jobs::TrackApiTopicView.jobs.size }
      end
    end

    context "when custom header is required" do
      before do
        SiteSetting.api_topic_views_require_header = "X-Count-As-View"
      end

      it "does not track without the header" do
        expect {
          described_class.track_api_topic_view(env, data)
        }.not_to change { Jobs::TrackApiTopicView.jobs.size }
      end

      it "tracks with the header present" do
        env["HTTP_X_COUNT_AS_VIEW"] = "true"
        expect {
          described_class.track_api_topic_view(env, data)
        }.to change { Jobs::TrackApiTopicView.jobs.size }.by(1)
      end
    end
  end
end

