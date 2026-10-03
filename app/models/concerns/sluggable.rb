# Slugs are the public identity of content: generated once from a source
# attribute, then treated as stable so bookmarked URLs keep working.
#
# Most content is addressed globally (`/topics/sql-joins`), but nested content
# such as a lesson only needs to be unique within its parent. The uniqueness
# check is therefore written by hand and reads `slug_uniqueness_scope` at
# validation time — Rails' built-in uniqueness validator captures its `scope`
# option when the class body is evaluated, which is before a subclass has had a
# chance to declare one.
module Sluggable
  extend ActiveSupport::Concern

  included do
    class_attribute :slug_source_attribute, instance_writer: false, default: :name
    class_attribute :slug_uniqueness_scope, instance_writer: false, default: []

    before_validation :generate_slug, if: -> { slug.blank? }

    validates :slug, presence: true,
                     format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/,
                               message: "must be lowercase words separated by hyphens" }
    validate :slug_must_be_unique
  end

  class_methods do
    # Declares which attribute the slug is derived from.
    def slug_from(attribute)
      self.slug_source_attribute = attribute
    end

    # Declares the column(s) the slug must be unique within.
    def slug_unique_within(*columns)
      self.slug_uniqueness_scope = columns.flatten.compact
    end

    def slug_source
      slug_source_attribute
    end

    def find_by_slug!(value)
      find_by!(slug: value.to_s.downcase)
    end
  end

  private

  def generate_slug
    self.slug = public_send(self.class.slug_source).to_s.parameterize.presence
  end

  def slug_must_be_unique
    return if slug.blank?

    scope = self.class.where(slug: slug)
    scope = scope.where.not(id: id) if persisted?
    self.class.slug_uniqueness_scope.each do |column|
      scope = scope.where(column => public_send(column))
    end

    errors.add(:slug, "has already been taken") if scope.exists?
  end
end
