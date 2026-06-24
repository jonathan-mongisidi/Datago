from rest_framework import serializers
from django.contrib.auth.models import User
from .models import UserProfile, Dataset, DatasetFile, DatasetChangelog, Project, DatasetRequest

class UserProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserProfile
        fields = ['profile_picture']

class UserSerializer(serializers.ModelSerializer):
    profile = UserProfileSerializer(read_only=True)
    
    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'first_name', 'last_name', 'profile']

class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)
    
    class Meta:
        model = User
        fields = ['username', 'email', 'first_name', 'password']
        
    def create(self, validated_data):
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            first_name=validated_data.get('first_name', ''),
            password=validated_data['password']
        )
        return user

class DatasetFileSerializer(serializers.ModelSerializer):
    filename = serializers.ReadOnlyField()
    file_size_mb = serializers.ReadOnlyField()
    
    class Meta:
        model = DatasetFile
        fields = ['id', 'file', 'version_tag', 'uploaded_at', 'filename', 'file_size_mb']

class DatasetChangelogSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.first_name', read_only=True)
    
    class Meta:
        model = DatasetChangelog
        fields = ['id', 'action', 'description', 'created_at', 'user_name']

class DatasetSerializer(serializers.ModelSerializer):
    owner = UserSerializer(read_only=True)
    files = DatasetFileSerializer(many=True, read_only=True)
    changelogs = DatasetChangelogSerializer(many=True, read_only=True)
    projects = serializers.SerializerMethodField()
    
    class Meta:
        model = Dataset
        fields = ['id', 'title', 'description', 'visibility', 'license', 'created_at', 'updated_at', 'download_count', 'owner', 'files', 'changelogs', 'projects']

    def get_projects(self, obj):
        return [{'id': p.id, 'name': p.name, 'owner': p.owner.username} for p in obj.projects.all()]

class DatasetRequestSerializer(serializers.ModelSerializer):
    class Meta:
        model = DatasetRequest
        fields = ['id', 'title', 'description', 'urgency', 'status', 'result_file', 'ic_contact_email', 'min_rows', 'required_columns', 'created_at', 'updated_at']
        read_only_fields = ['result_file', 'created_at', 'updated_at']

class ProjectSerializer(serializers.ModelSerializer):
    owner = UserSerializer(read_only=True)
    datasets = DatasetSerializer(many=True, read_only=True)
    dataset_ids = serializers.PrimaryKeyRelatedField(
        many=True, write_only=True, queryset=Dataset.objects.all(), source='datasets', required=False
    )
    
    class Meta:
        model = Project
        fields = ['id', 'name', 'description', 'created_at', 'updated_at', 'owner', 'datasets', 'dataset_ids']

from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Jadikan username tidak required agar bisa menerima 'email' dari mobile
        self.fields['username'].required = False

    def validate(self, attrs):
        # Ambil input pengguna: bisa dari 'username' atau 'email'
        username_input = attrs.get('username') or self.initial_data.get('email')
        
        if username_input:
            # Hilangkan spasi berlebih yang sering ditambahkan otomatis oleh keyboard HP
            username_input = username_input.strip()
            
            # Cek apakah input tersebut adalah email yang terdaftar (case-insensitive)
            user = User.objects.filter(email__iexact=username_input).first()
            if user:
                # Jika ketemu, gunakan username asli user tersebut
                attrs['username'] = user.username
            else:
                attrs['username'] = username_input

        # Lempar error jika tetap kosong
        if not attrs.get('username'):
            from rest_framework.exceptions import ValidationError
            raise ValidationError('Username atau email wajib diisi.')

        return super().validate(attrs)
