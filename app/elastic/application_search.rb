module ApplicationSearch
  extend ActiveSupport::Concern

  included do
    include Elasticsearch::Model

    index_name [Rails.application.class.parent_name.downcase, self.name.downcase, Rails.env.to_s].join('-')

    settings \
      index: {
      query: {
        default_field: :name
      },
      analysis: {
        :analyzer => {
          :index_analyzer => {
            type: "custom",
            tokenizer: "ngram_tokenizer",
            filter: %w(lowercase asciifolding name_ngrams)
          },
          :search_analyzer => {
            type: "custom",
            tokenizer: "standard",
            filter: %w(lowercase asciifolding )
          }
        },
        tokenizer: {
          ngram_tokenizer: {
            type: "NGram",
            min_gram: 1,
            max_gram: 20,
            token_chars: %w(letter digit)
          }
        },
        filter: {
          name_ngrams: {
            type:     "NGram",
            max_gram: 20,
            min_gram: 1
          }
        }
      }
    }

    after_commit lambda { Elastic::BaseIndexer.perform_async(:index,  self.class.to_s, self.id) }, on: :create
    after_commit lambda { Elastic::BaseIndexer.perform_async(:update, self.class.to_s, self.id) }, on: :update
    after_commit lambda { Elastic::BaseIndexer.perform_async(:delete, self.class.to_s, self.id) }, on: :destroy
    after_touch  lambda { Elastic::BaseIndexer.perform_async(:update, self.class.to_s, self.id) }
  end
end