/**
 * DATAGO Interactivity Script
 */

document.addEventListener('DOMContentLoaded', () => {
    // 1. Mobile Menu Toggle
    const mobileToggle = document.querySelector('.mobile-toggle');
    const navLinks = document.querySelector('.nav-links');
    const headerActions = document.querySelector('.header-actions');
    
    if (mobileToggle) {
        mobileToggle.addEventListener('click', () => {
            navLinks.classList.toggle('show');
            headerActions.classList.toggle('show');
            mobileToggle.classList.toggle('active');
            
            // Toggle hamburger icon animation
            const bars = mobileToggle.querySelectorAll('.bar');
            if (mobileToggle.classList.contains('active')) {
                bars[0].style.transform = 'rotate(-45deg) translate(-5px, 6px)';
                bars[1].style.opacity = '0';
                bars[2].style.transform = 'rotate(45deg) translate(-5px, -6px)';
            } else {
                bars[0].style.transform = 'none';
                bars[1].style.opacity = '1';
                bars[2].style.transform = 'none';
            }
        });
    }

    // 2. Dynamic Donut Chart Renderer
    renderDonutChart('chart-datasets', 'datasets-raw');
    renderDonutChart('chart-downloads', 'downloads-raw');

    function renderDonutChart(containerId, rawDataId) {
        const container = document.getElementById(containerId);
        const dataScript = document.getElementById(rawDataId);
        if (!container || !dataScript) return;

        try {
            const data = JSON.parse(dataScript.textContent);
            const segmentsGroup = container.querySelector('.segments-group');
            if (!segmentsGroup) return;

            const radius = 60;
            const cx = 80;
            const cy = 80;
            const circumference = 2 * Math.PI * radius; // ~376.99
            
            let accumulatedPercent = 0;

            data.forEach(item => {
                const percentVal = parseFloat(item.percentage);
                const strokeLength = (percentVal / 100) * circumference;
                const strokeOffset = -(accumulatedPercent / 100) * circumference;

                // Create SVG Circle Element for Segment
                const circle = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
                circle.setAttribute('class', 'donut-segment');
                circle.setAttribute('cx', cx);
                circle.setAttribute('cy', cy);
                circle.setAttribute('r', radius);
                circle.setAttribute('fill', 'transparent');
                circle.setAttribute('stroke', item.color);
                circle.setAttribute('stroke-width', '16');
                circle.setAttribute('stroke-dasharray', `${strokeLength} ${circumference}`);
                circle.setAttribute('stroke-dashoffset', strokeOffset);
                
                // Add tooltip accessibility / interactivity
                circle.setAttribute('data-year', item.year);
                circle.setAttribute('data-percentage', percentVal);
                
                // Hover effect on the floating pills
                circle.addEventListener('mouseenter', () => {
                    highlightPill(container, item.year);
                });
                
                circle.addEventListener('mouseleave', () => {
                    resetPills(container);
                });

                segmentsGroup.appendChild(circle);
                accumulatedPercent += percentVal;
            });
        } catch (e) {
            console.error('Error rendering chart ' + containerId, e);
        }
    }

    // Helpers to link SVG hover to legend pills
    function highlightPill(container, year) {
        const parent = container.closest('.chart-relative-container');
        if (!parent) return;
        const pills = parent.querySelectorAll('.chart-pill');
        pills.forEach(pill => {
            if (pill.classList.contains(`pill-${year}`)) {
                pill.style.transform = 'scale(1.2)';
                pill.style.backgroundColor = '#8B00FF';
                pill.style.color = '#FFFFFF';
                pill.querySelector('.pill-value').style.color = '#FFFFFF';
                pill.querySelector('.pill-year').style.color = '#E0E0E0';
            } else {
                pill.style.opacity = '0.4';
            }
        });
    }

    function resetPills(container) {
        const parent = container.closest('.chart-relative-container');
        if (!parent) return;
        const pills = parent.querySelectorAll('.chart-pill');
        pills.forEach(pill => {
            pill.style.transform = 'none';
            pill.style.backgroundColor = 'var(--text-white)';
            pill.style.color = 'var(--text-dark)';
            pill.style.opacity = '1';
            pill.querySelector('.pill-value').style.color = '#000';
            pill.querySelector('.pill-year').style.color = '#666';
        });
    }

    // 3. Auth Page Switcher (Login / Register)
    const tabLogin = document.getElementById('tab-login');
    const tabRegister = document.getElementById('tab-register');
    const formLogin = document.getElementById('form-login');
    const formRegister = document.getElementById('form-register');

    if (tabLogin && tabRegister) {
        tabLogin.addEventListener('click', () => {
            tabLogin.classList.add('active');
            tabRegister.classList.remove('active');
            formLogin.classList.remove('hidden');
            formRegister.classList.add('hidden');
        });

        tabRegister.addEventListener('click', () => {
            tabRegister.classList.add('active');
            tabLogin.classList.remove('active');
            formRegister.classList.remove('hidden');
            formLogin.classList.add('hidden');
        });
    }

    // 4. Drag & Drop File Upload simulation
    const dropzone = document.getElementById('dropzone');
    const fileInput = document.getElementById('file-input');

    if (dropzone && fileInput) {
        dropzone.addEventListener('click', () => fileInput.click());

        dropzone.addEventListener('dragover', (e) => {
            e.preventDefault();
            dropzone.style.borderColor = 'var(--primary-color)';
            dropzone.style.backgroundColor = 'rgba(139, 0, 255, 0.05)';
        });

        const leaveDrag = () => {
            dropzone.style.borderColor = 'rgba(139, 0, 255, 0.3)';
            dropzone.style.backgroundColor = 'rgba(139, 0, 255, 0.01)';
        };

        dropzone.addEventListener('dragleave', leaveDrag);
        dropzone.addEventListener('drop', (e) => {
            e.preventDefault();
            leaveDrag();
            const files = e.dataTransfer.files;
            if (files.length > 0) {
                simulateFileSelection(files);
            }
        });

        fileInput.addEventListener('change', () => {
            if (fileInput.files.length > 0) {
                simulateFileSelection(fileInput.files);
            }
        });
    }

    function simulateFileSelection(files) {
        const dropzoneText = dropzone.querySelector('h3');
        const dropzoneDesc = dropzone.querySelector('p');
        if (files.length === 1) {
            dropzoneText.textContent = `Selected: ${files[0].name}`;
            dropzoneDesc.textContent = `Size: ${(files[0].size / (1024 * 1024)).toFixed(2)} MB`;
        } else {
            dropzoneText.textContent = `${files.length} files selected`;
            dropzoneDesc.textContent = 'Ready to upload';
        }
    }

    // 5. Search filtering on datasets list page
    const searchFilterInput = document.getElementById('dataset-filter');
    if (searchFilterInput) {
        searchFilterInput.addEventListener('input', (e) => {
            const query = e.target.value.toLowerCase();
            const cards = document.querySelectorAll('.dataset-card');
            cards.forEach(card => {
                const name = card.querySelector('.dataset-name').textContent.toLowerCase();
                const tags = Array.from(card.querySelectorAll('.tag')).map(t => t.textContent.toLowerCase());
                
                const matches = name.includes(query) || tags.some(t => t.includes(query));
                if (matches) {
                    card.style.display = 'flex';
                } else {
                    card.style.display = 'none';
                }
            });
        });
    }

    // 6. Profile Dropdown Toggle
    const profileWrapper = document.getElementById('profileWrapper');
    const profileDropdown = document.getElementById('profileDropdown');

    if (profileWrapper && profileDropdown) {
        profileWrapper.addEventListener('click', (e) => {
            e.stopPropagation();
            const isOpen = profileDropdown.classList.contains('show');
            if (isOpen) {
                profileDropdown.classList.remove('show');
                profileWrapper.classList.remove('open');
            } else {
                profileDropdown.classList.add('show');
                profileWrapper.classList.add('open');
            }
        });

        document.addEventListener('click', (e) => {
            if (!profileWrapper.contains(e.target)) {
                profileDropdown.classList.remove('show');
                profileWrapper.classList.remove('open');
            }
        });

        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                profileDropdown.classList.remove('show');
                profileWrapper.classList.remove('open');
            }
        });
    }

    // 7. Global Search Bar (navbar)

    const globalSearchInput = document.getElementById('global-search-input');
    const searchSubmitIcon  = document.getElementById('search-submit-icon');

    function doGlobalSearch() {
        const q = globalSearchInput.value.trim();
        if (q) {
            window.location.href = '/datasets/?q=' + encodeURIComponent(q);
        } else {
            window.location.href = '/datasets/';
        }
    }

    if (globalSearchInput) {
        // Pre-fill dari URL params jika sudah di halaman datasets
        const urlParams = new URLSearchParams(window.location.search);
        const currentQ = urlParams.get('q');
        if (currentQ) globalSearchInput.value = currentQ;

        // Enter key
        globalSearchInput.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') {
                e.preventDefault();
                doGlobalSearch();
            }
        });
    }

    if (searchSubmitIcon) {
        searchSubmitIcon.addEventListener('click', doGlobalSearch);
    }
});

