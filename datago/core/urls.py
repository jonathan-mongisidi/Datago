from django.urls import path
from . import views

urlpatterns = [
    path('', views.home, name='home'),
    path('about/', views.about, name='about'),
    path('datasets/', views.datasets, name='datasets'),
    path('datasets/<int:pk>/', views.dataset_detail, name='dataset_detail'),
    path('create/', views.create_dataset, name='create_dataset'),
    path('upload/', views.upload_dataset, name='upload_dataset'),
    path('signin/', views.sign_in_out, name='signin'),
    path('signup/', views.sign_up, name='signup'),
    path('change-profile/', views.change_profile_view, name='change_profile'),
    path('take-picture/', views.take_picture_view, name='take_picture'),
    path('upload-camera-image/', views.upload_camera_image, name='upload_camera_image'),
    path('logout/', views.logout_view, name='logout'),
    path('datasets/<int:pk>/delete/', views.delete_dataset, name='delete_dataset'),
    path('files/<int:pk>/delete/', views.delete_dataset_file, name='delete_dataset_file'),
    path('files/<int:pk>/download/', views.download_file, name='download_file'),
    path('datasets/<int:pk>/downloads-count/', views.get_dataset_downloads, name='get_dataset_downloads'),
    path('forgot-password/', views.forgot_password_view, name='forgot_password'),
    path('reset-password/', views.reset_password_view, name='reset_password'),
    path('requests/', views.dataset_requests_view, name='dataset_requests'),
    path('requests/<int:pk>/update-status/', views.update_dataset_request_status, name='update_dataset_request_status'),
    path('requests/<int:pk>/match/', views.find_matching_datasets, name='find_matching_datasets'),
    path('files/<int:pk>/clean/', views.clean_dataset_file, name='clean_dataset_file'),
]

