# Slugs are the public identity of content; they are generated once and then
# treated as stable so bookmarked URLs keep working.
module Sluggable
  extend ActiveSupport::Concern

  included do
    before_validation :generate_slug, if: -> { slug.blank? }

    validates :slug, presence: true,
                     uniqueness: { case_sensitive: false },
                     format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/,
                               message: "must be lowercase words separated by hyphens" }
  end

  class_methods do
    def slug_source
      :name
    end

    # Content is addressed by slug everywhere in the UI.
    def find_by_slug!(value)
      find_by!(slug: value.to_s.downcase)
    end
  end

  private

  def generate_slug
    source = public_send(self.class.slug_source)
    self.slug = source.to_s.parameterize.presence
  end
end
