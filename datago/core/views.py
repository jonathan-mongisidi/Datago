from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.models import User
from django.contrib import messages
from django.contrib.auth.decorators import login_required
from django.db.models import Q
from .models import UserProfile, Dataset, DatasetFile, DatasetChangelog, Project, DatasetRequest
import random
import os
import tempfile
from django.core.files import File

# ─── Avatar Color Palette ───
AVATAR_COLORS = [
    '#42A5F5',  # Biru Muda
    '#EF5350',  # Merah
    '#66BB6A',  # Hijau
    '#FFA726',  # Kuning
    '#EC407A',  # Pink
    '#1565C0',  # Biru Tua
]

def get_avatar_color(request):
    """
    Mengembalikan warna avatar dari session.
    Jika belum ada, pilih warna acak, simpan ke session, dan kembalikan.
    """
    if 'avatar_color' not in request.session:
        request.session['avatar_color'] = random.choice(AVATAR_COLORS)
    return request.session['avatar_color']

def get_profile_picture(user):
    """Mengembalikan objek ImageField foto profil user, atau None jika belum ada."""
    try:
        return user.profile.profile_picture
    except UserProfile.DoesNotExist:
        return None

def home(request):
    # Dynamic statistics calculated from actual datasets in the database
    COLORS = ['#8B00FF', '#FF0000', '#00FFCC', '#FFCC00', '#FF00FF', '#00CCFF']
    
    # 1. Total Datasets per Year (In-memory grouping for maximum database compatibility)
    datasets = Dataset.objects.all()
    datasets_by_year = {}
    total_datasets = len(datasets)
    
    for ds in datasets:
        year = ds.created_at.year if ds.created_at else None
        if year is None:
            import datetime
            year = datetime.datetime.now().year
        datasets_by_year[year] = datasets_by_year.get(year, 0) + 1
        
    total_datasets_per_year = []
    CHART1_POSITIONS = [
        'top: 10%; right: 5%;',
        'bottom: 25%; left: 0%;',
        'bottom: 12%; right: 10%;',
        'top: 40%; left: -5%;',
        'top: 50%; right: -5%;'
    ]
    
    if total_datasets > 0:
        sorted_years = sorted(datasets_by_year.keys())
        for i, year in enumerate(sorted_years):
            count = datasets_by_year[year]
            percentage = round((count / total_datasets) * 100, 1)
            percentage_str = str(percentage).replace('.', ',')
            if percentage_str.endswith(',0'):
                percentage_str = percentage_str[:-2]
                
            color = COLORS[i % len(COLORS)]
            position = CHART1_POSITIONS[i % len(CHART1_POSITIONS)]
            
            total_datasets_per_year.append({
                'year': year,
                'percentage': percentage,
                'percentage_display': percentage_str,
                'color': color,
                'position': position
            })
            
    # 2. Total Downloads per Year (simulated dynamically based on actual datasets to avoid empty charts)
    downloads_by_year = {}
    total_downloads = 0
    
    for ds in datasets:
        year = ds.created_at.year if ds.created_at else None
        if year is None:
            import datetime
            year = datetime.datetime.now().year
        # Deterministic formula simulating downloads for each dataset
        sim_downloads = (ds.id * 37) % 150 + 15
        downloads_by_year[year] = downloads_by_year.get(year, 0) + sim_downloads
        total_downloads += sim_downloads
        
    total_downloads_per_year = []
    CHART2_POSITIONS = [
        'top: 12%; left: 5%;',
        'bottom: 5%; left: 18%;',
        'bottom: 30%; right: -2%;',
        'top: 40%; right: 5%;',
        'top: 55%; left: -5%;'
    ]
    
    if total_downloads > 0:
        sorted_years = sorted(downloads_by_year.keys())
        for i, year in enumerate(sorted_years):
            count = downloads_by_year[year]
            percentage = round((count / total_downloads) * 100, 1)
            percentage_str = str(percentage).replace('.', ',')
            if percentage_str.endswith(',0'):
                percentage_str = percentage_str[:-2]
                
            color = COLORS[i % len(COLORS)]
            position = CHART2_POSITIONS[i % len(CHART2_POSITIONS)]
            
            total_downloads_per_year.append({
                'year': year,
                'percentage': percentage,
                'percentage_display': percentage_str,
                'color': color,
                'position': position
            })
            
    context = {
        'avatar_color': get_avatar_color(request),
        'profile_picture': get_profile_picture(request.user) if request.user.is_authenticated else None,
        'total_datasets_per_year': total_datasets_per_year,
        'total_downloads_per_year': total_downloads_per_year,
    }
    return render(request, 'core/home.html', context)

def about(request):
    return render(request, 'core/about.html', {
        'avatar_color': get_avatar_color(request),
        'profile_picture': get_profile_picture(request.user) if request.user.is_authenticated else None,
    })

def datasets(request):
    query = request.GET.get('q', '').strip()

    # Tampilkan dataset public + dataset milik user sendiri (bila login)
    if request.user.is_authenticated:
        qs = Dataset.objects.filter(
            Q(visibility='public') | Q(owner=request.user)
        ).distinct()
    else:
        qs = Dataset.objects.filter(visibility='public')

    if query:
        qs = qs.filter(
            Q(title__icontains=query) |
            Q(description__icontains=query) |
            Q(owner__first_name__icontains=query) |
            Q(owner__username__icontains=query)
        )

    qs = qs.select_related('owner').prefetch_related('files').order_by('-created_at')

    return render(request, 'core/datasets.html', {
        'datasets':        qs,
        'search_query':    query,
        'avatar_color':    get_avatar_color(request),
        'profile_picture': get_profile_picture(request.user) if request.user.is_authenticated else None,
    })

def create_dataset(request):
    """
    Wizard Step 1 – simpan metadata dataset ke session.
    Step 2 – upload file, buat Dataset + DatasetFile di DB.
    """
    # Jika belum login, render halaman dengan modal peringatan
    if not request.user.is_authenticated:
        return render(request, 'core/create_dataset.html', {
            'avatar_color':       get_avatar_color(request),
            'profile_picture':    None,
            'show_login_warning': True,
            'show_step2':         False,
        })

    if request.method == 'POST':
        step = request.POST.get('wizard_step', '1')

        if step == '1':
            # Simpan data Step 1 ke session lalu tampilkan Step 2
            request.session['ds_title']      = request.POST.get('dataset_title', '').strip()
            request.session['ds_desc']       = request.POST.get('dataset_desc', '').strip()
            request.session['ds_visibility'] = request.POST.get('dataset_visibility', 'public')
            request.session['ds_license']    = request.POST.get('dataset_license', 'CC-BY-4.0').strip()
            return render(request, 'core/create_dataset.html', {
                'avatar_color':    get_avatar_color(request),
                'profile_picture': get_profile_picture(request.user),
                'show_step2':      True,
                'step1_data': {
                    'title':      request.session['ds_title'],
                    'desc':       request.session['ds_desc'],
                    'visibility': request.session['ds_visibility'],
                    'license':    request.session['ds_license'],
                },
            })

        elif step == '2':
            # Ambil metadata dari session
            title      = request.session.pop('ds_title', '')
            desc       = request.session.pop('ds_desc', '')
            visibility = request.session.pop('ds_visibility', 'public')
            lic        = request.session.pop('ds_license', 'CC-BY-4.0')

            if not title:
                messages.error(request, 'Data Step 1 hilang. Silakan mulai dari awal.')
                return redirect('create_dataset')

            # Buat objek Dataset
            dataset = Dataset.objects.create(
                owner=request.user,
                title=title,
                description=desc,
                visibility=visibility,
                license=lic,
            )

            # Upload file (boleh kosong — user bisa upload nanti)
            version_tag = request.POST.get('upload_version', 'v1.0.0').strip()
            uploaded_files = request.FILES.getlist('dataset_files')
            for f in uploaded_files:
                DatasetFile.objects.create(
                    dataset=dataset,
                    file=f,
                    version_tag=version_tag,
                )
                DatasetChangelog.objects.create(
                    dataset=dataset,
                    user=request.user,
                    action='file_added',
                    description=f'File "{f.name}" versi {version_tag} diunggah.',
                )

            # Changelog: dataset dibuat
            DatasetChangelog.objects.create(
                dataset=dataset,
                user=request.user,
                action='created',
                description=(
                    f'Dataset "{dataset.title}" dibuat dengan visibilitas '
                    f'{dataset.get_visibility_display()} dan lisensi {dataset.license}.'
                ),
            )

            messages.success(request, f'Dataset "{dataset.title}" berhasil dibuat!')
            return redirect('dataset_detail', pk=dataset.pk)

    # GET – tampilkan Step 1
    return render(request, 'core/create_dataset.html', {
        'avatar_color':    get_avatar_color(request),
        'profile_picture': get_profile_picture(request.user),
        'show_step2':      False,
    })


def upload_dataset(request):
    """Fallback – redirect ke wizard."""
    return redirect('create_dataset')


# ─────────────────────────────────────────────────────────
# CSV Statistics Helper
# ─────────────────────────────────────────────────────────

def compute_csv_stats(filepath):
    """Parse file CSV dan kembalikan statistik deskriptif dasar."""
    import csv
    try:
        with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
            reader = csv.DictReader(f)
            rows = []
            for i, row in enumerate(reader):
                if i >= 10000:   # cap 10 000 baris
                    break
                rows.append(row)

        if not rows:
            return {'empty': True}

        columns    = list(rows[0].keys())
        row_count  = len(rows)
        col_count  = len(columns)
        total_miss = 0
        col_stats  = []

        for col in columns:
            values   = [r.get(col, '') or '' for r in rows]
            missing  = sum(1 for v in values if not v.strip())
            total_miss += missing
            non_miss = [v for v in values if v.strip()]

            nums = []
            for v in non_miss:
                try:
                    nums.append(float(v.replace(',', '.')))
                except (ValueError, AttributeError):
                    pass

            is_num = bool(non_miss) and len(nums) >= len(non_miss) * 0.7

            cs = {
                'name':        col,
                'type':        'Numerik' if is_num else 'Teks',
                'missing':     missing,
                'missing_pct': round(missing / row_count * 100, 1) if row_count else 0,
                'unique':      len(set(v for v in values if v.strip())),
                'min': None, 'max': None, 'mean': None, 'std': None,
            }
            if is_num and nums:
                mean = sum(nums) / len(nums)
                variance = sum((x - mean) ** 2 for x in nums) / len(nums)
                cs.update({
                    'min':  round(min(nums), 3),
                    'max':  round(max(nums), 3),
                    'mean': round(mean, 3),
                    'std':  round(variance ** 0.5, 3),
                })
            col_stats.append(cs)

        total_cells   = row_count * col_count
        quality_score = round((1 - total_miss / total_cells) * 100, 1) if total_cells else 100.0
        display_cols  = columns[:10]

        return {
            'row_count':     row_count,
            'col_count':     col_count,
            'columns':       col_stats,
            'total_missing': total_miss,
            'quality_score': quality_score,
            'sample_headers': display_cols,
            'sample_rows':   [
                [row.get(c, '') for c in display_cols]
                for row in rows[:5]
            ],
            'truncated': len(rows) >= 10000,
        }
    except Exception as e:
        return {'error': str(e)}


# ─────────────────────────────────────────────────────────
# Dataset Detail
# ─────────────────────────────────────────────────────────

def dataset_detail(request, pk):
    """Halaman detail dataset: overview, statistik CSV, changelog, proyek."""
    dataset = get_object_or_404(Dataset, pk=pk)

    # Private dataset hanya bisa dilihat pemilik
    if dataset.visibility == 'private' and request.user != dataset.owner:
        messages.error(request, 'Dataset ini bersifat private.')
        return redirect('datasets')

    files      = dataset.files.all().order_by('-uploaded_at')
    changelogs = dataset.changelogs.all()
    projects   = dataset.projects.all().select_related('owner')

    # Statistik CSV (file pertama yang ditemukan)
    stats = None
    for f in files:
        if f.file.name.lower().endswith('.csv'):
            try:
                stats = compute_csv_stats(f.file.path)
            except Exception:
                pass
            break

    # Proyek milik user yang login (untuk form tambah ke proyek)
    user_projects = []
    if request.user.is_authenticated:
        user_projects = Project.objects.filter(owner=request.user)

    # Handle POST: tambah ke proyek
    if request.method == 'POST' and request.user.is_authenticated:
        project_id = request.POST.get('project_id', '').strip()
        new_name   = request.POST.get('new_project_name', '').strip()
        new_desc   = request.POST.get('new_project_desc', '').strip()

        if project_id:
            project = get_object_or_404(Project, pk=project_id, owner=request.user)
            project.datasets.add(dataset)
            DatasetChangelog.objects.create(
                dataset=dataset, user=request.user,
                action='project_link',
                description=f'Dataset ditambahkan ke proyek “{project.name}”.',
            )
            messages.success(request, f'Dataset ditambahkan ke proyek “{project.name}”!')
        elif new_name:
            project = Project.objects.create(
                name=new_name, description=new_desc, owner=request.user
            )
            project.datasets.add(dataset)
            DatasetChangelog.objects.create(
                dataset=dataset, user=request.user,
                action='project_link',
                description=f'Dataset ditambahkan ke proyek baru “{project.name}”.',
            )
            messages.success(request, f'Proyek “{project.name}” berhasil dibuat!')
        else:
            messages.error(request, 'Pilih atau masukkan nama proyek terlebih dahulu.')

        return redirect('dataset_detail', pk=pk)

    return render(request, 'core/dataset_detail.html', {
        'dataset':       dataset,
        'files':         files,
        'changelogs':    changelogs,
        'projects':      projects,
        'stats':         stats,
        'user_projects': user_projects,
        'avatar_color':    get_avatar_color(request),
        'profile_picture': get_profile_picture(request.user) if request.user.is_authenticated else None,
    })

def sign_in_out(request):
    if request.user.is_authenticated:
        return redirect('home')

    error_message = None
    if request.method == 'POST':
        email = request.POST.get('email', '').strip()
        password = request.POST.get('password', '')

        if not email or not password:
            error_message = "Email dan password wajib diisi."
        else:
            # Check if a user matches the email address
            user = User.objects.filter(email=email).first()
            if user:
                username = user.username
            else:
                username = email
            
            # Authenticate
            authenticated_user = authenticate(request, username=username, password=password)
            if authenticated_user is not None:
                login(request, authenticated_user)
                next_url = request.GET.get('next', 'home')
                if not next_url:
                    next_url = 'home'
                return redirect(next_url)
            else:
                error_message = "Email atau password salah."

    return render(request, 'core/signin.html', {'error': error_message})


def sign_up(request):
    if request.user.is_authenticated:
        return redirect('home')

    error_message = None
    success_message = None
    form_data = {}

    if request.method == 'POST':
        name     = request.POST.get('name', '').strip()
        email    = request.POST.get('email', '').strip()
        password = request.POST.get('password', '')

        form_data = {'name': name, 'email': email}

        if not name or not email or not password:
            error_message = "Semua field wajib diisi."
        elif len(password) < 8:
            error_message = "Password minimal 8 karakter."
        elif User.objects.filter(email=email).exists():
            error_message = "Email ini sudah terdaftar. Silakan Sign In."
        else:
            # Gunakan email sebagai username agar unik
            username = email
            user = User.objects.create_user(
                username=username,
                email=email,
                password=password,
                first_name=name,
            )
            user.save()
            # Auto-login setelah registrasi berhasil
            login(request, user)
            return redirect('home')

    return render(request, 'core/signup.html', {
        'error': error_message,
        'success': success_message,
        'form_data': form_data,
    })


@login_required(login_url='signin')
def change_profile_view(request):
    """Halaman ganti foto profil. Menerima upload file gambar via POST."""

    # Ambil atau buat profil user
    profile, _ = UserProfile.objects.get_or_create(user=request.user)

    if request.method == 'POST':
        uploaded = request.FILES.get('profile_picture')
        if uploaded:
            # Validasi tipe file (JPG, JPEG, PNG)
            ext = os.path.splitext(uploaded.name)[1].lower()
            valid_extensions = ['.jpg', '.jpeg', '.png']
            content_type = uploaded.content_type
            valid_content_types = ['image/jpeg', 'image/png']
            
            if ext not in valid_extensions or content_type not in valid_content_types:
                messages.error(request, 'Hanya format gambar .jpg, .jpeg, dan .png yang diperbolehkan.')
                return redirect('change_profile')

            # Hapus foto lama jika ada agar tidak menumpuk
            if profile.profile_picture:
                try:
                    profile.profile_picture.delete(save=False)
                except Exception:
                    pass
            profile.profile_picture = uploaded
            profile.save()
            messages.success(request, 'Foto profil berhasil diperbarui!')
            return redirect('home')
        else:
            messages.error(request, 'Pilih file gambar terlebih dahulu.')

    context = {
        'avatar_color':    get_avatar_color(request),
        'profile_picture': profile.profile_picture if profile.profile_picture else None,
    }
    return render(request, 'core/change_profile.html', context)


@login_required(login_url='signin')
def take_picture_view(request):
    """Merender halaman camera.html untuk live webcam capture."""
    context = {
        'avatar_color': get_avatar_color(request),
        'profile_picture': get_profile_picture(request.user),
    }
    return render(request, 'core/camera.html', context)


@login_required(login_url='signin')
def upload_camera_image(request):
    """
    Endpoint AJAX: menerima foto hasil capture kamera (multipart/form-data),
    menyimpan ke UserProfile, dan mengembalikan JSON { success: true }.
    """
    from django.http import JsonResponse

    if request.method != 'POST':
        return JsonResponse({'success': False, 'error': 'Method not allowed'}, status=405)

    uploaded = request.FILES.get('profile_picture')
    if not uploaded:
        return JsonResponse({'success': False, 'error': 'Tidak ada file yang diterima.'}, status=400)

    # Validasi tipe file (JPG, JPEG, PNG) untuk capture kamera
    ext = os.path.splitext(uploaded.name)[1].lower()
    valid_extensions = ['.jpg', '.jpeg', '.png']
    content_type = uploaded.content_type
    valid_content_types = ['image/jpeg', 'image/png']
    
    if ext not in valid_extensions or content_type not in valid_content_types:
        return JsonResponse({'success': False, 'error': 'Hanya format gambar .jpg, .jpeg, dan .png yang diperbolehkan.'}, status=400)

    try:
        profile, _ = UserProfile.objects.get_or_create(user=request.user)

        # Hapus foto lama agar tidak menumpuk di storage
        if profile.profile_picture:
            try:
                profile.profile_picture.delete(save=False)
            except Exception:
                pass

        profile.profile_picture = uploaded
        profile.save()
        return JsonResponse({'success': True})

    except Exception as e:
        return JsonResponse({'success': False, 'error': str(e)}, status=500)


def logout_view(request):
    """Logout user dan redirect ke halaman home."""
    logout(request)
    return redirect('home')


@login_required(login_url='signin')
def delete_dataset(request, pk):
    """Menghapus seluruh dataset beserta file terkait (hanya pemilik)."""
    dataset = get_object_or_404(Dataset, pk=pk)
    
    if dataset.owner != request.user:
        messages.error(request, 'Anda tidak memiliki izin untuk menghapus dataset ini.')
        return redirect('dataset_detail', pk=pk)
    
    if request.method == 'POST':
        title = dataset.title
        # Hapus file dari media storage
        for dataset_file in dataset.files.all():
            if dataset_file.file:
                try:
                    if os.path.exists(dataset_file.file.path):
                        os.remove(dataset_file.file.path)
                except Exception:
                    pass
        
        dataset.delete()
        messages.success(request, f'Dataset "{title}" berhasil dihapus.')
        return redirect('datasets')
        
    return redirect('dataset_detail', pk=pk)


@login_required(login_url='signin')
def delete_dataset_file(request, pk):
    """Menghapus file tertentu di dalam dataset (hanya pemilik dataset)."""
    dataset_file = get_object_or_404(DatasetFile, pk=pk)
    dataset = dataset_file.dataset
    
    if dataset.owner != request.user:
        messages.error(request, 'Anda tidak memiliki izin untuk menghapus file ini.')
        return redirect('dataset_detail', pk=dataset.pk)
        
    if request.method == 'POST':
        filename = dataset_file.filename
        # Hapus file dari media storage
        if dataset_file.file:
            try:
                if os.path.exists(dataset_file.file.path):
                    os.remove(dataset_file.file.path)
            except Exception:
                pass
                
        # Hapus record dari database
        dataset_file.delete()
        
        # Rekam di changelog
        DatasetChangelog.objects.create(
            dataset=dataset,
            user=request.user,
            action='file_deleted',
            description=f'File "{filename}" telah dihapus.',
        )
        
        messages.success(request, f'File "{filename}" berhasil dihapus.')
        
    return redirect('dataset_detail', pk=dataset.pk)


def forgot_password_view(request):
    """Menerima email pengguna dan memverifikasi keberadaannya untuk pemulihan password."""
    if request.user.is_authenticated:
        return redirect('home')

    error_message = None
    if request.method == 'POST':
        email = request.POST.get('email', '').strip()
        if not email:
            error_message = "Email wajib diisi."
        else:
            # Check if user exists with this email
            user = User.objects.filter(email=email).first()
            if user:
                # Simpan email ke session
                request.session['reset_password_email'] = email
                return redirect('reset_password')
            else:
                error_message = "Email tidak terdaftar di sistem kami."

    return render(request, 'core/forgot_password.html', {'error': error_message})


def reset_password_view(request):
    """Menerima password baru dan memperbarui password pengguna di basis data."""
    if request.user.is_authenticated:
        return redirect('home')

    # Ambil email dari session
    email = request.session.get('reset_password_email')
    if not email:
        messages.error(request, "Silakan masukkan email Anda terlebih dahulu.")
        return redirect('forgot_password')

    error_message = None
    if request.method == 'POST':
        new_password = request.POST.get('new_password', '')
        confirm_password = request.POST.get('confirm_password', '')

        if not new_password or not confirm_password:
            error_message = "Semua field wajib diisi."
        elif len(new_password) < 8:
            error_message = "Password minimal 8 karakter."
        elif new_password != confirm_password:
            error_message = "Konfirmasi password tidak cocok."
        else:
            user = User.objects.filter(email=email).first()
            if user:
                user.set_password(new_password)
                user.save()
                # Hapus email dari session
                request.session.pop('reset_password_email', None)
                messages.success(request, "Kata sandi Anda berhasil diperbarui! Silakan masuk kembali.")
                return redirect('signin')
            else:
                error_message = "Pengguna tidak ditemukan."

    return render(request, 'core/reset_password.html', {
        'email': email,
        'error': error_message
    })


def download_file(request, pk):
    """Meningkatkan download_count dataset secara realtime dan mengunduh file."""
    from django.db.models import F
    dataset_file = get_object_or_404(DatasetFile, pk=pk)
    dataset = dataset_file.dataset
    
    # Check permission for private dataset
    if dataset.visibility == 'private' and request.user != dataset.owner:
        messages.error(request, 'Dataset ini bersifat private.')
        return redirect('datasets')
    
    # Increment download count
    dataset.download_count = F('download_count') + 1
    dataset.save(update_fields=['download_count'])
    
    # Redirect to actual file url
    return redirect(dataset_file.file.url)


def get_dataset_downloads(request, pk):
    """Mengembalikan data realtime jumlah download_count dataset dalam format JSON."""
    from django.http import JsonResponse
    dataset = get_object_or_404(Dataset, pk=pk)
    
    # Check permission for private dataset
    if dataset.visibility == 'private' and request.user != dataset.owner:
        return JsonResponse({'error': 'Unauthorized'}, status=403)
        
    return JsonResponse({'download_count': dataset.download_count})

def dataset_requests_view(request):
    """Menampilkan daftar permintaan dataset dari kelompok IC."""
    if not request.user.is_authenticated:
        return render(request, 'core/dataset_requests.html', {
            'avatar_color': get_avatar_color(request),
            'profile_picture': None,
            'show_login_warning': True,
        })
        
    pending_requests = DatasetRequest.objects.filter(status__in=['PENDING', 'IN_PROGRESS']).order_by('-created_at')
    completed_requests = DatasetRequest.objects.filter(status__in=['COMPLETED', 'REJECTED']).order_by('-created_at')
    
    context = {
        'pending_requests': pending_requests,
        'completed_requests': completed_requests,
        'profile_picture': request.user.profile.profile_picture if hasattr(request.user, 'profile') else None,
        'avatar_color': get_avatar_color(request),
    }
    return render(request, 'core/dataset_requests.html', context)

@login_required
def update_dataset_request_status(request, pk):
    """Mengubah status dari permintaan dataset dan mengunggah file jika ada."""
    import requests
    if request.method == 'POST':
        req = get_object_or_404(DatasetRequest, pk=pk)
        new_status = request.POST.get('status')
        if new_status in dict(DatasetRequest.STATUS_CHOICES):
            req.status = new_status
            if 'result_file' in request.FILES:
                uploaded_file = request.FILES['result_file']
                req.result_file = uploaded_file
                req.status = 'COMPLETED' # Otomatis selesai jika file diunggah
                
                # Forward file to Intelligence Creation (IC) if it originated from IC
                if req.ic_submission_id:
                    try:
                        # Reset file pointer so requests can read it
                        uploaded_file.seek(0)
                        files = {'source_file': (uploaded_file.name, uploaded_file.read(), uploaded_file.content_type)}
                        
                        ic_url = f"http://72.61.215.222/creation/api/submissions/{req.ic_submission_id}/receive_from_datago/"
                        res = requests.post(ic_url, files=files, timeout=15)
                        if not res.ok:
                            messages.warning(request, f"File berhasil diunggah di Datago, tapi gagal dikirim ke IC: {res.text}")
                    except Exception as e:
                        messages.warning(request, f"File berhasil diunggah, tapi gagal dikirim ke IC (Error: {str(e)})")
            req.save()
            messages.success(request, f"Permintaan '{req.title}' berhasil diperbarui.")
    return redirect('dataset_requests')

@login_required
def clean_dataset_file(request, pk):
    """Membersihkan file CSV dari baris kosong (NA) dan duplikat, lalu membuat versi barunya."""
    if request.method == 'POST':
        dataset_file = get_object_or_404(DatasetFile, pk=pk)
        dataset = dataset_file.dataset
        
        # Hanya pemilik dataset yang dapat melakukan pembersihan
        if request.user != dataset.owner:
            messages.error(request, "Hanya pemilik dataset yang dapat melakukan aksi ini.")
            return redirect('dataset_detail', pk=dataset.pk)
        
        if not dataset_file.file.name.lower().endswith('.csv'):
            messages.error(request, "Fitur ini hanya mendukung file dengan ekstensi .csv.")
            return redirect('dataset_detail', pk=dataset.pk)
            
        try:
            import csv
            
            initial_count = 0
            final_count = 0
            cleaned_rows = []
            seen = set()
            header = None
            
            with open(dataset_file.file.path, 'r', encoding='utf-8', errors='replace') as f:
                reader = csv.reader(f)
                try:
                    header = next(reader)
                    cleaned_rows.append(header)
                except StopIteration:
                    pass
                
                for row in reader:
                    initial_count += 1
                    
                    # Hapus baris dengan nilai NA (kolom kosong)
                    if any(not str(cell).strip() for cell in row):
                        continue
                    
                    # Hapus duplikat
                    row_tuple = tuple(row)
                    if row_tuple in seen:
                        continue
                        
                    seen.add(row_tuple)
                    cleaned_rows.append(row)
                    final_count += 1
            
            if initial_count == final_count:
                messages.info(request, "File tidak memiliki data kosong maupun duplikat, tidak ada versi baru yang dibuat.")
                return redirect('dataset_detail', pk=dataset.pk)
            
            # Tentukan tag versi baru
            new_version_tag = dataset_file.version_tag + "_cleaned"
            
            # Tentukan nama file baru
            original_filename = os.path.basename(dataset_file.file.name)
            name, ext = os.path.splitext(original_filename)
            new_filename = f"{name}_cleaned{ext}"
            
            # Buat Dataset Baru
            new_dataset = Dataset.objects.create(
                owner=request.user,
                title=f"{dataset.title} (Cleaned)",
                description=f"{dataset.description}\n\n[Dataset ini merupakan hasil pembersihan dari dataset asli: '{dataset.title}'. {initial_count - final_count} baris dihapus karena kosong atau duplikat.]",
                visibility=dataset.visibility,
                license=dataset.license
            )
            
            # Menyimpan data yang sudah dibersihkan ke temporary file
            with tempfile.NamedTemporaryFile(suffix='.csv', delete=False, mode='w', newline='', encoding='utf-8') as tmp:
                writer = csv.writer(tmp)
                writer.writerows(cleaned_rows)
                tmp.flush()
                tmp.close()
                
                # Membuka file temporary dan membungkusnya sebagai file django
                with open(tmp.name, 'rb') as f_temp:
                    django_file = File(f_temp)
                    django_file.name = new_filename
                    
                    # Simpan sebagai file baru untuk dataset *BARU* tersebut
                    new_dataset_file = DatasetFile(
                        dataset=new_dataset,
                        version_tag=new_version_tag
                    )
                    new_dataset_file.file.save(new_filename, django_file, save=True)
            
            # Menghapus temporary file
            os.remove(tmp.name)
            
            # Buat changelog
            DatasetChangelog.objects.create(
                dataset=new_dataset,
                user=request.user,
                action='created',
                description=f"Dataset versi bersih dibuat dari dataset '{dataset.title}'."
            )
            DatasetChangelog.objects.create(
                dataset=new_dataset,
                user=request.user,
                action='file_added',
                description=f"File {new_filename} ditambahkan (hasil pembersihan: {initial_count - final_count} baris dihapus)."
            )
            
            messages.success(request, f"Dataset berhasil dibersihkan dan dibuat baru! {initial_count - final_count} baris telah dihapus.")
            
        except Exception as e:
            messages.error(request, f"Terjadi kesalahan saat membersihkan file: {e}")
            return redirect('dataset_detail', pk=dataset.pk)
            
        return redirect('dataset_detail', pk=new_dataset.pk)
    
    # Bila GET, arahkan kembali
    return redirect('home')

@login_required
def find_matching_datasets(request, pk):
    """Mencari dataset CSV yang memenuhi kriteria min_rows dan required_columns dari sebuah request."""
    req = get_object_or_404(DatasetRequest, pk=pk)
    
    if req.status in ['COMPLETED', 'REJECTED']:
        messages.error(request, "Pencarian tidak tersedia untuk request yang sudah selesai.")
        return redirect('dataset_requests')
        
    required_cols = []
    if req.required_columns:
        required_cols = [c.strip().lower() for c in req.required_columns.split(',') if c.strip()]
        
    min_rows = req.min_rows or 0
    
    # Cari semua dataset milik user ATAU public
    all_datasets = Dataset.objects.filter(Q(visibility='public') | Q(owner=request.user)).distinct()
    
    matching_files = []
    
    import csv
    for dataset in all_datasets:
        for dfile in dataset.files.all():
            if not dfile.file.name.lower().endswith('.csv'):
                continue
                
            try:
                row_count = 0
                has_cols = False
                
                with open(dfile.file.path, 'r', encoding='utf-8', errors='replace') as f:
                    reader = csv.reader(f)
                    try:
                        header = next(reader)
                        if header:
                            header_lower = [h.strip().lower() for h in header]
                            # Periksa kolom
                            if all(rc in header_lower for rc in required_cols):
                                has_cols = True
                                
                                # Jika kolom cocok, hitung baris
                                if has_cols:
                                    for row in reader:
                                        row_count += 1
                                        if row_count >= min_rows:
                                            # Jika sudah mencapai min_rows, kita bisa berhenti menghitung untuk efisiensi
                                            break
                    except StopIteration:
                        pass
                
                if has_cols and row_count >= min_rows:
                    matching_files.append(dfile)
            except Exception as e:
                # Lewati file yang bermasalah
                pass

    context = {
        'req': req,
        'matching_files': matching_files,
        'profile_picture': request.user.profile.profile_picture if hasattr(request.user, 'profile') else None,
        'avatar_color': get_avatar_color(request),
    }
    return render(request, 'core/matching_datasets.html', context)


import json
from django.views.decorators.csrf import csrf_exempt
from django.http import JsonResponse

@csrf_exempt
def create_dataset_request_api(request):
    if request.method != 'POST':
        return JsonResponse({'success': False}, status=405)
    try:
        data = json.loads(request.body)
        title = data.get('title', 'Tanpa Judul')
        description = data.get('description', '')
        contact = data.get('contact', '')
        min_rows = data.get('min_rows', '')
        required_columns = data.get('required_columns', '')
        ic_submission_id = data.get('submission_id', '')

        # Pastikan ada submission id
        if not ic_submission_id:
            return JsonResponse({'success': False, 'error': 'Missing submission_id'}, status=400)

        # Buat DatasetRequest
        req = DatasetRequest.objects.create(
            title=title,
            description='[IC ID: ' + str(ic_submission_id) + '] ' + description,
            contact_email=contact,
            min_rows=int(min_rows) if min_rows else None,
            required_columns=required_columns,
            status='PENDING',
            ic_submission_id=ic_submission_id
        )
        return JsonResponse({'success': True, 'id': req.id})
    except Exception as e:
        return JsonResponse({'success': False, 'error': str(e)}, status=500)
