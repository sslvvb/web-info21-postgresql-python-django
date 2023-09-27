from django import template

register = template.Library()


@register.filter(name='getattr')
def get_attribute(value, arg):
    try:
        return getattr(value, arg)
    except AttributeError:
        return None
