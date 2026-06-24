from django.contrib import admin
from .models import UserProfile, Dataset, DatasetFile, DatasetChangelog, Project, DatasetRequest

admin.site.register(UserProfile)
admin.site.register(Dataset)
admin.site.register(DatasetFile)
admin.site.register(DatasetChangelog)
admin.site.register(Project)
admin.site.register(DatasetRequest)
