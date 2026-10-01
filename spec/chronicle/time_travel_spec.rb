# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'ActiveRecord Time-Travel Queries (as_of and since)' do
  let(:mock_transport) { instance_double(Chronicle::Transport::CRubyClient) }
  let(:mock_db_snapshot) { double('DatomicDBSnapshot') }

  before do
    allow(Chronicle::Transport).to receive(:client).and_return(mock_transport)
    allow(Article).to receive(:chronicle_transport).and_return(mock_transport)
  end

  describe '.as_of time travel' do
    it 'attaches as_of timestamp to relation and passes it to the transport db snapshot' do
      target_time = Time.utc(2025, 1, 15, 12, 0, 0)

      expect(mock_transport).to receive(:db).with(hash_including(as_of: target_time)).and_return(mock_db_snapshot)
      expect(mock_transport).to receive(:q).with(anything, mock_db_snapshot, 'Ruby').and_return([
                                                                                                  { ':db/id' => 101,
                                                                                                    ':article/title' => 'Ruby 3.4 Released', ':article/view_count' => 1500 }
                                                                                                ])

      relation = Article.all.extending(Chronicle::Relation).as_of(target_time).where(title: 'Ruby')
      results = relation.to_a

      expect(results.size).to eq(1)
      expect(results.first.title).to eq('Ruby 3.4 Released')
      expect(results.first.view_count).to eq(1500)
      expect(results.first.persisted?).to be(true)
    end

    it 'supports basis-t transaction numbers as well as timestamps' do
      basis_t = 10_042

      expect(mock_transport).to receive(:db).with(hash_including(as_of: basis_t)).and_return(mock_db_snapshot)
      expect(mock_transport).to receive(:q).with(anything, mock_db_snapshot, 'ActiveRecord').and_return([
                                                                                                          {
                                                                                                            ':db/id' => 102, ':article/title' => 'ActiveRecord Datomic Adapter'
                                                                                                          }
                                                                                                        ])

      relation = Article.all.extending(Chronicle::Relation).as_of(basis_t).where(title: 'ActiveRecord')
      results = relation.to_a

      expect(results.first.id).to eq(102)
      expect(results.first.title).to eq('ActiveRecord Datomic Adapter')
    end
  end

  describe '.since time travel' do
    it 'attaches since parameter to relation to query incremental changes' do
      start_tx = 10_010

      expect(mock_transport).to receive(:db).with(hash_including(since: start_tx)).and_return(mock_db_snapshot)
      expect(mock_transport).to receive(:q).with(anything, mock_db_snapshot, 'Updated').and_return([
                                                                                                     { ':db/id' => 201,
                                                                                                       ':article/title' => 'Updated Post', ':article/view_count' => 20 }
                                                                                                   ])

      relation = Article.all.extending(Chronicle::Relation).since(start_tx).where(title: 'Updated')
      results = relation.to_a

      expect(results.first.id).to eq(201)
      expect(results.first.title).to eq('Updated Post')
    end
  end

  describe 'chained time-travel queries' do
    it 'allows chaining .as_of with standard Active Record scopes (.where, .select)' do
      past_time = Time.utc(2024, 6, 1)

      expect(mock_transport).to receive(:db).with(hash_including(as_of: past_time)).and_return(mock_db_snapshot)
      expect(mock_transport).to receive(:q).with(anything, mock_db_snapshot, true).and_return([
                                                                                                { ':db/id' => 301,
                                                                                                  ':article/title' => 'Legacy Post' }
                                                                                              ])

      relation = Article.all.extending(Chronicle::Relation)
                        .as_of(past_time)
                        .where(active: true)

      results = relation.to_a
      expect(results.first.title).to eq('Legacy Post')
    end
  end
end
