from django.db import models
from django.contrib.auth.models import User
import os


class UserProfile(models.Model):
    """Menyimpan foto profil per user."""
    user            = models.OneToOneField(User, on_delete=models.CASCADE,
                                           related_name='profile')
    profile_picture = models.ImageField(upload_to='profile_pictures/',
                                        null=True, blank=True)

    def __str__(self):
        return f"Profile of {self.user.username}"


class Dataset(models.Model):
    """Menyimpan metadata sebuah dataset."""
    VISIBILITY_CHOICES = [
        ('public',  'Public'),
        ('private', 'Private'),
    ]

    owner       = models.ForeignKey(User, on_delete=models.CASCADE,
                                    related_name='datasets')
    title       = models.CharField(max_length=255)
    description = models.TextField(blank=True, default='')
    visibility  = models.CharField(max_length=10, choices=VISIBILITY_CHOICES,
                                   default='public')
    license     = models.CharField(max_length=100, blank=True, default='CC-BY-4.0')
    created_at  = models.DateTimeField(auto_now_add=True)
    updated_at  = models.DateTimeField(auto_now=True)
    download_count = models.IntegerField(default=0)

    def __str__(self):
        return self.title


class DatasetFile(models.Model):
    """Menyimpan file yang diunggah ke sebuah dataset (mendukung multi-versi)."""
    dataset     = models.ForeignKey(Dataset, on_delete=models.CASCADE,
                                    related_name='files')
    file        = models.FileField(upload_to='dataset_files/')
    version_tag = models.CharField(max_length=50, blank=True, default='v1.0.0')
    uploaded_at = models.DateTimeField(auto_now_add=True)

    @property
    def filename(self):
        return os.path.basename(self.file.name)

    @property
    def file_size_mb(self):
        try:
            return round(self.file.size / (1024 * 1024), 2)
        except Exception:
            return None

    def __str__(self):
        return f"{self.dataset.title} – {self.version_tag} – {self.filename}"


class DatasetChangelog(models.Model):
    """Merekam setiap perubahan yang terjadi pada dataset."""
    ACTION_CHOICES = [
        ('created',      'Dataset Dibuat'),
        ('file_added',   'File Ditambahkan'),
        ('meta_updated', 'Metadata Diperbarui'),
        ('file_deleted', 'File Dihapus'),
        ('project_link', 'Ditambahkan ke Proyek'),
    ]
    dataset     = models.ForeignKey(Dataset, on_delete=models.CASCADE,
                                    related_name='changelogs')
    user        = models.ForeignKey(User, on_delete=models.SET_NULL,
                                    null=True, blank=True)
    action      = models.CharField(max_length=20, choices=ACTION_CHOICES)
    description = models.TextField(blank=True)
    created_at  = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.dataset.title} – {self.action} – {self.created_at:%Y-%m-%d}"


class Project(models.Model):
    """Proyek yang menggunakan satu atau lebih dataset."""
    name        = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    owner       = models.ForeignKey(User, on_delete=models.CASCADE,
                                    related_name='projects')
    datasets    = models.ManyToManyField(Dataset, related_name='projects', blank=True)
    created_at  = models.DateTimeField(auto_now_add=True)
    updated_at  = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.name

class DatasetRequest(models.Model):
    STATUS_CHOICES = [
        ('PENDING', 'Pending'),
        ('IN_PROGRESS', 'In Progress'),
        ('COMPLETED', 'Completed'),
        ('REJECTED', 'Rejected'),
    ]
    URGENCY_CHOICES = [
        ('LOW', 'Low'),
        ('NORMAL', 'Normal'),
        ('HIGH', 'High Priority'),
    ]
    
    title = models.CharField(max_length=255)
    description = models.TextField()
    urgency = models.CharField(max_length=20, choices=URGENCY_CHOICES, default='NORMAL')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PENDING')
    result_file = models.FileField(upload_to='request_results/', null=True, blank=True)
    ic_contact_email = models.EmailField()
    ic_submission_id = models.IntegerField(null=True, blank=True, help_text="ID submission dari IC")
    min_rows = models.IntegerField(null=True, blank=True, help_text="Jumlah baris minimum (opsional)")
    required_columns = models.TextField(null=True, blank=True, help_text="Nama kolom yang harus ada, pisahkan dengan koma (opsional)")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.title} ({self.status})"
