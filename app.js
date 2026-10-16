/* ============================================================
   Калькулятор подарка коллеге на ДР
   Формула: (X / 500 + Y / 100) * K * N
   ============================================================ */

(function () {
  'use strict';

  /* ---------- данные коэффициентов ---------- */

  var K_OPTIONS = [
    { value: 0.5, label: 'Работает не в твоём отделе' },
    { value: 1,   label: 'Твой отдел, но другая функция' },
    { value: 1.5, label: 'Работает в твоей функции' },
    { value: 2,   label: 'Твой руководитель или подчинённый' }
  ];

  var N_OPTIONS = [
    { value: 0.5, label: 'Видитесь реже раза в неделю' },
    { value: 1,   label: 'Общаетесь почти каждый день' },
    { value: 1.5, label: 'Вместе выпивали' },
    { value: 2,   label: 'Ходили друг к другу в гости' }
  ];

  var STORE_KEY = 'dr-gift-state-v1';

  var defaults = { x: 80000, y: 3000, k: 1.5, n: 1, round: 0 };

  /* ---------- элементы ---------- */

  var el = {
    x: document.getElementById('x'),
    y: document.getElementById('y'),
    chipsK: document.getElementById('chips-k'),
    chipsN: document.getElementById('chips-n'),
    rounding: document.getElementById('rounding'),
    amount: document.getElementById('amount'),
    amountNote: document.getElementById('amount-note'),
    breakdown: document.getElementById('breakdown'),
    share: document.getElementById('share'),
    copy: document.getElementById('copy'),
    toast: document.getElementById('toast')
  };

  /* ---------- утилиты ---------- */

  var nf = new Intl.NumberFormat('ru-RU', { maximumFractionDigits: 2 });

  function group(digits) {
    return digits.replace(/\B(?=(\d{3})+(?!\d))/g, '\u00A0');
  }

  function fmtNum(value) {
    return nf.format(value);
  }

  function fmtRatio(value) {
    return String(value).replace('.', ',');
  }

  function digitsOf(input) {
    return input.value.replace(/\D/g, '').slice(0, 12);
  }

  // Показывает в поле введённые цифры. Пустая строка остаётся пустой,
  // а "0" остаётся нулём — это разные вещи.
  function formatField(input, digits) {
    input.value = digits ? group(String(parseInt(digits, 10))) : '';
  }

  // Первичная отрисовка из сохранённого состояния (там всегда число).
  function writeMoney(input, value) {
    formatField(input, isFinite(value) ? String(value) : '');
  }

  function clampNumber(value, fallback) {
    var n = parseFloat(value);
    return isFinite(n) ? n : fallback;
  }

  /* ---------- состояние ---------- */

  var state = Object.assign({}, defaults);

  function loadState() {
    var fromUrl = new URLSearchParams(location.search);
    var s = {};

    if (fromUrl.has('x') || fromUrl.has('y') || fromUrl.has('k') || fromUrl.has('n')) {
      s.x = clampNumber(fromUrl.get('x'), defaults.x);
      s.y = clampNumber(fromUrl.get('y'), defaults.y);
      s.k = pickOption(fromUrl.get('k'), K_OPTIONS, defaults.k);
      s.n = pickOption(fromUrl.get('n'), N_OPTIONS, defaults.n);
    } else {
      try {
        var raw = localStorage.getItem(STORE_KEY);
        if (raw) s = JSON.parse(raw) || {};
      } catch (e) { /* приватный режим — не страшно */ }
    }

    state.x = Math.max(0, Math.round(clampNumber(s.x, defaults.x)));
    state.y = Math.max(0, Math.round(clampNumber(s.y, defaults.y)));
    state.k = pickOption(s.k, K_OPTIONS, defaults.k);
    state.n = pickOption(s.n, N_OPTIONS, defaults.n);
    state.round = [0, 100, 500].indexOf(clampNumber(s.round, 0)) >= 0 ? clampNumber(s.round, 0) : 0;
  }

  function pickOption(value, options, fallback) {
    var n = parseFloat(value);
    for (var i = 0; i < options.length; i++) {
      if (options[i].value === n) return n;
    }
    return fallback;
  }

  function saveState() {
    try { localStorage.setItem(STORE_KEY, JSON.stringify(state)); } catch (e) { /* ignore */ }
    syncUrl();
  }

  function syncUrl() {
    if (!history.replaceState) return;
    var q = '?x=' + state.x + '&y=' + state.y + '&k=' + fmtRatio(state.k) + '&n=' + fmtRatio(state.n);
    history.replaceState(null, '', location.pathname + q);
  }

  /* ---------- расчёт ---------- */

  function compute() {
    var base = state.x / 500 + state.y / 100;
    var raw = base * state.k * state.n;
    var rounded = raw;

    if (state.round === 100) rounded = Math.ceil(raw / 100) * 100;
    if (state.round === 500) rounded = Math.ceil(raw / 500) * 500;

    return { base: base, raw: raw, value: rounded };
  }

  /* ---------- отрисовка чипсов ---------- */

  function buildChips(container, options, key) {
    container.innerHTML = '';
    options.forEach(function (opt) {
      var btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'chip';
      btn.setAttribute('role', 'radio');
      btn.dataset.value = String(opt.value);

      var k = document.createElement('span');
      k.className = 'chip-k';
      k.textContent = fmtRatio(opt.value);

      var t = document.createElement('span');
      t.className = 'chip-t';
      t.textContent = opt.label;

      btn.appendChild(k);
      btn.appendChild(t);

      btn.addEventListener('click', function () {
        state[key] = opt.value;
        syncChips();
        update({ animate: true });
        saveState();
      });

      container.appendChild(btn);
    });
  }

  function syncChips() {
    [['chipsK', 'k'], ['chipsN', 'n']].forEach(function (pair) {
      var nodes = el[pair[0]].querySelectorAll('.chip');
      Array.prototype.forEach.call(nodes, function (node) {
        node.setAttribute('aria-checked', parseFloat(node.dataset.value) === state[pair[1]] ? 'true' : 'false');
      });
    });
  }

  function syncRounding() {
    var nodes = el.rounding.querySelectorAll('.seg-btn');
    Array.prototype.forEach.call(nodes, function (node) {
      node.setAttribute('aria-checked', parseFloat(node.dataset.value) === state.round ? 'true' : 'false');
    });
  }

  /* ---------- анимация числа ---------- */

  var shown = 0;
  var rafId = null;
  var fallbackId = null;
  var DURATION = 420;

  function render(value) {
    el.amount.textContent = fmtNum(value) + ' ₽';
  }

  function stopAnimation() {
    if (rafId) { cancelAnimationFrame(rafId); rafId = null; }
    if (fallbackId) { clearTimeout(fallbackId); fallbackId = null; }
  }

  function animateTo(target, animate) {
    stopAnimation();

    var reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    if (!animate || reduced || typeof requestAnimationFrame !== 'function') {
      shown = target;
      render(target);
      return;
    }

    var from = shown;
    var start = performance.now();

    function finish() {
      stopAnimation();
      shown = target;
      render(target);
    }

    function step(now) {
      var p = Math.min(1, (now - start) / DURATION);
      var eased = 1 - Math.pow(1 - p, 3);
      shown = from + (target - from) * eased;
      render(shown);
      if (p < 1) {
        rafId = requestAnimationFrame(step);
      } else {
        finish();
      }
    }

    rafId = requestAnimationFrame(step);

    // Страховка: если rAF приостановлен (фоновая вкладка, prerender, headless),
    // итоговое число всё равно обязано появиться.
    fallbackId = setTimeout(finish, DURATION + 120);
  }

  /* ---------- обновление результата ---------- */

  function update(opts) {
    opts = opts || {};
    var r = compute();
    var animate = opts.animate !== false;

    el.breakdown.textContent =
      '(' + group(String(state.x)) + ' / 500 + ' + group(String(state.y)) + ' / 100) × ' +
      fmtRatio(state.k) + ' × ' + fmtRatio(state.n) +
      ' = ' + fmtNum(Math.round(r.raw * 100) / 100) + ' ₽';

    if (state.round !== 0 && r.value !== r.raw) {
      el.amountNote.textContent = 'Округлили вверх до ' + state.round + ' ₽ — точный расчёт ' + fmtNum(Math.round(r.raw * 100) / 100) + ' ₽';
    } else if (r.value <= 0) {
      el.amountNote.textContent = 'Пока нечего считать — заполни поля слева.';
    } else if (r.raw < 300) {
      el.amountNote.textContent = 'Скромно. Возможно, стоит добавить пару щедрости.';
    } else if (r.raw > 5000) {
      el.amountNote.textContent = 'Щедро! Проверь коэффициенты — вдруг пережал.';
    } else {
      el.amountNote.textContent = 'Выглядит адекватно.';
    }

    if (animate) {
      el.amount.classList.remove('bump');
      void el.amount.offsetWidth;
      el.amount.classList.add('bump');
    }

    animateTo(Math.round(r.value * 100) / 100, animate);

    return r;
  }

  /* ---------- уведомления ---------- */

  var toastTimer = null;

  function toast(message) {
    el.toast.textContent = message;
    el.toast.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () {
      el.toast.classList.remove('show');
    }, 2400);
  }

  function copyText(text) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      return navigator.clipboard.writeText(text);
    }
    return new Promise(function (resolve, reject) {
      try {
        var ta = document.createElement('textarea');
        ta.value = text;
        ta.setAttribute('readonly', '');
        ta.style.position = 'fixed';
        ta.style.opacity = '0';
        document.body.appendChild(ta);
        ta.select();
        document.execCommand('copy');
        document.body.removeChild(ta);
        resolve();
      } catch (e) { reject(e); }
    });
  }

  function shareText() {
    var r = compute();
    return 'Мне насчитало ' + fmtNum(Math.round(r.value * 100) / 100) + ' ₽ скинуться коллеге на ДР 🎁\n' + location.href;
  }

  /* ---------- события ---------- */

  [el.x, el.y].forEach(function (input, index) {
    input.addEventListener('input', function () {
      var key = index === 0 ? 'x' : 'y';
      var digits = digitsOf(input);
      state[key] = digits ? parseInt(digits, 10) : 0;
      formatField(input, digits);
      update({ animate: true });
      saveState();
    });

    input.addEventListener('blur', function () {
      formatField(input, digitsOf(input));
    });
  });

  el.rounding.addEventListener('click', function (event) {
    var btn = event.target.closest('.seg-btn');
    if (!btn) return;
    state.round = parseFloat(btn.dataset.value);
    syncRounding();
    update({ animate: true });
    saveState();
  });

  el.copy.addEventListener('click', function () {
    var r = compute();
    copyText(fmtNum(Math.round(r.value * 100) / 100) + ' ₽')
      .then(function () { toast('Сумма скопирована ✓'); })
      .catch(function () { toast('Не получилось скопировать :('); });
  });

  el.share.addEventListener('click', function () {
    var payload = { title: 'Сколько скинуться коллеге на ДР', text: shareText(), url: location.href };

    if (navigator.share) {
      navigator.share(payload).catch(function () {
        copyText(shareText()).then(function () { toast('Ссылка с расчётом скопирована ✓'); });
      });
      return;
    }

    copyText(shareText())
      .then(function () { toast('Ссылка с расчётом скопирована ✓'); })
      .catch(function () { toast('Не получилось скопировать :('); });
  });

  /* ---------- запуск ---------- */

  loadState();
  buildChips(el.chipsK, K_OPTIONS, 'k');
  buildChips(el.chipsN, N_OPTIONS, 'n');
  writeMoney(el.x, state.x);
  writeMoney(el.y, state.y);
  syncChips();
  syncRounding();
  update({ animate: false });
  saveState();
})();
