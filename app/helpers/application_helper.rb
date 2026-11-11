module ApplicationHelper
  def fa_icon(name, style: :solid, **attributes)
    classes = [ "fa-#{style}", "fa-#{name.to_s.tr("_", "-")}", attributes.delete(:class) ].compact
    aria = attributes.delete(:aria) || {}
    aria[:hidden] = true unless aria[:label].present?

    tag.i(**attributes, class: classes, aria: aria)
  end
end
