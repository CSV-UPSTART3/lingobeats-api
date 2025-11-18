(() => {
  document.addEventListener('DOMContentLoaded', () => {
    // --- Tooltip initialization ---
    const tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'));
    tooltipTriggerList.forEach(el => new bootstrap.Tooltip(el));

    // --- Elements used across sections ---
    const searchInput      = document.getElementById('spotify_query_input');
    const errorMsg         = document.getElementById('error');
    const switcher         = document.querySelector('.pill-switch');
    const slider           = switcher?.querySelector('.slider');
    const links            = switcher ? switcher.querySelectorAll('.nav-link') : [];
    const submitBtn        = document.getElementById('submitBtn');
    const categoryInput    = document.getElementById('category');
    const form             = document.getElementById('spotify-form');
    const historyContainer = document.getElementById('searchHistoryContainer');

    // --- Page context ---
    const isHome = window.location.pathname === '/';
    console.log('[init] isHome =', isHome);

    // --- Placeholders map ---
    const placeholders = {
      song_name: 'e.g. Shape of You',
      singer: 'e.g. Taylor Swift'
    };

    // --- Helpers for pill switch ---
    const getActiveLink = () => switcher?.querySelector('.nav-link.active');

    const setActive = (link) => {
      if (!switcher || !slider) return;
      links.forEach(a => {
        a.classList.remove('active', 'text-white');
        a.setAttribute('aria-selected', 'false');
      });
      link.classList.add('active', 'text-white');
      link.setAttribute('aria-selected', 'true');

      const cat = link.dataset.category || 'song_name';
      if (categoryInput) categoryInput.value = cat;
      if (searchInput) searchInput.placeholder = placeholders[cat] || 'Enter keywords to find songs';

      // ensure the correct history group is visible when switching pills
      toggleHistoryGroups(cat);

      const currentQuery = (searchInput?.value || '').trim();
      renderHistory(cat, currentQuery);

      requestAnimationFrame(() => {
        slider.style.left = link.offsetLeft + 'px';
        slider.style.width = link.offsetWidth + 'px';
      });
    };

    // --- Strict prefix matching helpers ---
    const normalizeStr = (s) =>
      (s || '')
        .toLowerCase()
        .normalize('NFKD')
        .replace(/[\u0300-\u036f]/g, '')
        .trim();

    const prefixMatch = (text, query) => {
      const t = normalizeStr(text);
      const q = normalizeStr(query);
      if (!q) return true;            // no query → show all in category
      if (!t) return false;
      return t.startsWith(q);         // strict prefix
    };

    // --- Toggle which category group is visible (Song vs Singer) ---
    function toggleHistoryGroups(activeCat) {
      if (!historyContainer) return;
      const groups = historyContainer.querySelectorAll('.history-group');
      groups.forEach(g => {
        g.classList.toggle('d-none', g.dataset.category !== activeCat);
      });
    }

    // --- Core renderer: category filter + strict prefix filter + container visibility gating ---
    function renderHistory(category, query) {
      if (!historyContainer) return;

      const q = (query || '').trim();
      const badges = historyContainer.querySelectorAll('.history-badge');

      let showCount = 0;

      badges.forEach(badge => {
        // 1) category filter
        const isCat = badge.dataset.category === category;
        if (!isCat) {
          badge.style.display = 'none';
          return;
        }

        // 2) prefix filter
        const text = badge.dataset.query || badge.querySelector('.history-text')?.textContent || '';
        const shouldShow = prefixMatch(text, q);

        if (shouldShow) {
          // use flex to preserve layout
          badge.style.display = 'flex';
          showCount++;
        } else {
          badge.style.display = 'none';
        }
      });

      // 3) only show container when:
      //    - input is focused
      //    - and (query empty with some items, or query non-empty with matches)
      const focused = (document.activeElement === searchInput);
      const shouldShowContainer = focused && showCount > 0;
      historyContainer.style.display = shouldShowContainer ? 'block' : 'none';

      console.log('[history] render:', {
        category,
        query: q,
        showCount,
        focused,
        shown: historyContainer.style.display
      });
    }

    // --- Show/hide history on input focus / outside click and live filter ---
    if (searchInput && historyContainer) {
      // focus: render with current text
      searchInput.addEventListener('focus', () => {
        const cat = categoryInput?.value || 'song_name';
        toggleHistoryGroups(cat);
        renderHistory(cat, searchInput.value);
      });

      // input: live strict-prefix filtering
      searchInput.addEventListener('input', () => {
        const cat = categoryInput?.value || 'song_name';
        toggleHistoryGroups(cat);
        renderHistory(cat, searchInput.value);
      });

      // click outside → close
      document.addEventListener('click', (e) => {
        if (!searchInput.contains(e.target) &&
            !historyContainer.contains(e.target) &&
            !e.target.closest('.pill-switch')) {
          historyContainer.style.display = 'none';
        }
      });
    }

    // --- Click a history item to search ---
    if (historyContainer) {
      historyContainer.addEventListener('click', (e) => {
        const historyText = e.target.closest('.history-text');
        if (!historyText) return;

        const badge = historyText.closest('.history-badge');
        const query = badge?.dataset.query;
        const category = badge?.dataset.category;
        if (!query || !category) return;

        if (searchInput) searchInput.value = query;
        if (categoryInput) categoryInput.value = category;

        const targetLink = Array.from(links).find(l => l.dataset.category === category);
        if (targetLink) setActive(targetLink);

        sessionStorage.setItem('lastCategory', category);
        sessionStorage.setItem('lastSearchQuery', (query || '').trim());

        console.log('[history] choose:', { category, query });

        if (form?.requestSubmit) {
          form.requestSubmit();
        } else {
          form?.submit();
        }
      });

      // --- Delete single history item ---
      historyContainer.addEventListener('mousedown', (e) => {
        const closeBtn = e.target.closest('.btn-close');
        if (closeBtn) {
          e.preventDefault();
        }
      });

      historyContainer.addEventListener('click', async (e) => {
        const closeBtn = e.target.closest('.btn-close');
        if (!closeBtn) return;

        e.stopPropagation();

        const query    = closeBtn.dataset.query;
        const category = closeBtn.dataset.category;
        if (!query || !category) return;

        try {
          const params = new URLSearchParams({ category, query });
          const res = await fetch(`/search_history?${params.toString()}`, {
            method: 'DELETE'
          });

          if (res.ok || res.status === 204) {
            const badge = closeBtn.closest('.history-badge');
            if (badge) badge.remove();

            const cat = categoryInput?.value || 'song_name';
            const q = (searchInput?.value || '').trim();
            renderHistory(cat, q);

            keepSearchFocus();
            console.log('[history] deleted:', { category, query });
          } else {
            console.error('[history] delete failed:', res.status);
          }
        } catch (err) {
          console.error('[history] delete failed:', err);
        }
      });
    }

    function keepSearchFocus() {
      if (!searchInput) return;
      searchInput.focus({ preventScroll: true });
      const len = searchInput.value.length;
      requestAnimationFrame(() => {
        try { searchInput.setSelectionRange(len, len); } catch(_) {}
      });
    }

    // --- Remember on submit & reset on home ---
    if (searchInput) {
      if (isHome) {
        sessionStorage.removeItem('lastCategory');
        sessionStorage.removeItem('lastSearchQuery');
        searchInput.value = '';
        if (errorMsg) errorMsg.textContent = '';
      } else {
        const rememberedQuery = sessionStorage.getItem('lastSearchQuery');
        if (rememberedQuery) searchInput.value = rememberedQuery;
        if (errorMsg && !rememberedQuery) errorMsg.textContent = '';
      }
    }

    // --- Pill Switch + Search initialization ---
    if (switcher && slider && categoryInput && searchInput) {
      const DEFAULT_CAT = 'song_name';
      const rememberedCat = sessionStorage.getItem('lastCategory');
      const initialCategory = isHome
        ? DEFAULT_CAT
        : (['song_name', 'singer'].includes(rememberedCat || '') ? rememberedCat : DEFAULT_CAT);

      categoryInput.value = initialCategory;
      searchInput.placeholder = placeholders[initialCategory] || searchInput.placeholder || '';

      const initialLink =
        Array.from(links).find(a => (a.dataset.category || '') === initialCategory) || links[0];

      if (initialLink) {
        setActive(initialLink);
        console.log('[pill] initial active =', initialCategory);
      }

      // Render once using current input (kept hidden if input is not focused)
      toggleHistoryGroups(initialCategory);
      renderHistory(initialCategory, (searchInput?.value || '').trim());

      links.forEach(link => {
        link.addEventListener('click', e => {
          e.preventDefault();
          setActive(link);
          console.log('[pill] switched to =', link.dataset.category);
        });
      });

      if (form) {
        form.addEventListener('submit', () => {
          const active = getActiveLink();
          const cat = (active?.dataset.category) || categoryInput.value || DEFAULT_CAT;
          categoryInput.value = cat;

          sessionStorage.setItem('lastCategory', cat);
          sessionStorage.setItem('lastSearchQuery', (searchInput.value || '').trim());
          console.log('[submit] remember:', { cat, q: searchInput.value });
        });
      }

      const toggleSubmit = () => {
        if (submitBtn) submitBtn.disabled = !searchInput.value.trim();
      };
      searchInput.addEventListener('input', toggleSubmit);
      toggleSubmit();

      const relocate = () => {
        const a = getActiveLink();
        if (!a) return;
        requestAnimationFrame(() => {
          slider.style.left = a.offsetLeft + 'px';
          slider.style.width = a.offsetWidth + 'px';
        });
      };
      window.addEventListener('resize', relocate);
      window.addEventListener('load', relocate);
    }

    // --- Scroll behavior for .results-container ---
    document.addEventListener(
      'wheel',
      e => {
        const results = document.querySelector('.results-container');
        if (!results) return;

        const atTop = results.scrollTop === 0;
        const atBottom = results.scrollHeight - results.scrollTop === results.clientHeight;

        if (!results.contains(e.target)) {
          e.preventDefault();
          results.scrollTop += e.deltaY;
        } else if ((atTop && e.deltaY < 0) || (atBottom && e.deltaY > 0)) {
          e.preventDefault();
        }
      },
      { passive: false }
    );

    // --- Song Modal Logic ---
    const songModal = document.getElementById('songModal');
    let scrollPosition = 0;

    function preventScroll(e) {
      e.preventDefault();
      e.stopPropagation();
      return false;
    }

    if (songModal) {
      songModal.addEventListener('show.bs.modal', function () {
        scrollPosition = window.pageYOffset;

        document.body.style.overflow = 'hidden';
        document.body.style.position = 'fixed';
        document.body.style.top = `-${scrollPosition}px`;
        document.body.style.width = '100%';

        document.addEventListener('wheel', preventScroll, { passive: false });
        document.addEventListener('touchmove', preventScroll, { passive: false });
        document.addEventListener('scroll', preventScroll, { passive: false });
      });

      songModal.addEventListener('hidden.bs.modal', function () {
        document.removeEventListener('wheel', preventScroll);
        document.removeEventListener('touchmove', preventScroll);
        document.removeEventListener('scroll', preventScroll);

        document.body.style.overflow = '';
        document.body.style.position = '';
        document.body.style.top = '';
        document.body.style.width = '';
        window.scrollTo(0, scrollPosition);
      });

      const modalLyrics = document.getElementById('modalLyrics');
      if (modalLyrics) {
        modalLyrics.addEventListener('wheel', function (e) {
          e.stopPropagation();
        });
        modalLyrics.addEventListener('touchmove', function (e) {
          e.stopPropagation();
        });
      }
    }

    // --- Card click -> open modal and load lyrics ---
    document.addEventListener(
      'click',
      (e) => {
        const card = e.target.closest('.song-card');
        if (!card) return;

        if (e.target.closest('.singer-link') || e.target.closest('.play-overlay')) return;

        const singerLinks = card.querySelectorAll('.singer-link');
        const singers = Array.from(singerLinks).map(link => ({
          name: link.textContent.trim(),
          external_url: link.href
        }));

        const songData = {
          id:    card.dataset.id || '',
          name:  card.dataset.songName || '',
          album: card.dataset.albumName || '',
          cover: card.dataset.cover || '/assets/img/placeholder-album.png',
          url:   card.dataset.url || '#',
          singers
        };

        updateSongModal(songData);

        const modalEl = document.getElementById('songModal');
        const bsModal = bootstrap.Modal.getOrCreateInstance(modalEl);
        bsModal.show();
      },
      true
    );

    const lyricsLoadingHTML = `
      <div class="text-center text-muted py-3">
        <i class="fas fa-spinner fa-spin fa-2x mb-1 d-block"></i>
        <p>Loading lyrics...</p>
      </div>`;

    function updateSongModal(data) {
      const modalEl = document.getElementById('songModal');
      if (!modalEl) return;

      modalEl.querySelector('#modalSongTitle').textContent = data.name;
      modalEl.querySelector('#modalAlbum').textContent = data.album;
      modalEl.querySelector('#modalCover').src = data.cover;
      modalEl.querySelector('#modalCover').alt = data.album || 'Cover';
      modalEl.querySelector('#modalPlayOverlay').href = data.url;

      const singersEl = modalEl.querySelector('#modalSingers');
      if (data.singers?.length) {
        singersEl.innerHTML = data.singers
          .map(s => `<a class="singer-link" href="${s.external_url}" target="_blank" rel="noopener">${s.name}</a>`)
          .join(', ');
      } else {
        singersEl.textContent = 'Unknown';
      }

      const lyricsEl = document.getElementById('modalLyrics');
      lyricsEl.scrollTop = 0;
      lyricsEl.innerHTML = lyricsLoadingHTML;

      const primaryArtist = data.singers?.[0]?.name || '';
      loadLyrics(data.id, data.name, primaryArtist);
    }

    async function loadLyrics(songId, songName, singerName) {
      const lyricsEl = document.getElementById('modalLyrics');
      lyricsEl.classList.add('loading');

      try {
        const params = new URLSearchParams();
        if (songId) params.set('id', songId);
        if (songName) params.set('name', songName);
        if (singerName) params.set('singer', singerName);

        const res  = await fetch(`/lyrics/song?${params.toString()}`, { cache: 'no-store' });
        const html = await res.text();
        if (!res.ok) throw new Error(`HTTP ${res.status}`);

        lyricsEl.classList.remove('loading');
        lyricsEl.innerHTML = html;
      } catch (e) {
        lyricsEl.classList.remove('loading');
        lyricsEl.innerHTML = `
          <div class="text-center text-danger py-5">
            <i class="fas fa-exclamation-triangle fa-2x mb-1 d-block"></i>
            <p>Failed to load lyrics: ${e.message}</p>
          </div>`;
      }
    }
  });
})();
