from django.urls import path
from . import views

urlpatterns = [
    path('', views.main, name='main'),
    path('data/', views.data, name='data'),
    path('data/<str:table_name>/', views.table_data, name='table_data'),
    path('data/<str:table_name>/create_row/', views.create_row, name='create_row'),
    path('data/<str:table_name>/edit_row/<str:pk>/', views.edit_row, name='edit_row'),
    path('data/<str:table_name>/delete_row/<str:pk>/', views.delete_row, name='delete_row'),
    path('data/<str:table_name>/clear_table/', views.clear_table, name='clear_table'),
    path('data/<str:table_name>/import/', views.import_table, name='import_table'),
    path('data/<str:table_name>/export/', views.export_table, name='export_table'),
    path('operations/', views.operations, name='operations'),
    path('operations/operations_export', views.operations_export, name='operations_export')
]
