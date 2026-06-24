from django.urls import path, include
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from . import api_views
from .serializers import CustomTokenObtainPairSerializer

class CustomTokenObtainPairView(TokenObtainPairView):
    serializer_class = CustomTokenObtainPairSerializer

router = DefaultRouter()
router.register(r'datasets', api_views.DatasetViewSet, basename='api-dataset')
router.register(r'files', api_views.DatasetFileViewSet, basename='api-dataset-file')
router.register(r'projects', api_views.ProjectViewSet, basename='api-project')
router.register(r'requests', api_views.DatasetRequestViewSet, basename='api-dataset-request')

urlpatterns = [
    path('auth/login/', CustomTokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('auth/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('auth/register/', api_views.RegisterView.as_view(), name='api_register'),
    path('auth/me/', api_views.CurrentUserView.as_view(), name='api_current_user'),
    path('auth/profile-picture/', api_views.ProfilePictureUpdateView.as_view(), name='api_profile_picture_update'),
    path('auth/reset-password/', api_views.PasswordResetAPIView.as_view(), name='api_reset_password'),
    path('stats/', api_views.DashboardStatsView.as_view(), name='api_stats'),
    path('', include(router.urls)),
]
