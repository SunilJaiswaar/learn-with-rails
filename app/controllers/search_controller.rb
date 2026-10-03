# Global search across every kind of content (spec 66).
class SearchController < ApplicationController
  def index
    @query = params[:q].to_s.strip
    @results = @query.length >= 2 ? Search::Global.new(query: @query).call : {}
    @total = @results.values.sum(&:size)
  end
end
